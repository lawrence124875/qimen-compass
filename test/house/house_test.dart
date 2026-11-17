import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/app/theme/app_theme.dart';
import 'package:qimen_compass/engine/engine.dart' hide Element, palaceBearing;
import 'package:qimen_compass/features/house/house_geometry.dart';
import 'package:qimen_compass/features/house/house_model.dart';
import 'package:qimen_compass/features/house/house_widgets.dart';
import 'package:qimen_compass/features/house/plan_editor_page.dart';
import 'package:qimen_compass/l10n/l10n.dart';

void main() {
  group('平面圖方位', () {
    const c = Offset(5, 5);
    test('圖上方朝北：上＝坎1、右＝震3、下＝離9、左＝兌7', () {
      expect(palaceAtPoint(c, const Offset(5, 0), 0, centerR: 1), 1);
      expect(palaceAtPoint(c, const Offset(10, 5), 0, centerR: 1), 3);
      expect(palaceAtPoint(c, const Offset(5, 10), 0, centerR: 1), 9);
      expect(palaceAtPoint(c, const Offset(0, 5), 0, centerR: 1), 7);
      expect(palaceAtPoint(c, const Offset(10, 0), 0, centerR: 1), 8); // 右上＝東北
      expect(palaceAtPoint(c, const Offset(5.5, 5), 0, centerR: 1), 5);
    });
    test('圖上方朝東（90°）：上＝震3、左＝坎1', () {
      expect(palaceAtPoint(c, const Offset(5, 0), 90, centerR: 1), 3);
      expect(palaceAtPoint(c, const Offset(0, 5), 90, centerR: 1), 1);
      expect(bearingInPlan(c, const Offset(5, 10), 90), closeTo(270, 1e-9));
    });
    test('planDirection 與 bearingInPlan 互逆', () {
      for (final up in [0.0, 37.0, 200.0]) {
        for (final b in [0.0, 45.0, 123.0, 300.0]) {
          final p = c + planDirection(b, up) * 3;
          expect(bearingInPlan(c, p, up), closeTo(b, 1e-6));
        }
      }
    });
    test('房間含中心點算中五宮', () {
      expect(palaceOfRect(c, const Rect.fromLTWH(4, 4, 3, 3), 0, centerR: 0.5), 5);
      expect(palaceOfRect(c, const Rect.fromLTWH(4, 0, 2, 2), 0, centerR: 0.5), 1);
    });
    test('rayToBounds', () {
      expect(rayToBounds(c, const Offset(1, 0), const Rect.fromLTWH(0, 0, 10, 10)), closeTo(5, 1e-9));
      expect(rayToBounds(const Offset(2, 5), const Offset(-1, 0), const Rect.fromLTWH(0, 0, 10, 10)), closeTo(2, 1e-9));
    });
  });

  group('重心', () {
    test('單一長方形', () {
      final g = unionCentroid([const Rect.fromLTWH(0, 0, 4, 2)])!;
      expect(g.dx, closeTo(2, 1e-9));
      expect(g.dy, closeTo(1, 1e-9));
    });
    test('L 形（重疊不重複計算）', () {
      // 4×2 橫條＋2×4 直條，重疊 2×2 → L 形面積 12
      final rs = [const Rect.fromLTWH(0, 0, 4, 2), const Rect.fromLTWH(0, 0, 2, 4)];
      expect(unionArea(rs), closeTo(12, 1e-9));
      final g = unionCentroid(rs)!;
      // (8×(2,1) + 4×(1,3)) / 12 = (5/3, 5/3)
      expect(g.dx, closeTo(5 / 3, 1e-9));
      expect(g.dy, closeTo(5 / 3, 1e-9));
    });
    test('空清單', () => expect(unionCentroid([]), isNull));
  });

  group('透視校正', () {
    test('四點對應', () {
      const src = [Offset(10, 20), Offset(300, 40), Offset(320, 400), Offset(5, 380)];
      const dst = [Offset(0, 0), Offset(100, 0), Offset(100, 120), Offset(0, 120)];
      final h = homography(src, dst)!;
      for (var i = 0; i < 4; i++) {
        final p = applyHomography(h, src[i]);
        expect(p.dx, closeTo(dst[i].dx, 1e-6));
        expect(p.dy, closeTo(dst[i].dy, 1e-6));
      }
    });
    test('退化（三點共線）回傳 null', () {
      expect(homography(const [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(3, 0)], const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)]), isNull);
    });
    test('長寬比估計', () {
      expect(estimateAspect(const [Offset(0, 0), Offset(200, 0), Offset(200, 100), Offset(0, 100)]), closeTo(2, 1e-9));
    });
    test('坐向', () => expect(sittingOf(30), 210));
  });

  test('House JSON 來回', () {
    final h = House(sittingMethod: SittingMethod.light, facing: 135, moveIn: DateTime(2020, 5, 6, 9, 30), moveInHasTime: true)
      ..marked.add(MarkedRoom('主臥', 10))
      ..marked.add(MarkedRoom('客廳', null))
      ..plan = (FloorPlan(aspect: 1.5, upBearing: 90, northSet: true, manualCenter: const Offset(3, 4))
        ..rooms.add(PlanRoom('廚房', rect: const Rect.fromLTWH(0, 0, 3, 3)))
        ..rooms.add(PlanRoom('書房', pin: const Offset(17, 6))));
    final r = House.fromJson(h.toJson());
    expect(r.sittingMethod, SittingMethod.light);
    expect(r.facing, 135);
    expect(r.moveIn, DateTime(2020, 5, 6, 9, 30));
    expect(r.moveInHasTime, isTrue);
    expect(r.marked.map((m) => m.palace), [1, 5]);
    expect(r.plan!.aspect, 1.5);
    expect(r.plan!.center, const Offset(3, 4));
    expect(r.plan!.rooms.length, 2);
    expect(r.plan!.rooms[0].rect, const Rect.fromLTWH(0, 0, 3, 3));
    expect(r.plan!.rooms[1].pin, const Offset(17, 6));
    final byPalace = r.roomsByPalace();
    expect(byPalace[1], ['主臥']);
    expect(byPalace[5], ['客廳']);
    // 圖上方朝東、中心 (3,4)：書房在右邊（圖右＝南）→ 離9
    expect(r.plan!.palaceOf(r.plan!.rooms[1]), 9);
  });

  test('壞掉的 JSON 不當機', () {
    final h = House.fromJson({'plan': {'rooms': [{'n': 'x'}]}, 'marked': []});
    expect(h.plan!.rooms, isEmpty);
  });

  final chart = const ShiJiaEngine().compute(DateTime.utc(2026, 11, 17, 4), settings: const TimeSettings());
  Widget wrap(Widget child, Brightness b) => MaterialApp(
        theme: AppTheme.of(b),
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: Center(child: SizedBox(width: 360, height: 480, child: child))),
      );

  for (final b in Brightness.values) {
    testWidgets('方位圖與手繪平面圖可繪製（$b）', (tester) async {
      await tester.pumpWidget(wrap(Builder(builder: (context) {
        final labels = sectorLabels(context, chart);
        final plan = FloorPlan()..rooms.add(PlanRoom('客廳', rect: const Rect.fromLTWH(2, 2, 6, 6)));
        return Column(children: [
          Expanded(child: BearingWheel(labels: labels, rooms: const [('主臥', 10.0), ('客廳', null)], pointer: 30)),
          Expanded(child: PlanCanvas(plan: plan, labels: labels)),
        ]);
      }), b));
      expect(tester.takeException(), isNull);
    });
  }
}
