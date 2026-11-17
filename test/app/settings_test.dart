import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/app/pages/settings_page.dart';
import 'package:qimen_compass/app/settings/app_settings.dart';
import 'package:qimen_compass/app/settings/cities.dart';
import 'package:qimen_compass/app/theme/app_theme.dart';
import 'package:qimen_compass/engine/engine.dart' hide Element;
import 'package:qimen_compass/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  test('排盤設定轉成 TimeSettings', () {
    final s = AppSettings.instance;
    expect(s.timeSettingsAt(DateTime.now()).trueSolarTime, isFalse);
    s.solarCityIndex = 0;
    s.ziHour = ZiHourMode.lateZi;
    final t = s.timeSettingsAt(DateTime.now());
    expect(t.trueSolarTime, isTrue);
    expect(t.longitude, kCities[0].longitude);
    expect(t.ziHour, ZiHourMode.lateZi);
    s.solarCityIndex = -1;
    s.ziHour = ZiHourMode.nextDay;
  });

  test('引導看過後記住', () {
    final s = AppSettings.instance;
    expect(s.guideSeen('home'), isFalse);
    s.markGuideSeen('home');
    expect(s.guideSeen('home'), isTrue);
  });

  testWidgets('設定頁可切換定元方法', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.of(Brightness.dark),
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SettingsPage(),
    ));
    await tester.tap(find.text('置閏法'));
    await tester.pump();
    expect(AppSettings.instance.juMethod, JuMethod.zhiRun);
    AppSettings.instance.juMethod = JuMethod.chaiBu;
  });
}
