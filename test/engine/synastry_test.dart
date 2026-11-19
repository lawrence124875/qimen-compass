import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const s = TimeSettings(utcOffset: Duration(hours: 8));
  BirthInfo y(String ganzhi) => BirthInfo(year: GanZhi.parse(ganzhi), day: GanZhi.parse('甲子'));

  test('合沖判斷', () {
    const e = SynastryEngine();
    final at = DateTime.utc(2026, 7, 1);
    // 甲己合、子丑合
    var r = e.read(y('甲子'), y('己丑'), SynMode.marriage, at, settings: s);
    expect(r.factors, containsAll([SynFactor.stemHe, SynFactor.branchLiuHe]));
    // 子午沖
    r = e.read(y('甲子'), y('丙午'), SynMode.partner, at, settings: s);
    expect(r.factors, contains(SynFactor.branchChong));
    // 申子辰三合
    r = e.read(y('甲子'), y('丙辰'), SynMode.partner, at, settings: s);
    expect(r.factors, contains(SynFactor.branchSanHe));
    expect(r.palaceA, isNotNull);
    expect(r.score, 3 + r.factors.where((f) => f.good).length - r.factors.where((f) => !f.good).length);
  });
}
