// 商店截圖（Play 上架用）：11 語 × 數個畫面，輸出 1080×1920 PNG 到 test/store/goldens/<語言>/。
// 只在 workflow store_screenshots.yml 執行：flutter test test/store --update-goldens --dart-define=STORE_SHOTS=true
// 平常的 flutter test 會跳過。
import 'dart:io';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/app/home_page.dart';
import 'package:qimen_compass/app/services.dart';
import 'package:qimen_compass/app/settings/app_settings.dart';
import 'package:qimen_compass/app/theme/app_theme.dart';
import 'package:qimen_compass/core/monetization/premium_service.dart';
import 'package:qimen_compass/features/course/course_page.dart';
import 'package:qimen_compass/features/divination/divination_page.dart';
import 'package:qimen_compass/features/travel/travel_page.dart';
import 'package:qimen_compass/features/zeshi/zeshi_page.dart';
import 'package:qimen_compass/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _enabled = bool.fromEnvironment('STORE_SHOTS');

Future<void> _loadFonts() async {
  final families = <String, List<String>>{
    'QmSans': ['assets/fonts/QmSans-Regular.otf', 'assets/fonts/QmSans-Bold.otf'],
    'QmSerif': ['assets/fonts/QmSerif-Regular.otf', 'assets/fonts/QmSerif-Bold.otf'],
    'QmFbSC': ['assets/fonts/QmFbSC-Regular.otf'],
    'QmFbJP': ['assets/fonts/QmFbJP-Regular.otf'],
    'QmFbKR': ['assets/fonts/QmFbKR-Regular.otf'],
    'QmFbTH': ['assets/fonts/QmFbTH-Regular.ttf'],
    'QmFbAR': ['assets/fonts/QmFbAR-Regular.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }
  // Material 圖示字型在 Flutter SDK 裡
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

final _screens = <String, Widget Function()>{
  '1_chart': () => const HomePage(),
  '2_travel': () => const TravelPage(),
  '3_zeshi': () => const ZeShiPage(),
  '4_divination': () => const DivinationPage(),
  '5_course': () => const CoursePage(),
};

void main() {
  if (!_enabled) {
    test('商店截圖（略過）', () {}, skip: '只在 store_screenshots.yml 執行');
    return;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'qm_guide_seen_home': true, 'qm_guide_seen_house': true});
    await AppSettings.instance.load();
    await _loadFonts();
    debugDisableShadows = false;
  });

  for (final lang in AppLanguages.all) {
    for (final s in _screens.entries) {
      testWidgets('${lang.code} ${s.key}', (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        L10n.language = lang;
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(Brightness.dark),
          locale: lang.locale,
          supportedLocales: [for (final l in AppLanguages.all) l.locale],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppServices(services: Services(premium: FreePremium(premium: true)), child: s.value()),
        ));
        // 讓非同步載入（App 內容 JSON 等）完成
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${lang.code}/${s.key}.png'));
      });
    }
  }

  // 主題圖片 1024×500（每語一張）：圖示＋名稱＋簡短說明，文字取自 store/listing.json
  final listing = jsonDecode(File('store/listing.json').readAsStringSync()) as Map<String, dynamic>;
  final iconBytes = File('branding/play_icon_512.png').readAsBytesSync();
  for (final lang in AppLanguages.all) {
    testWidgets('${lang.code} feature', (tester) async {
      tester.view.physicalSize = const Size(1024, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l = listing[lang.code] as Map<String, dynamic>;
      final theme = AppTheme.of(Brightness.dark);
      final icon = MemoryImage(iconBytes);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: lang.locale,
        supportedLocales: [for (final l in AppLanguages.all) l.locale],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Builder(builder: (context) {
          final t = Theme.of(context).textTheme;
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.55, 0),
                  radius: 1.2,
                  colors: [cs.primary.withValues(alpha: 0.28), cs.surface],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(56), child: Image(image: icon, width: 260, height: 260)),
                const SizedBox(width: 56),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lookupAppLocalizations(lang.locale).appTitle,
                        style: serif(t.displaySmall)?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
                    const SizedBox(height: 20),
                    Text(l['short'] as String,
                        style: t.titleLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.8), height: 1.4)),
                  ]),
                ),
              ]),
            ),
          );
        }),
      ));
      await tester.runAsync(() => precacheImage(icon, tester.element(find.byType(Scaffold))));
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${lang.code}/0_feature.png'));
    });
  }
}
