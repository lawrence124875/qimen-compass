import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/travel/travel_reminders.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QimenApp());
  // 吉時推播：每次啟動重排未來 7 天（通知權限未允許時不排，啟動時也不請求）。
  TravelReminders.reschedule().catchError((_) {});
}
