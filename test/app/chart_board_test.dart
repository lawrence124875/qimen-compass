import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/app/theme/app_theme.dart';
import 'package:qimen_compass/app/widgets/chart_board.dart';
import 'package:qimen_compass/engine/engine.dart' hide Element;
import 'package:qimen_compass/l10n/l10n.dart';

Widget _wrap(Widget child, Brightness b, {Locale locale = const Locale('zh')}) => MaterialApp(
      theme: AppTheme.of(b),
      locale: locale,
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

void main() {
  final chart = const ShiJiaEngine().compute(DateTime.utc(2026, 11, 17, 4), settings: const TimeSettings());

  for (final b in Brightness.values) {
    testWidgets('九宮格：八宮＋中宮都畫出（$b）', (tester) async {
      await tester.pumpWidget(_wrap(ChartBoard(chart: chart), b));
      expect(find.byType(PalaceCell), findsNWidgets(8));
      for (final p in const [1, 2, 3, 4, 6, 7, 8, 9]) {
        expect(find.text('${palaceNames[p]}$p'), findsOneWidget);
      }
      expect(find.text('${chart.dun.zh}${chart.ju}局'), findsOneWidget);
      // 八門都在盤上
      for (final d in Door.values) {
        expect(find.text(d.zh), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('點宮位開啟詳情（英文介面含拼音）', (tester) async {
    L10n.language = AppLanguages.en;
    await tester.pumpWidget(_wrap(ChartBoard(chart: chart), Brightness.dark, locale: const Locale('en')));
    final p = chart.palaceOfDoor(Door.kai);
    await tester.tap(find.text('${palaceNames[p]}$p'));
    await tester.pumpAndSettle();
    expect(find.byType(PalaceDetail), findsOneWidget);
    expect(find.textContaining('Kāi Mén'), findsOneWidget);
    L10n.language = AppLanguages.zhHant;
  });

  testWidgets('小尺寸不溢位', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.of(Brightness.light),
      home: Center(child: SizedBox(width: 240, child: ChartBoard(chart: chart))),
    ));
    expect(tester.takeException(), isNull);
  });
}
