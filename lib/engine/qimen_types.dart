import 'ganzhi.dart';

/// 盤的時間單位。已實作 [hour]（時家）、[month]（月家）、[year]（年家）；[day] 排在 V3。
enum PanUnit { hour, day, month, year }

/// 定元方法。
enum JuMethod {
  /// 拆補法（預設）：以符頭地支定上中下元，節氣以真實交節為準。
  chaiBu,

  /// 置閏法：符頭與節氣對齊，超神逾九日於芒種、大雪置閏。
  zhiRun,
}

enum Dun {
  yang('陽遁'),
  yin('陰遁');

  const Dun(this.zh);
  final String zh;
}

enum Yuan {
  upper('上元'),
  middle('中元'),
  lower('下元');

  const Yuan(this.zh);
  final String zh;
}

/// 九星（依原始宮位：蓬1 芮2 沖3 輔4 禽5 心6 柱7 任8 英9）。
enum Star {
  peng('天蓬', 1, Element.water),
  rui('天芮', 2, Element.earth),
  chong('天沖', 3, Element.wood),
  fu('天輔', 4, Element.wood),
  qin('天禽', 5, Element.earth),
  xin('天心', 6, Element.metal),
  zhu('天柱', 7, Element.metal),
  ren('天任', 8, Element.earth),
  ying('天英', 9, Element.fire);

  const Star(this.zh, this.home, this.element);
  final String zh;
  final int home;
  final Element element;

  static Star atHome(int palace) => values.firstWhere((s) => s.home == palace);
}

/// 吉凶分類（§4：吉 開休生；平 杜景；凶 死驚傷）。
enum Luck { good, neutral, bad }

/// 八門（依原始宮位：休1 死2 傷3 杜4 開6 驚7 生8 景9）。
enum Door {
  xiu('休門', 1, Element.water, Luck.good),
  si('死門', 2, Element.earth, Luck.bad),
  shang('傷門', 3, Element.wood, Luck.bad),
  du('杜門', 4, Element.wood, Luck.neutral),
  kai('開門', 6, Element.metal, Luck.good),
  jing('驚門', 7, Element.metal, Luck.bad),
  sheng('生門', 8, Element.earth, Luck.good),
  jingScene('景門', 9, Element.fire, Luck.neutral);

  const Door(this.zh, this.home, this.element, this.luck);
  final String zh;
  final int home;
  final Element element;
  final Luck luck;

  static Door atHome(int palace) => values.firstWhere((d) => d.home == palace);
}

/// 八神（轉盤，從值符起依序排）。
enum God {
  zhiFu('值符'),
  tengShe('螣蛇'),
  taiYin('太陰'),
  liuHe('六合'),
  baiHu('白虎'),
  xuanWu('玄武'),
  jiuDi('九地'),
  jiuTian('九天');

  const God(this.zh);
  final String zh;
}

/// 宮位五行（洛書數 1–9）。
const Map<int, Element> palaceElement = {
  1: Element.water,
  2: Element.earth,
  3: Element.wood,
  4: Element.wood,
  5: Element.earth,
  6: Element.metal,
  7: Element.metal,
  8: Element.earth,
  9: Element.fire,
};

/// 宮名（後天八卦）。
const Map<int, String> palaceNames = {
  1: '坎', 2: '坤', 3: '震', 4: '巽', 5: '中', 6: '乾', 7: '兌', 8: '艮', 9: '離', //
};

/// 外八宮順時針環（坎→艮→震→巽→離→坤→兌→乾）。
const List<int> palaceRing = [1, 8, 3, 4, 9, 2, 7, 6];

/// 對宮（反吟用）。
int oppositePalace(int p) => p == 5 ? 5 : 10 - p;

/// 一宮的排盤結果。
class PalaceChart {
  PalaceChart(this.palace);

  final int palace;

  /// 地盤天干（坤二宮另含寄宮的中五宮天干）。
  final List<int> earthStems = [];

  /// 天盤天干（天芮所落宮另含天禽帶來的天干）。
  final List<int> heavenStems = [];

  /// 九星（天芮所落宮另含天禽）。
  final List<Star> stars = [];

  Door? door;
  God? god;

  bool kongWang = false;
  bool horse = false;

  /// 門迫：門的五行剋宮的五行。
  bool menPo = false;

  /// 擊刑的天盤天干。
  final List<int> jiXing = [];

  /// 入墓的天盤天干。
  final List<int> ruMu = [];

  String get name => palaceNames[palace]!;
}

/// 一張完整的盤。
class QimenChart {
  QimenChart({
    required this.unit,
    required this.method,
    required this.dun,
    required this.ju,
    required this.yuan,
    required this.termIndex,
    this.fuTou,
    this.chaoShen,
    this.leap = false,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    GanZhi? pivot,
    required this.xunShou,
    required this.zhiFu,
    required this.zhiShi,
    required this.palaces,
    required this.starFuYin,
    required this.starFanYin,
    required this.doorFuYin,
    required this.doorFanYin,
  }) : pivot = pivot ?? hour;

  final PanUnit unit;
  final JuMethod method;
  final Dun dun;
  final int ju;
  final Yuan yuan;

  /// 定局所用的節氣（置閏法可能與實際節氣不同）。
  final int termIndex;

  /// 起局依據：符頭、置閏法的超神（正）／接氣（負）日數、是否閏局。
  final GanZhi? fuTou;
  final int? chaoShen;
  final bool leap;

  final GanZhi year, month, day, hour;

  /// 起局所依的柱：時盤＝時柱、月盤＝月柱、年盤＝年柱。
  final GanZhi pivot;

  /// 起局柱（[pivot]）的旬首（例如甲子）。
  final GanZhi xunShou;

  final Star zhiFu;
  final Door zhiShi;

  /// 1–9 宮（5 宮只有地盤）。
  final Map<int, PalaceChart> palaces;

  final bool starFuYin, starFanYin, doorFuYin, doorFanYin;

  PalaceChart operator [](int palace) => palaces[palace]!;

  /// 某門目前所在宮。
  int palaceOfDoor(Door d) => palaces.values.firstWhere((p) => p.door == d).palace;
}
