import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const QimenApp());
}
