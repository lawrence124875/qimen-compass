import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/settings/app_settings.dart';
import 'features/travel/travel_page.dart';
import 'features/travel/travel_reminders.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  Notifications.routes[TravelReminders.payload] = () => MaterialPageRoute(builder: (_) => const TravelPage());
  runApp(const QimenApp());
  WidgetsBinding.instance.addPostFrameCallback((_) => Notifications.handleLaunch().catchError((_) {}));
  // 吉時推播：每次啟動重排未來 7 天（通知權限未允許時不排，啟動時也不請求）。
  TravelReminders.reschedule().catchError((_) {});
}
