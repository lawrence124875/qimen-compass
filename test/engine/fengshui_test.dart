import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  test('每日五行穿衣：木日 大吉水、次吉木、招財土、消耗火、不宜金', () {
    final c = LuckyColors.ofDay(GanZhi.parse('甲子'));
    expect(c.dayElement, Element.wood);
    expect(c.of(ColorRank.great), Element.water);
    expect(c.of(ColorRank.good), Element.wood);
    expect(c.of(ColorRank.wealth), Element.earth);
    expect(c.of(ColorRank.drain), Element.fire);
    expect(c.of(ColorRank.avoid), Element.metal);
  });

  test('個人吉色：木日、金年命 → 土（生金）為佳、火（剋金）為忌', () {
    final (best, worst) = LuckyColors.ofDay(GanZhi.parse('甲子')).personal(6);
    expect(best, Element.earth);
    expect(worst, Element.fire);
  });

  test('十二長生：甲長生亥、帝旺卯；乙長生午、帝旺寅；庚墓丑', () {
    expect(changShengOf(0, 11), ChangSheng.changSheng);
    expect(changShengOf(0, 3), ChangSheng.diWang);
    expect(changShengOf(1, 6), ChangSheng.changSheng);
    expect(changShengOf(1, 2), ChangSheng.diWang);
    expect(changShengOf(6, 1), ChangSheng.mu);
    expect(changShengOf(9, 3), ChangSheng.changSheng);
    expect(changShengOf(4, 10), ChangSheng.mu); // 戊墓戌
  });

  test('化解五行：門迫取通關、凶門洩氣、吉門不必', () {
    expect(cureElement(Door.jing, 3), Element.water); // 驚金迫震木 → 水通關
    expect(cureElement(Door.shang, 2), Element.fire); // 傷木迫坤土 → 火
    expect(cureElement(Door.si, 9), Element.metal); // 死土在離火（宮生門）凶門 → 金洩土
    expect(cureElement(Door.kai, 6), isNull);
    expect(cureElement(Door.du, 4), Element.water); // 平門取生扶
  });

  test('發訊息時機：接下來 4 個時辰連續、第一個含現在', () {
    final now = DateTime.utc(2026, 11, 19, 7, 30);
    final r = const ZeShiPlanner().upcoming(now, ZeShiEvent.message);
    expect(r.length, 4);
    expect(r.first.startUtc.isAfter(now), isFalse);
    expect(r.first.endUtc.isAfter(now), isTrue);
    for (var i = 1; i < 4; i++) {
      expect(r[i].startUtc, r[i - 1].endUtc);
    }
  });
}
