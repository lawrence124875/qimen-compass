import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const s = TimeSettings(utcOffset: Duration(hours: 8));
  final birth = DateTime.utc(1990, 5, 20, 2); // 庚午年
  final now = DateTime.utc(2026, 11, 20, 1); // +8 09:00

  test('今日個人運：有年命宮吉凶；有性別才有大運', () {
    final m = PersonalDay.of(birth, male: true, now: now, birthSettings: s, settings: s);
    expect(m.fortune, isNotNull);
    expect(m.level, isNotNull);
    expect(m.daYun, isNotNull);
    expect(m.daYunToday, isNotNull);
    expect(m.hours.length, lessThanOrEqualTo(3));
    for (final h in m.hours) {
      expect(h.recommended, isTrue);
      expect(h.startUtc!.isAfter(now.subtract(const Duration(hours: 2))), isTrue);
    }
    final n = PersonalDay.of(birth, now: now, birthSettings: s, settings: s);
    expect(n.daYun, isNull);
    expect(n.fortune?.palace, m.fortune?.palace);
  });
}
