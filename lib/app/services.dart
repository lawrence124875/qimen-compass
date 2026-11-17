import 'package:flutter/widgets.dart';

import '../core/feedback/feedback_sender.dart';
import '../core/monetization/ad_service.dart';
import '../core/monetization/free_limits.dart';
import '../core/monetization/premium_service.dart';
import '../core/monetization/usage_quota.dart';
import '../core/records/record_store.dart';
import '../core/telemetry/analytics.dart';
import '../core/telemetry/remote_flags.dart';
import '../core/telemetry/usage_sharing.dart';
import '../core/updates/app_updates.dart';
import '../core/updates/play_app_updates.dart';

/// App 共用服務（比照謙卦 `lib/app/services.dart`）。測試直接 `Services()`：不統計、免費版、沒有廣告。
/// 各功能（擇時、宅盤、占卜）要訂閱時用 `requirePremium()`（lib/shared/premium/usage_gate.dart）。
class Services {
  Services({
    this.analytics = const NoopAnalytics(),
    this.flags = const DefaultRemoteFlags(),
    this.usage,
    this.feedback,
    this.updates = const NoAppUpdates(),
    PremiumService? premium,
    AdService? ads,
    FreeLimits? limits,
    UsageQuota? travelQuota,
    RecordStore? records,
    PreviewStore? previews,
  })  : premium = premium ?? FreePremium(),
        ads = ads ?? NoAds(),
        limits = limits ?? const FreeLimits(),
        travelQuota = travelQuota ?? UsageQuota(limits: limits ?? const FreeLimits(), storage: MemoryQuotaStorage()),
        records = records ?? MemoryRecordStore(),
        previews = previews ?? PreviewStore(MemoryQuotaStorage());

  /// main.dart 用：Firebase、RevenueCat、AdMob 初始化後傳入；各自失敗時退回替代實作。
  factory Services.standard({
    Analytics analytics = const NoopAnalytics(),
    RemoteFlags flags = const DefaultRemoteFlags(),
    PremiumService? premium,
    AdService? ads,
    FreeLimits limits = const FreeLimits(),
    UsageSharing? usage,
    FeedbackSender? feedback,
  }) =>
      Services(
        analytics: analytics,
        flags: flags,
        usage: usage,
        feedback: feedback,
        updates: const PlayAppUpdates(),
        premium: premium,
        ads: ads,
        limits: limits,
        travelQuota: UsageQuota(limits: limits, storage: FileQuotaStorage(fileName: 'travel_quota.json')),
        records: FileRecordStore(),
        previews: PreviewStore(FileQuotaStorage(fileName: 'previews.json')),
      );

  /// 使用統計（事件一律 `qm_` 開頭；不記錄使用者輸入的文字）。
  final Analytics analytics;

  /// 遠端開關（Remote Config，`qm_feature_<id>`、`qm_free_*`）。
  final RemoteFlags flags;

  /// 「分享匿名使用統計與當機報告」；null＝設定頁不顯示（測試、沒有 Firebase）。
  final UsageSharing? usage;

  /// 意見回饋（Firestore `qm_feedback`）；null＝設定頁不顯示。
  final FeedbackSender? feedback;

  /// App 更新提示（Google Play In-App Updates）。
  final AppUpdates updates;

  final PremiumService premium;
  final AdService ads;
  final FreeLimits limits;

  /// 出行訣每日次數。
  final UsageQuota travelQuota;

  /// 紀錄（擇時紀錄＋事後應驗回饋）。
  final RecordStore records;

  /// 訂閱功能「免費完整體驗一次」用過了沒。
  final PreviewStore previews;

  bool get isPremium => premium.isPremium.value;

  /// 功能是否開放（Remote Config `qm_feature_<id>`，預設開）。
  bool featureEnabled(String id) => flags.featureEnabled(id);
}

/// 記錄每個訂閱功能是否已免費體驗過（`previews.json`）。
class PreviewStore {
  PreviewStore(this._storage);

  final QuotaStorage _storage;

  Future<bool> used(String feature) async => (await _storage.read())[feature] == true;

  Future<void> markUsed(String feature) async {
    final m = await _storage.read();
    m[feature] = true;
    await _storage.write(m);
  }
}

class AppServices extends InheritedWidget {
  const AppServices({super.key, required this.services, required super.child});

  final Services services;

  static Services of(BuildContext context) => context.getInheritedWidgetOfExactType<AppServices>()!.services;

  @override
  bool updateShouldNotify(AppServices oldWidget) => services != oldWidget.services;
}
