import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  test('黃曆：子時起 12 個連續時辰、吉時依時間排序', () {
    const s = TimeSettings(utcOffset: Duration(hours: 8));
    final a = DailyAlmanac.of(DateTime(2026, 11, 19), settings: s);
    expect(a.slots.length, 12);
    // 第一個時辰從前一天 23:00（台北）開始＝15:00 UTC
    expect(a.slots.first.startUtc, DateTime.utc(2026, 11, 18, 15));
    for (var i = 1; i < 12; i++) {
      expect(a.slots[i].startUtc, a.slots[i - 1].endUtc);
    }
    final b = a.best();
    expect(b.length, lessThanOrEqualTo(3));
    for (var i = 1; i < b.length; i++) {
      expect(b[i].startUtc.isAfter(b[i - 1].startUtc), isTrue);
    }
    if (b.isNotEmpty) expect(a.bestPalace, isNotNull);
  });
}
