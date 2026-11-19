import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const s = TimeSettings(utcOffset: Duration(hours: 8));

  test('冬至當天換局、前一天四離', () {
    // 2024 冬至：2024-12-21 17:20（北京時間）
    final eve = DayAlerts.of(DateTime(2024, 12, 20), settings: s);
    final day = DayAlerts.of(DateTime(2024, 12, 21), settings: s);
    expect(eve.kinds, contains(DayAlertKind.siLi));
    expect(eve.kinds, isNot(contains(DayAlertKind.termChange)));
    expect(day.kinds, contains(DayAlertKind.termChange));
    expect(day.term!.index, 0);
  });

  test('立春前一天四絕', () {
    // 2025 立春：2025-02-03 22:10（北京時間）
    expect(DayAlerts.of(DateTime(2025, 2, 2), settings: s).kinds, contains(DayAlertKind.siJue));
  });

  test('月破、歲破與沖生年依日支判定', () {
    var yuePo = 0, suiPo = 0;
    for (var i = 0; i < 60; i++) {
      final a = DayAlerts.of(DateTime(2026, 3, 1).add(Duration(days: i)), settings: s);
      expect(a.kinds.contains(DayAlertKind.yuePo), (a.day.branch + 6) % 12 == a.month.branch);
      expect(a.kinds.contains(DayAlertKind.suiPo), (a.day.branch + 6) % 12 == a.year.branch);
      if (a.kinds.contains(DayAlertKind.yuePo)) yuePo++;
      if (a.kinds.contains(DayAlertKind.suiPo)) suiPo++;
    }
    expect(yuePo, inInclusiveRange(4, 6));
    expect(suiPo, inInclusiveRange(4, 6));
    final a = DayAlerts.of(DateTime(2026, 3, 1), settings: s);
    expect(a.clashes(GanZhi((a.day.index + 6) % 60)), isTrue);
    expect(a.clashes(a.day), isFalse);
  });

  test('家人盤：出門、簽約最佳時辰落在當天 7–21 點', () {
    final b = BirthInfo.fromInstant(DateTime.utc(1990, 5, 20, 2), settings: s);
    final r = const FamilyDayPlanner().evaluate(b, DateTime(2026, 11, 20), settings: s);
    for (final slot in [r.travel, r.contract]) {
      expect(slot, isNotNull);
      final local = slot!.startUtc.add(const Duration(hours: 8));
      expect(local.day, 20);
      expect(local.hour, inInclusiveRange(7, 20));
    }
    expect(r.suits(r.travel), r.travel!.score >= 5 && !r.clash);
  });
}
