import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const planner = ZeShiPlanner();
  const tw = TimeSettings();
  final from = DateTime.utc(2026, 11, 17, 4);

  test('前 5 名：分數遞減、同天最多 2 個、都在 7–21 點、都在未來 N 天內', () {
    for (final e in ZeShiEvent.values) {
      final r = planner.best(from, e, days: 14, settings: tw);
      expect(r.length, 5, reason: '$e');
      for (var i = 1; i < r.length; i++) {
        expect(r[i].score <= r[i - 1].score, isTrue);
      }
      final perDay = <int, int>{};
      for (final s in r) {
        final c = s.startUtc.add(const Duration(hours: 8));
        expect(c.hour >= 7 && c.hour < 21, isTrue);
        expect(s.startUtc.isAfter(from) && s.startUtc.isBefore(from.add(const Duration(days: 14))), isTrue);
        expect(e.doors, contains(s.door));
        expect(s.chart.palaceOfDoor(s.door), s.palace);
        perDay.update(c.day, (v) => v + 1, ifAbsent: () => 1);
      }
      expect(perDay.values.every((v) => v <= 2), isTrue);
    }
  });

  test('分數 = 4 + 加分項 − 扣分項', () {
    for (final s in planner.scan(from, ZeShiEvent.opening, days: 3, settings: tw)) {
      final plus = s.flags.where((f) => f.index <= ZeShiFlag.mingJi.index).length;
      expect(s.score, 4 + plus - (s.flags.length - plus));
    }
  });

  test('年命：甲年取旬首六儀；加入生辰會改變分數但不出錯', () {
    final b = BirthInfo.fromInstant(DateTime.utc(1984, 6, 1, 4));
    expect(b.year.toString(), '甲子');
    expect(b.yearStem, 4); // 甲子戊
    final a = planner.scan(from, ZeShiEvent.contract, days: 7, settings: tw);
    final c = planner.scan(from, ZeShiEvent.contract, days: 7, settings: tw, birth: b);
    expect(c.length, a.length);
    expect(c.any((s) => s.flags.contains(ZeShiFlag.mingJi) || s.flags.contains(ZeShiFlag.mingXiong)), isTrue);
  });

  test('自訂情境：只用使用者選的門；就醫取天心加分', () {
    const spec = ZeShiSpec(doors: [Door.du], favoredGod: God.jiuDi);
    final r = planner.best(from, ZeShiEvent.custom, days: 7, settings: tw, spec: spec);
    expect(r, isNotEmpty);
    expect(r.every((s) => s.door == Door.du), isTrue);
    final m = planner.scan(from, ZeShiEvent.medical, days: 14, settings: tw);
    for (final s in m) {
      expect(s.flags.contains(ZeShiFlag.favoredStar), s.chart[s.palace].stars.contains(Star.xin));
    }
  });
}
