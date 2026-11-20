import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const s = TimeSettings(utcOffset: Duration(hours: 8));
  const e = NatalReportEngine();
  // 1990-05-20 10:00（+8）：庚午年（陽年）、辛巳月。
  final birth = DateTime.utc(1990, 5, 20, 2);

  test('大運：陽年男順排、女逆排，從月柱起', () {
    final m = e.build(birth, male: true, now: DateTime(2026, 11, 20), settings: s);
    expect(m.forward, isTrue);
    expect(m.daYun.first.pillar.toString(), '壬午');
    expect(m.daYun[1].pillar.toString(), '癸未');
    final f = e.build(birth, male: false, now: DateTime(2026, 11, 20), settings: s);
    expect(f.forward, isFalse);
    expect(f.daYun.first.pillar.toString(), '庚辰');
    for (final d in m.daYun) {
      expect(d.reading, isNotNull);
    }
    expect(m.daYun[1].startAge - m.daYun[0].startAge, closeTo(10, 1e-9));
  });

  test('起運歲：順排到芒種（1990-06-06）約 17 天 → 約 5.6 歲；逆排到立夏（05-06）約 14 天 → 約 4.7 歲', () {
    expect(e.startAge(birth, forward: true), closeTo(5.6, 0.2));
    expect(e.startAge(birth, forward: false), closeTo(4.7, 0.2));
  });

  test('未設定性別不排大運；不知時間不論子女', () {
    final r = e.build(birth, now: DateTime(2026, 11, 20), settings: s, knowTime: false);
    expect(r.daYun, isEmpty);
    expect(r.topics.containsKey(NatalTopic.children), isFalse);
    expect(r.topics.containsKey(NatalTopic.career), isTrue);
    expect(r.topics.containsKey(NatalTopic.wealth), isTrue);
  });

  test('五行關係', () {
    expect(relationTo(1, 3), Relation.shengWo); // 坎水生震木
    expect(relationTo(6, 3), Relation.keWo); // 乾金剋震木
    expect(relationTo(3, 4), Relation.biHe);
  });

  test('本命吉方、關鍵期推播、擇時本命加分', () {
    final n = const PersonalEngine().natal(birth, settings: s);
    final fav = natalFavoredPalaces(n);
    expect(fav.length, 2);
    expect(fav.every(palaceRing.contains), isTrue);
    final year = const ShiJiaEngine().compute(DateTime.utc(2026, 7, 1), settings: s, unit: PanUnit.year);
    for (final v in natalLuckyIn(n, year)) {
      expect(v.level, isNot(TravelLevel.blocked));
    }
    final alerts = fortuneAlerts(n.birth, DateTime.utc(2026, 11, 20), months: 6, settings: s);
    expect(alerts.length, lessThanOrEqualTo(6));
    for (final a in alerts) {
      expect(a.term.index.isOdd, isTrue);
      expect(a.verdict.level == TravelLevel.great || a.verdict.level == TravelLevel.blocked, isTrue);
    }
    final b = n.birth.withNatal([1, 2, 3, 4, 6, 7, 8, 9]);
    final chart = const ShiJiaEngine().compute(DateTime.utc(2026, 11, 20, 2), settings: s);
    final p = chart.palaceOfDoor(Door.kai);
    final r = ZeShiPlanner.scorePalace(chart, Door.kai, p, ZeShiEvent.contract, birth: b);
    expect(r.$2, contains(ZeShiFlag.natalFit));
  });
}
