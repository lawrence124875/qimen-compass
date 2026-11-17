import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const engine = ShiJiaEngine();
  QimenChart chart(DateTime utc, PanUnit u) => engine.compute(utc, unit: u);

  group('年盤', () {
    test('三元：1864 上元陰一、1924 中元陰四、1984 下元陰七', () {
      for (final (y, ju, yuan) in [(1900, 1, Yuan.upper), (1950, 4, Yuan.middle), (2026, 7, Yuan.lower), (2044, 1, Yuan.upper)]) {
        final c = chart(DateTime.utc(y, 6, 1), PanUnit.year);
        expect(c.dun, Dun.yin, reason: '$y');
        expect(c.ju, ju, reason: '$y');
        expect(c.yuan, yuan, reason: '$y');
        expect(c.unit, PanUnit.year);
        expect(c.pivot, c.year);
      }
    });

    test('以立春換年：2044-01-20 仍屬 2043（下元）', () {
      final c = chart(DateTime.utc(2044, 1, 20), PanUnit.year);
      expect(c.year.toString(), '癸亥');
      expect(c.ju, 7);
    });

    test('2026 丙午年：旬首甲辰，空亡寅卯', () {
      final c = chart(DateTime.utc(2026, 6, 1), PanUnit.year);
      expect(c.pivot.toString(), '丙午');
      expect(c.xunShou.toString(), '甲辰');
      expect(c[8].kongWang && c[3].kongWang, isTrue);
    });
  });

  group('月盤', () {
    test('年支定元：子午卯酉陰七、寅申巳亥陰一、辰戌丑未陰四', () {
      expect(chart(DateTime.utc(2026, 6, 1), PanUnit.month).ju, 7); // 午年
      expect(chart(DateTime.utc(2025, 6, 1), PanUnit.month).ju, 1); // 巳年
      expect(chart(DateTime.utc(2024, 6, 1), PanUnit.month).ju, 4); // 辰年
    });

    test('起局柱為月柱，依節換月', () {
      final a = chart(DateTime.utc(2026, 6, 1), PanUnit.month);
      expect(a.pivot, a.month);
      expect(a.dun, Dun.yin);
      final b = chart(DateTime.utc(2026, 7, 1), PanUnit.month);
      expect(b.pivot, isNot(a.pivot));
    });
  });

  test('年盤、月盤結構：九星、八門、八神各一份', () {
    var d = DateTime.utc(2000, 1, 1);
    for (var i = 0; i < 400; i++, d = d.add(const Duration(days: 23))) {
      for (final u in [PanUnit.month, PanUnit.year]) {
        final c = engine.compute(d, unit: u);
        expect(c.palaces.values.expand((p) => p.stars).toSet().length, 9);
        expect(c.palaces.values.map((p) => p.door).whereType<Door>().toSet().length, 8);
        expect(c.palaces.values.map((p) => p.god).whereType<God>().toSet().length, 8);
        if (c.pivot.stem == 0) expect(c.starFuYin && c.doorFuYin, isTrue);
      }
    }
  });
}
