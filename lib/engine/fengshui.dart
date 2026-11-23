import 'divination.dart' show stemElement;
import 'ganzhi.dart';
import 'qimen_types.dart';

/// 今日吉色、十二長生、開運擺件與化解（純規則，不依賴 UI）。

Element _gen(Element e) => Element.values[(e.index + 1) % 5]; // e 所生
Element _genBy(Element e) => Element.values[(e.index + 4) % 5]; // 生 e 者

/// 穿搭顏色的五個等級（常見的每日五行穿衣分法）。
enum ColorRank {
  great, // 大吉：生當日五行
  good, // 次吉：與當日同五行
  wealth, // 招財：當日五行所剋
  drain, // 消耗：當日五行所生
  avoid, // 不宜：剋當日五行
}

/// 某日五行下，五個五行顏色各屬哪一級。
Map<Element, ColorRank> colorRanks(Element day) => {
      _genBy(day): ColorRank.great,
      day: ColorRank.good,
      Element.values[(day.index + 2) % 5]: ColorRank.wealth,
      _gen(day): ColorRank.drain,
      Element.values[(day.index + 3) % 5]: ColorRank.avoid,
    };

/// 今日吉色：以日干五行為準。
class LuckyColors {
  LuckyColors.ofDay(GanZhi day) : dayElement = stemElement(day.stem), ranks = colorRanks(stemElement(day.stem));

  final Element dayElement;
  final Map<Element, ColorRank> ranks;

  Element of(ColorRank r) => ranks.entries.firstWhere((e) => e.value == r).key;

  /// 個人吉色（結合年命）：同時看當日與年干五行，各打分取最高；最低者為個人忌色。
  (Element best, Element worst) personal(int birthYearStem) {
    final me = stemElement(birthYearStem);
    int score(Element e) {
      final d = switch (ranks[e]!) {
        ColorRank.great => 3,
        ColorRank.good => 2,
        ColorRank.wealth => 1,
        ColorRank.drain => 0,
        ColorRank.avoid => -3,
      };
      final p = e == _genBy(me)
          ? 3
          : e == me
              ? 2
              : me.overcomes(e)
                  ? 1
                  : e.overcomes(me)
                      ? -3
                      : 0;
      return d + p;
    }

    final sorted = [...Element.values]..sort((a, b) {
        final c = score(b).compareTo(score(a));
        return c != 0 ? c : a.index.compareTo(b.index);
      });
    return (sorted.first, sorted.last);
  }
}

/// 十二長生。
enum ChangSheng {
  changSheng('長生'),
  muYu('沐浴'),
  guanDai('冠帶'),
  linGuan('臨官'),
  diWang('帝旺'),
  shuai('衰'),
  bing('病'),
  si('死'),
  mu('墓'),
  jue('絕'),
  tai('胎'),
  yang('養');

  const ChangSheng(this.zh);
  final String zh;

  /// 旺（長生至帝旺）、衰（衰至絕）、蓄（胎養）。
  bool get strong => index <= ChangSheng.diWang.index;
}

/// 十干長生所在地支：甲亥、乙午、丙戊寅、丁己酉、庚巳、辛子、壬申、癸卯；陽干順行、陰干逆行。
const List<int> _changShengBranch = [11, 6, 2, 9, 2, 9, 5, 0, 8, 3];

ChangSheng changShengOf(int stem, int branch) {
  final start = _changShengBranch[stem];
  final i = stem.isEven ? (branch - start) % 12 : (start - branch) % 12;
  return ChangSheng.values[(i + 12) % 12];
}

/// 九宮所含地支（後天八卦）：坎子、艮丑寅、震卯、巽辰巳、離午、坤未申、兌酉、乾戌亥。
const Map<int, List<int>> palaceBranches = {
  1: [0],
  8: [1, 2],
  3: [3],
  4: [4, 5],
  9: [6],
  2: [7, 8],
  7: [9],
  6: [10, 11],
  5: [],
};

/// 化解用的五行：門與宮相剋時取通關五行，凶門取洩其氣的五行，平門取生扶門的五行。
/// 吉門且不相剋時回傳 null（不需化解）。
Element? cureElement(Door door, int palace) {
  final d = door.element;
  final p = palaceElement[palace]!;
  if (d.overcomes(p)) return _gen(d); // 門迫：門生它、它生宮
  if (p.overcomes(d)) return _gen(p); // 宮剋門：宮生它、它生門
  if (door.luck == Luck.bad) return _gen(d);
  if (door.luck == Luck.neutral) return _genBy(d);
  return null;
}

/// 需留意的星（用於化解提示）。
const Set<Star> cureStars = {Star.peng, Star.rui};

/// 門與宮的五行關係（宮位詳情「五行與化解」）。
enum DoorPalaceRelation {
  palaceGen('宮生門'),
  doorGen('門生宮'),
  same('比和'),
  menPo('門剋宮'),
  palaceKe('宮剋門');

  const DoorPalaceRelation(this.zh);
  final String zh;

  static DoorPalaceRelation of(Door door, int palace) {
    final d = door.element;
    final p = palaceElement[palace]!;
    if (d == p) return same;
    if (_gen(p) == d) return palaceGen;
    if (_gen(d) == p) return doorGen;
    if (d.overcomes(p)) return menPo;
    return palaceKe;
  }
}

/// 吉門催旺用的五行：生扶門的五行（[cureElement] 為 null 的吉門用）。
Element boostElement(Door door) => _genBy(door.element);
