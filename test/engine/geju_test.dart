import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

/// 天干索引：甲0 乙1 丙2 丁3 戊4 己5 庚6 辛7 壬8 癸9。
PalaceChart _cell({List<int> h = const [], List<int> e = const [], List<Star> s = const [], Door? d, God? g}) =>
    PalaceChart(1)
      ..heavenStems.addAll(h)
      ..earthStems.addAll(e)
      ..stars.addAll(s)
      ..door = d
      ..god = g;

void main() {
  test('三遁', () {
    expect(stemPatterns(_cell(h: [2], e: [3], d: Door.sheng)), [GeJu.sanDun]); // 天遁
    expect(stemPatterns(_cell(h: [1], e: [5], d: Door.kai)), [GeJu.sanDun]); // 地遁
    expect(stemPatterns(_cell(h: [3], e: [8], d: Door.xiu, g: God.taiYin)), [GeJu.sanDun]); // 人遁
    expect(stemPatterns(_cell(h: [2], e: [3], d: Door.kai)), isEmpty); // 門不對
  });

  test('四凶格與庚丙', () {
    for (final (h, e) in [(1, 7), (7, 1), (3, 9), (9, 3)]) {
      expect(stemPatterns(_cell(h: [h], e: [e])), [GeJu.siXiong], reason: '$h加$e');
    }
    expect(stemPatterns(_cell(h: [6], e: [2])), [GeJu.gengBing]);
    expect(stemPatterns(_cell(h: [2], e: [6])), [GeJu.gengBing]);
    expect(stemPatterns(_cell(h: [1], e: [1])), isEmpty);
  });

  test('九星吉凶，吉凶同宮相抵', () {
    expect(starLuck(_cell(s: [Star.xin])), GeJu.goodStar);
    expect(starLuck(_cell(s: [Star.peng])), GeJu.badStar);
    expect(starLuck(_cell(s: [Star.rui, Star.qin])), isNull);
    expect(starLuck(_cell(s: [Star.chong])), isNull);
  });

  test('擇時與出行都把格局算進分數', () {
    final from = DateTime.utc(2026, 3, 1);
    final z = const ZeShiPlanner().scan(from, ZeShiEvent.journey, days: 30);
    expect(z.any((s) => s.flags.any((f) => {ZeShiFlag.goodStar, ZeShiFlag.badStar}.contains(f))), isTrue);
    final t = const ChuXingPlanner().plan(from, TravelEvent.general, count: 360);
    expect(t.any((s) => s.flags.contains(TravelFlag.goodStar) || s.flags.contains(TravelFlag.badStar)), isTrue);
  });
}
