import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const planner = ChuXingPlanner();
  const tw = TimeSettings(); // UTC+8

  group('時辰起點', () {
    DateTime start(DateTime utc) => planner.slotStart(utc, tw);

    test('午時 11:30 → 11:00', () {
      expect(start(DateTime.utc(2026, 11, 17, 3, 30)), DateTime.utc(2026, 11, 17, 3));
    });
    test('11:00 整點即為起點', () {
      expect(start(DateTime.utc(2026, 11, 17, 3)), DateTime.utc(2026, 11, 17, 3));
    });
    test('子時跨日：00:30 → 前一天 23:00', () {
      expect(start(DateTime.utc(2026, 11, 16, 16, 30)), DateTime.utc(2026, 11, 16, 15));
    });
    test('23:10 → 23:00', () {
      expect(start(DateTime.utc(2026, 11, 16, 15, 10)), DateTime.utc(2026, 11, 16, 15));
    });
  });

  test('連續 12 個時辰，第一個包含現在', () {
    final now = DateTime.utc(2026, 11, 17, 4, 10);
    final slots = planner.plan(now, TravelEvent.general, settings: tw);
    expect(slots.length, 12);
    expect(slots.first.contains(now), isTrue);
    for (var i = 1; i < slots.length; i++) {
      expect(slots[i].startUtc, slots[i - 1].endUtc);
    }
  });

  test('吉方與盤一致；單一用神門的事類只用該門', () {
    final now = DateTime.utc(2026, 6, 21, 2);
    for (final e in TravelEvent.values) {
      for (final s in planner.plan(now, e, settings: tw, count: 24)) {
        expect(e.doors, contains(s.door));
        final mid = s.startUtc.add(const Duration(hours: 1));
        final chart = const ShiJiaEngine().compute(mid, settings: tw);
        expect(chart.palaceOfDoor(s.door), s.palace);
        expect(chart.hour, s.hour);
        expect(palaceBearing[s.palace], isNotNull);
        expect(s.palace, isNot(5));
      }
    }
  });

  test('一般出行取三吉門中分數最高者', () {
    final now = DateTime.utc(2026, 3, 1);
    final general = planner.plan(now, TravelEvent.general, settings: tw, count: 24);
    final singles = [TravelEvent.wealth, TravelEvent.career, TravelEvent.love]
        .map((e) => planner.plan(now, e, settings: tw, count: 24))
        .toList();
    for (var i = 0; i < general.length; i++) {
      final best = singles.map((l) => l[i].score).reduce((a, b) => a > b ? a : b);
      expect(general[i].score, best);
    }
  });

  test('吉時推播：每天最多一個、都在 7–21 點、都達「吉」、依時間排序', () {
    final now = DateTime.utc(2026, 11, 17, 4);
    for (final e in TravelEvent.values) {
      final best = planner.dailyBest(now, e, settings: tw);
      expect(best.length, lessThanOrEqualTo(7));
      final days = <String>{};
      for (var i = 0; i < best.length; i++) {
        final s = best[i];
        final clock = s.startUtc.add(const Duration(hours: 8));
        expect(clock.hour, inInclusiveRange(7, 20));
        expect(s.recommended, isTrue);
        expect(s.startUtc.isAfter(now), isTrue);
        expect(days.add('${clock.year}-${clock.month}-${clock.day}'), isTrue);
        if (i > 0) expect(s.startUtc.isAfter(best[i - 1].startUtc), isTrue);
      }
    }
  });

  test('五級對應分數', () {
    TravelSlot slot(int score) => TravelSlot(
          startUtc: DateTime.utc(2026),
          endUtc: DateTime.utc(2026, 1, 1, 2),
          hour: const GanZhi(0),
          door: Door.kai,
          palace: 6,
          score: score,
          flags: const [],
        );
    expect(slot(5).level, TravelLevel.great);
    expect(slot(4).level, TravelLevel.good);
    expect(slot(3).level, TravelLevel.neutral);
    expect(slot(2).level, TravelLevel.minor);
    expect(slot(0).level, TravelLevel.blocked);
  });
}
