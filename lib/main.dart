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
import 'core/telemetry/usage_sharing.dart';
import 'features/course/course.dart';
import 'features/family/family_store.dart';
import 'features/reminders/day_alert_reminder.dart';
import 'features/reminders/daily_reminder.dart';
import 'features/wear/wear_sync.dart';
import 'l10n/l10n.dart';
import 'features/travel/travel_reminders.dart';
import 'services/notifications.dart';

/// 功能 id（Remote Config `qm_feature_<id>`，預設開）。
const featureIds = ['compass', 'travel', 'divination', 'zeshi', 'house', 'records', 'course', 'map', 'destination', 'almanac', 'personal', 'synastry', 'move', 'facing', 'widget', 'family', 'alerts', 'wear'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 放最前面才接得到啟動中的當機；失敗不影響 App（統計不送、遠端開關全照預設）。
  final sharingStore = FileUsageSharingStore();
  final sharing = await sharingStore.load();
  final telemetry = await FirebaseTelemetry.init(featureIds: featureIds, sharing: sharing);
  final usage = UsageSharing(initial: sharing, store: sharingStore, apply: telemetry.setSharing);
  await AppSettings.instance.load();
  // 訂閱與廣告：訂閱戶不載入任何廣告；廣告同意表單在 runApp 之後才跑，不拖慢啟動。
  final limits = FreeLimits.from(telemetry.flags.intValue);
  final premium = await RevenueCatPremium.init();
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
    unawaited(_syncWear());
  }

  TravelReminders.maxPerDay = premium.isPremium.value ? 6 : limits.notifyPerDay;
  CourseAccess.premium.value = premium.isPremium.value;
  DayAlertReminder.clashEnabled = premium.isPremium.value || limits.alertClashFree;
  _wearLocked = () => limits.wearPremium && !premium.isPremium.value;
  premium.isPremium.addListener(syncPremium);
  // 家人改了：重排重要日提醒（沖生年那一行）
  FamilyStore.changed.addListener(() => DayAlertReminder.reschedule().catchError((_) {}));
  final services = Services.standard(
    analytics: telemetry.analytics,
    flags: telemetry.flags,
    premium: premium,
    ads: ads,
    limits: limits,
    usage: usage,
    feedback: telemetry.available ? const FirestoreFeedbackSender() : null,
  );
  Notifications.routes[TravelReminders.payload] = () => MaterialPageRoute(builder: (_) => const TravelPage());
  runApp(AppServices(services: services, child: const QimenApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) => Notifications.handleLaunch().catchError((_) {}));
  appStarted = true;
  syncAds();
  // 吉時推播、每日提醒：每次啟動重排未來 7 天（通知權限未允許時不排，啟動時也不請求）。
  AppSettings.instance.refreshGps().catchError((_) {});
  TravelReminders.reschedule().catchError((_) {});
  DailyReminder.reschedule().catchError((_) {});
  DayAlertReminder.reschedule().catchError((_) {});
  // 手錶資料要算 36 個時辰，等首頁畫好再做
  unawaited(Future<void>.delayed(const Duration(seconds: 5), _syncWear));
}

bool Function() _wearLocked = () => false;

/// 手錶羅盤：每次啟動、訂閱狀態改變時同步 3 天資料（沒有手錶或 Play 服務時什麼都不做）。
Future<void> _syncWear() async {
  try {
    await WearSync.sync(L10n.current, locked: _wearLocked());
  } catch (_) {}
}
