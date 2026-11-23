import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/services.dart';
import 'app/settings/app_settings.dart';
import 'features/travel/travel_page.dart';
import 'core/admob/admob_ads.dart';
import 'core/firebase/firebase_feedback.dart';
import 'core/firebase/firebase_telemetry.dart';
import 'core/monetization/free_limits.dart';
import 'core/revenuecat/revenuecat_premium.dart';
import 'core/telemetry/cached_remote_flags.dart';
import 'core/telemetry/usage_sharing.dart';
import 'features/course/course.dart';
import 'features/family/family_store.dart';
import 'features/reminders/day_alert_reminder.dart';
import 'features/reminders/natal_alert_reminder.dart';
import 'features/reminders/house_month_reminder.dart';
import 'features/reminders/daily_reminder.dart';
import 'features/house/door_hours.dart';
import 'features/house/house_model.dart' show HouseStore;
import 'features/wear/wear_sync.dart';
import 'l10n/l10n.dart';
import 'features/travel/travel_reminders.dart';
import 'services/notifications.dart';

/// 功能 id（Remote Config `qm_feature_<id>`，預設開）。
const featureIds = ['compass', 'travel', 'divination', 'zeshi', 'house', 'records', 'course', 'map', 'destination', 'almanac', 'personal', 'synastry', 'move', 'facing', 'widget', 'family', 'alerts', 'wear', 'natal_report', 'personal_day'];

Future<void> main() async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  // 啟動加速（各級 Android 機通用）：首頁不等 Firebase、不等網路。
  // - 遠端開關讀本機快取（上次 Remote Config 的值），Firebase 在背景初始化，統計事件先收著、好了再送。
  // - 訂閱狀態先用本機快取。只等本機設定檔，其餘都在首幀之後。
  final sharingStore = FileUsageSharingStore();
  final premiumFuture = RevenueCatPremium.init();
  final settingsFuture = AppSettings.instance.load();
  final flagsFuture = CachedRemoteFlags.load();
  final sharing = await sharingStore.load();
  final analytics = LateAnalytics();
  FirebaseTelemetry? telemetry;
  final telemetryFuture = FirebaseTelemetry.init(featureIds: featureIds, sharing: sharing).then((t) {
    telemetry = t;
    analytics.inner = t.analytics;
    return t;
  });
  final usage = UsageSharing(
    initial: sharing,
    store: sharingStore,
    apply: (v) async => (telemetry ?? await telemetryFuture).setSharing(v),
  );
  final flags = await flagsFuture;
  await settingsFuture;
  // 訂閱與廣告：訂閱戶不載入任何廣告；廣告同意表單在 runApp 之後才跑，不拖慢啟動。
  final limits = FreeLimits.from(flags.intValue);
  final premium = await premiumFuture;
  final ads = AdMobAds.create();
  var appStarted = false;
  void syncAds() {
    ads.enabled = !premium.isPremium.value;
    if (appStarted && ads.enabled) unawaited(ads.start());
  }

  premium.isPremium.addListener(syncAds);
  syncAds();
  // 課程解鎖、吉時推播則數跟訂閱狀態同步
  void syncPremium() {
    CourseAccess.premium.value = premium.isPremium.value;
    final cap = premium.isPremium.value ? 6 : limits.notifyPerDay;
    if (TravelReminders.maxPerDay != cap) {
      TravelReminders.maxPerDay = cap;
      unawaited(TravelReminders.reschedule());
    }
    final clash = premium.isPremium.value || limits.alertClashFree;
    if (DayAlertReminder.clashEnabled != clash) {
      DayAlertReminder.clashEnabled = clash;
      unawaited(DayAlertReminder.reschedule().catchError((_) {}));
    }
    if (NatalAlertReminder.premium != premium.isPremium.value) {
      NatalAlertReminder.premium = premium.isPremium.value;
      HouseMonthReminder.premium = premium.isPremium.value;
      DailyReminder.premium = premium.isPremium.value;
      unawaited(NatalAlertReminder.reschedule().catchError((_) {}));
      unawaited(HouseMonthReminder.reschedule().catchError((_) {}));
      unawaited(DailyReminder.reschedule().catchError((_) {}));
    }
    unawaited(_syncWear());
  }

  TravelReminders.maxPerDay = premium.isPremium.value ? 6 : limits.notifyPerDay;
  CourseAccess.premium.value = premium.isPremium.value;
  DayAlertReminder.clashEnabled = premium.isPremium.value || limits.alertClashFree;
  NatalAlertReminder.premium = premium.isPremium.value;
  HouseMonthReminder.premium = premium.isPremium.value;
  DailyReminder.premium = premium.isPremium.value;
  _wearLocked = () => limits.wearPremium && !premium.isPremium.value;
  premium.isPremium.addListener(syncPremium);
  HouseStore.onChanged = () => Future<void>.delayed(const Duration(milliseconds: 300), DoorHours.reschedule).catchError((_) {});
  // 家人改了：重排重要日提醒（沖生年那一行）
  FamilyStore.changed.addListener(() => DayAlertReminder.reschedule().catchError((_) {}));
  final services = Services.standard(
    analytics: analytics,
    flags: flags,
    premium: premium,
    ads: ads,
    limits: limits,
    usage: usage,
    feedback: const FirestoreFeedbackSender(),
  );
  Notifications.routes[TravelReminders.payload] = () => MaterialPageRoute(builder: (_) => const TravelPage());
  runApp(AppServices(services: services, child: const QimenApp()));
  final runAppMs = startup.elapsedMilliseconds;
  WidgetsBinding.instance.addPostFrameCallback((_) => Notifications.handleLaunch().catchError((_) {}));
  // 啟動加速：首頁畫出來之前什麼都不做；廣告 SDK（會載入 WebView）、推播重排、手錶同步
  // 都在首幀後再等一下、依序做，不跟首頁搶主執行緒。
  unawaited(() async {
    await WidgetsBinding.instance.endOfFrame;
    unawaited(analytics.log('qm_startup', {
      'run_app_ms': runAppMs,
      'first_frame_ms': startup.elapsedMilliseconds,
    }));
    await Future<void>.delayed(const Duration(seconds: 2));
    appStarted = true;
    syncAds();
    AppSettings.instance.refreshGps().catchError((_) {});
    // 吉時推播、每日提醒：每次啟動重排未來 7 天（通知權限未允許時不排，啟動時也不請求）。
    for (final job in <Future<void> Function()>[
      TravelReminders.reschedule,
      DailyReminder.reschedule,
      DayAlertReminder.reschedule,
      NatalAlertReminder.reschedule,
      HouseMonthReminder.reschedule,
      DoorHours.reschedule,
      _syncWear,
    ]) {
      try {
        await job();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }());
}

bool Function() _wearLocked = () => false;

/// 手錶羅盤：每次啟動、訂閱狀態改變時同步 3 天資料（沒有手錶或 Play 服務時什麼都不做）。
Future<void> _syncWear() async {
  try {
    await WearSync.sync(L10n.current, locked: _wearLocked());
  } catch (_) {}
}
