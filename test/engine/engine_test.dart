import 'package:flutter_test/flutter_test.dart';
import 'package:lunar/lunar.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  const cal = CalendarService();
  const engine = ShiJiaEngine();
  const lunarTerms = [
    '冬至', '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满', '芒种', //
    '夏至', '小暑', '大暑', '立秋', '处暑', '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪',
  ];

  test('日柱、時柱、節氣與 lunar 套件一致（1950–2060 抽樣）', () {
    for (var d = DateTime.utc(1950, 1, 1, 4); d.isBefore(DateTime.utc(2060)); d = d.add(const Duration(days: 37, hours: 5))) {
      final m = cal.momentAt(d, const TimeSettings());
      final bj = d.add(const Duration(hours: 8));
      final l = Solar.fromYmdHms(bj.year, bj.month, bj.day, bj.hour, bj.minute, 0).getLunar();
      expect(m.day.toString(), l.getDayInGanZhiExact(), reason: '$bj 日柱');
      expect(m.hour.toString(), l.getTimeInGanZhi(), reason: '$bj 時柱');
      expect(lunarTerms[m.term.index], l.getPrevJieQi(false).getName(), reason: '$bj 節氣');
    }
  });

  test('2000-01-01 為戊午日', () {
    expect(CalendarService.dayGanZhi(2451545).toString(), '戊午');
  });

  test('子時換日：23 點起換日；晚子時日柱不換、時柱用次日', () {
    final t = DateTime.utc(2024, 3, 1, 15, 30); // 北京 23:30
    final next = cal.momentAt(t, const TimeSettings());
    final late = cal.momentAt(t, const TimeSettings(ziHour: ZiHourMode.lateZi));
    final before = cal.momentAt(DateTime.utc(2024, 3, 1, 14, 30), const TimeSettings());
    expect(next.day, isNot(before.day));
    expect(late.day, before.day);
    expect(late.hour, next.hour);
    expect(next.hour.branch, 0);
  });

  test('真太陽時：東經 120 度、時區 +8 時約只差均時差', () {
    final t = DateTime.utc(2024, 11, 3, 4);
    final c = cal.clockTime(t, const TimeSettings(trueSolarTime: true, longitude: 120));
    final diff = c.difference(t.add(const Duration(hours: 8))).inSeconds / 60;
    expect(diff, closeTo(16.4, 0.6)); // 11 月初均時差約 +16.4 分
  });

  test('陽遁一局地盤：戊1 己2 庚3 辛4 壬5 癸6 丁7 丙8 乙9', () {
    // 2024-12-31 前後為冬至上元陽一局（拆補）；直接用 buildChart 驗證地盤。
    final m = cal.momentAt(DateTime.utc(2025, 1, 1, 4), const TimeSettings());
    final c = engine.buildChart(m, const JuInfo(Dun.yang, 1, Yuan.upper, 0));
    final order = [for (var p = 1; p <= 9; p++) stemNames[c[p].earthStems.first]].join();
    expect(order, '戊己庚辛壬癸丁丙乙');
    expect(c[2].earthStems.length, 2); // 中五寄坤
  });

  test('陰遁九局地盤：戊9 己8 庚7 辛6 壬5 癸4 丁3 丙2 乙1', () {
    final m = cal.momentAt(DateTime.utc(2025, 6, 22, 4), const TimeSettings());
    final c = engine.buildChart(m, const JuInfo(Dun.yin, 9, Yuan.upper, 12));
    final order = [for (var p = 9; p >= 1; p--) stemNames[c[p].earthStems.first]].join();
    expect(order, '戊己庚辛壬癸丁丙乙');
  });

  test('甲時為伏吟；每張盤九星、八門、八神各一份', () {
    var d = DateTime.utc(2024, 1, 1);
    for (var i = 0; i < 2000; i++, d = d.add(const Duration(hours: 2, minutes: 13))) {
      final c = engine.compute(d);
      final stars = c.palaces.values.expand((p) => p.stars).toList();
      expect(stars.toSet().length, 9);
      expect(stars.length, 9);
      expect(c.palaces.values.map((p) => p.door).whereType<Door>().toSet().length, 8);
      expect(c.palaces.values.map((p) => p.god).whereType<God>().toSet().length, 8);
      expect(c.palaces.values.expand((p) => p.heavenStems).length, 9);
      if (c.hour.stem == 0) {
        expect(c.starFuYin && c.doorFuYin, isTrue, reason: '${c.hour}');
      }
      // 星伏吟時天盤必同地盤（kinqimen 在時干入中五時算錯天盤，本引擎以此規則把關）
      if (c.starFuYin) {
        for (final p in c.palaces.values.where((p) => p.palace != 5)) {
          expect(p.heavenStems.first, p.earthStems.first, reason: '${c.hour} ${p.palace}宮');
        }
      }
      expect(c[c.palaceOfDoor(c.zhiShi)].door, c.zhiShi);
      // 值符神與值符星同宮
      final zf = c.palaces.values.firstWhere((p) => p.god == God.zhiFu);
      expect(zf.stars.contains(c.zhiFu) || (c.zhiFu == Star.qin && zf.stars.contains(Star.rui)), isTrue);
    }
  });

  test('定元：拆補法依符頭；置閏法 2024 年大雪置閏', () {
    // 2024-12-15 前後（癸丑日附近）置閏法仍為大雪，拆補法同為大雪
    final m = cal.momentAt(DateTime.utc(2024, 12, 20, 4), const TimeSettings());
    final z = engine.juZhiRun(m, const TimeSettings());
    expect(solarTermNames[z.termIndex], '大雪');
  });

  test('日家盤尚未實作（V3）', () {
    expect(() => engine.compute(DateTime.utc(2024), unit: PanUnit.day), throwsUnsupportedError);
  });
}
