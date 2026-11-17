import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/settings/app_settings.dart';
import 'features/travel/travel_reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const QimenApp());
  // 吉時推播：每次啟動重排未來 7 天（通知權限未允許時不排，啟動時也不請求）。
  TravelReminders.reschedule().catchError((_) {});
}
