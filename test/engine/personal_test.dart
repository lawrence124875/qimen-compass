import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const s = TimeSettings(utcOffset: Duration(hours: 8));
  const e = PersonalEngine();

  test('本命盤：年命、日干都找得到宮位', () {
    final r = e.natal(DateTime.utc(1990, 5, 20, 2), settings: s);
    expect(r.ming, isNotNull);
    expect(r.self, isNotNull);
    expect(r.chart[r.ming!.palace].heavenStems, contains(r.birth.yearStem));
  });

  test('流年流月與個人吉方', () {
    final b = BirthInfo.fromInstant(DateTime.utc(1990, 5, 20, 2), settings: s);
    expect(e.fortune(b, DateTime.utc(2026, 7, 1), PanUnit.year, settings: s).verdict, isNotNull);
    expect(e.fortune(b, DateTime.utc(2026, 11, 15), PanUnit.month, settings: s).verdict, isNotNull);
    final hits = e.luckyHours(b, DateTime.utc(2026, 11, 19), settings: s);
    expect(hits.length, lessThanOrEqualTo(5));
    for (final h in hits) {
      expect(h.recommended, isTrue);
    }
  });
}
