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
import 'features/reminders/daily_reminder.dart';
import 'features/travel/travel_reminders.dart';
import 'services/notifications.dart';

/// 功能 id（Remote Config `qm_feature_<id>`，預設開）。
const featureIds = ['compass', 'travel', 'divination', 'zeshi', 'house', 'records', 'course', 'map', 'destination'];

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
}
