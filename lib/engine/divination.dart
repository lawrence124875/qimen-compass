import 'calendar_service.dart';
import 'ganzhi.dart';
import 'geju.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';

/// 事類占卜（HANDOFF §8）：依提問時間起局 → 事類 → 用神 → 規則判斷。
/// 用神對照表（可切換流派）放在私人 repo qimen-content（`app/divination/rules.json`），
/// 這裡只放判斷邏輯；輸出的是「因素」清單，文句由 UI 依語言組合。

/// 用神種類。
enum YongShenKind {
  /// 八門，例如生門。
  door,

  /// 九星，例如天芮。
  star,

  /// 八神，例如六合。
  god,

  /// 指定天干（天盤），例如乙、庚。甲取遁藏的六儀。
  stem,

  /// 日干（求測者本人）。
  dayStem,

  /// 時干（所問之事／失物）。
  hourStem,
}

/// 一個用神設定。
class YongShen {
  const YongShen(this.kind, [this.value]);

  final YongShenKind kind;

  /// 門、星、神、干的中文名（door／star／god／stem 才需要）。
  final String? value;

  factory YongShen.fromJson(Map<String, dynamic> j) {
    final kind = YongShenKind.values.byName(j['type'] as String);
    final value = j['value'] as String?;
    final y = YongShen(kind, value);
    y._check();
    return y;
  }

  void _check() {
    switch (kind) {
      case YongShenKind.door:
        Door.values.firstWhere((d) => d.zh == value);
      case YongShenKind.star:
        Star.values.firstWhere((s) => s.zh == value);
      case YongShenKind.god:
        God.values.firstWhere((g) => g.zh == value);
      case YongShenKind.stem:
        if (!stemNames.contains(value)) throw ArgumentError('未知天干：$value');
      case YongShenKind.dayStem:
      case YongShenKind.hourStem:
        break;
    }
  }

  /// 文句庫用的鍵，例如 `door:生門`、`dayStem`。
  String get key => value == null ? kind.name : '${kind.name}:$value';
}

/// 一個事類的設定。
class TopicRule {
  const TopicRule({
    required this.id,
    required this.yongShen,
    this.relation = false,
    this.direction = false,
    this.disclaimer = false,
  });

  final String id;

  /// 第一個為主用神，其餘為輔。
  final List<YongShen> yongShen;

  /// 是否比較日干（我）與主用神的生剋。
  final bool relation;

  /// 是否輸出方位（失物）。
  final bool direction;

  /// 是否加「僅供參考」聲明（官司、健康）。
  final bool disclaimer;

  factory TopicRule.fromJson(String id, Map<String, dynamic> j) => TopicRule(
        id: id,
        yongShen: [for (final y in j['yongShen'] as List) YongShen.fromJson(y as Map<String, dynamic>)],
        relation: j['relation'] as bool? ?? false,
        direction: j['direction'] as bool? ?? false,
        disclaimer: j['disclaimer'] as bool? ?? false,
      );
}

/// 用神對照表（rules.json）。
class DivinationRules {
  const DivinationRules({required this.topics, required this.schools, required this.defaultSchool});

  /// 事類順序。
  final List<String> topics;

  /// 流派 → 事類 → 設定。流派只需列出與預設不同的事類。
  final Map<String, Map<String, TopicRule>> schools;
  final String defaultSchool;

  static const schemaVersion = 1;

  factory DivinationRules.fromJson(Map<String, dynamic> j) {
    final v = j['schemaVersion'];
    if (v != schemaVersion) throw FormatException('rules.json schemaVersion $v 不支援');
    final schools = <String, Map<String, TopicRule>>{};
    (j['schools'] as Map<String, dynamic>).forEach((name, s) {
      final topics = (s as Map<String, dynamic>)['topics'] as Map<String, dynamic>;
      schools[name] = {for (final e in topics.entries) e.key: TopicRule.fromJson(e.key, e.value as Map<String, dynamic>)};
    });
    final r = DivinationRules(
      topics: [for (final t in j['topics'] as List) t as String],
      schools: schools,
      defaultSchool: j['defaultSchool'] as String,
    );
    for (final t in r.topics) {
      if (!schools[r.defaultSchool]!.containsKey(t)) throw FormatException('預設流派缺少事類 $t');
    }
    return r;
  }

  /// 取某流派的事類設定（該流派沒寫的退回預設流派）。
  TopicRule rule(String topic, [String? school]) =>
      schools[school]?[topic] ?? schools[defaultSchool]![topic]!;

  /// 有改寫 [topic] 的流派（含預設）。
  List<String> schoolsFor(String topic) =>
      [defaultSchool, for (final e in schools.entries) if (e.key != defaultSchool && e.value.containsKey(topic)) e.key];
}

/// 旺相休囚死（用神五行對月令）。
enum Season { wang, xiang, xiu, qiu, si }

/// 判斷因素。[weight] 為加減分（正吉負凶，0 只作說明）。
enum Factor {
  // 主用神的旺衰
  wang, xiang, xiu, qiu, si,
  // 落宮生剋
  palaceSupports, palaceSame, drainsPalace, controlsPalace, palaceControls,
  // 盤面標記
  kongWang, menPo, jiXing, ruMu, horse, fuYin, fanYin,
  // 同宮的門與神
  goodDoor, badDoor, goodGod, badGod,
  // 同宮的九星與格局
  goodStar, sanDun, badStar, siXiong, gengBing,
  // 我（日干）與用神
  sameAsSelf, supportsSelf, selfSupports, selfControls, controlsSelf,
}

const Map<Factor, int> factorWeight = {
  Factor.wang: 2, Factor.xiang: 1, Factor.xiu: 0, Factor.qiu: -1, Factor.si: -2, //
  Factor.palaceSupports: 1, Factor.palaceSame: 1, Factor.drainsPalace: 0, Factor.controlsPalace: -1, Factor.palaceControls: -1,
  Factor.kongWang: -2, Factor.menPo: -1, Factor.jiXing: -1, Factor.ruMu: -1, Factor.horse: 0, Factor.fuYin: -1, Factor.fanYin: -1,
  Factor.goodDoor: 1, Factor.badDoor: -1, Factor.goodGod: 1, Factor.badGod: -1,
  Factor.goodStar: 1, Factor.sanDun: 1, Factor.badStar: -1, Factor.siXiong: -1, Factor.gengBing: -1,
  Factor.sameAsSelf: 1, Factor.supportsSelf: 2, Factor.selfSupports: -1, Factor.selfControls: 1, Factor.controlsSelf: -2,
};

/// 五級（比照謙卦，不用「凶」字）。
enum Verdict { great, good, neutral, minor, blocked }

/// 一個用神在盤上的位置。
class YongShenHit {
  const YongShenHit({required this.spec, required this.palace, required this.element, this.stem});

  final YongShen spec;

  /// 落宮（找不到時為 null，例如天干沒有出現在天盤）。
  final int? palace;

  /// 用神本身的五行（門、星、干；神以落宮五行代）。
  final Element element;

  /// 天干類用神實際找的天干（甲已換成六儀）。
  final int? stem;
}

/// 一次占卜的結果。
class Reading {
  const Reading({
    required this.topic,
    required this.school,
    required this.rule,
    required this.chart,
    required this.hits,
    required this.self,
    required this.factors,
    required this.score,
  });

  final String topic, school;
  final TopicRule rule;
  final QimenChart chart;

  /// 依 [TopicRule.yongShen] 順序。
  final List<YongShenHit> hits;

  /// 日干（我）。
  final YongShenHit self;

  /// 主用神的判斷因素（依計算順序）。
  final List<Factor> factors;
  final int score;

  YongShenHit get main => hits.first;

  Verdict get verdict => score >= 3
      ? Verdict.great
      : score >= 1
          ? Verdict.good
          : score >= -1
              ? Verdict.neutral
              : score >= -3
                  ? Verdict.minor
                  : Verdict.blocked;

  /// 主用神落宮的方位角（失物指向用；落中宮或找不到時為 null）。
  double? get bearing => const {1: 0.0, 8: 45.0, 3: 90.0, 4: 135.0, 9: 180.0, 2: 225.0, 7: 270.0, 6: 315.0}[main.palace];

  /// 用神落宮的門與神（找不到時為 null）。
  PalaceChart? get mainCell => main.palace == null ? null : chart[main.palace!];

  /// 文句挑選用的穩定種子（同一盤、同一事類每次結果相同）。
  int get seed => chart.hour.index * 61 + chart.day.index * 7 + chart.ju + topic.hashCode % 97;
}

/// 天干五行（甲乙木、丙丁火、戊己土、庚辛金、壬癸水）。
Element stemElement(int stem) => Element.values[stem ~/ 2];

extension ElementCycle on Element {
  /// 本五行生 [other]（木生火、火生土…）。
  bool generates(Element other) => other.index == (index + 1) % 5;
}

/// 月令五行（寅卯木、巳午火、申酉金、亥子水、辰戌丑未土）。
Element seasonElement(int monthBranch) => const [
      Element.water, Element.earth, Element.wood, Element.wood, Element.earth, Element.fire, //
      Element.fire, Element.earth, Element.metal, Element.metal, Element.earth, Element.water,
    ][monthBranch];

Season seasonOf(Element e, int monthBranch) {
  final s = seasonElement(monthBranch);
  if (e == s) return Season.wang;
  if (s.generates(e)) return Season.xiang;
  if (e.generates(s)) return Season.xiu;
  if (e.overcomes(s)) return Season.qiu;
  return Season.si;
}

/// 甲遁藏的六儀：甲子戊、甲戌己、甲申庚、甲午辛、甲辰壬、甲寅癸。
int hiddenYi(GanZhi gz) => const {0: 4, 10: 5, 8: 6, 6: 7, 4: 8, 2: 9}[gz.xunBranch]!;

class DivinationEngine {
  const DivinationEngine({this.engine = const ShiJiaEngine()});

  final ShiJiaEngine engine;

  /// 依提問時間 [askedAt] 起局並判斷 [topic]。
  Reading read(
    DivinationRules rules,
    String topic,
    DateTime askedAt, {
    String? school,
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
  }) {
    final chart = engine.compute(askedAt, settings: settings, method: method);
    return judge(rules, topic, chart, school: school);
  }

  /// 對已排好的盤判斷（測試與擇時共用）。
  Reading judge(DivinationRules rules, String topic, QimenChart chart, {String? school}) {
    final sch = rules.schools.containsKey(school) ? school! : rules.defaultSchool;
    final rule = rules.rule(topic, sch);
    final hits = [for (final y in rule.yongShen) locate(chart, y)];
    final self = locate(chart, const YongShen(YongShenKind.dayStem));
    final factors = _factors(chart, rule, hits.first, self);
    final score = factors.fold<int>(0, (s, f) => s + factorWeight[f]!);
    return Reading(
      topic: topic,
      school: sch,
      rule: rule,
      chart: chart,
      hits: hits,
      self: self,
      factors: factors,
      score: score,
    );
  }

  /// 找用神落宮。
  YongShenHit locate(QimenChart chart, YongShen y) {
    switch (y.kind) {
      case YongShenKind.door:
        final d = Door.values.firstWhere((d) => d.zh == y.value);
        return YongShenHit(spec: y, palace: chart.palaceOfDoor(d), element: d.element);
      case YongShenKind.star:
        final s = Star.values.firstWhere((s) => s.zh == y.value);
        final p = chart.palaces.values.where((c) => c.palace != 5 && c.stars.contains(s)).firstOrNull?.palace;
        return YongShenHit(spec: y, palace: p, element: s.element);
      case YongShenKind.god:
        final g = God.values.firstWhere((g) => g.zh == y.value);
        final p = chart.palaces.values.firstWhere((c) => c.god == g).palace;
        return YongShenHit(spec: y, palace: p, element: palaceElement[p]!);
      case YongShenKind.stem:
      case YongShenKind.dayStem:
      case YongShenKind.hourStem:
        var stem = switch (y.kind) {
          YongShenKind.dayStem => chart.day.stem,
          YongShenKind.hourStem => chart.hour.stem,
          _ => stemNames.indexOf(y.value!),
        };
        if (stem == 0) {
          stem = hiddenYi(switch (y.kind) {
            YongShenKind.dayStem => chart.day,
            YongShenKind.stem => chart.hour, // 指定甲時以時旬的六儀代
            _ => chart.hour,
          });
        }
        final p = chart.palaces.values.where((c) => c.palace != 5 && c.heavenStems.contains(stem)).firstOrNull?.palace;
        return YongShenHit(spec: y, palace: p, element: stemElement(stem), stem: stem);
    }
  }

  List<Factor> _factors(QimenChart chart, TopicRule rule, YongShenHit main, YongShenHit self) {
    final f = <Factor>[];
    f.add(Factor.values[Factor.wang.index + seasonOf(main.element, chart.month.branch).index]);
    final p = main.palace;
    if (p == null) return f;
    final cell = chart[p];
    final pe = palaceElement[p]!;
    final e = main.element;
    if (pe == e) {
      f.add(Factor.palaceSame);
    } else if (pe.generates(e)) {
      f.add(Factor.palaceSupports);
    } else if (e.generates(pe)) {
      f.add(Factor.drainsPalace);
    } else if (e.overcomes(pe)) {
      // 門剋宮即門迫，下面另列
      if (main.spec.kind != YongShenKind.door) f.add(Factor.controlsPalace);
    } else {
      f.add(Factor.palaceControls);
    }
    if (cell.kongWang) f.add(Factor.kongWang);
    if (cell.menPo) f.add(Factor.menPo);
    final stem = main.stem;
    if (stem != null ? cell.jiXing.contains(stem) : cell.jiXing.isNotEmpty) f.add(Factor.jiXing);
    if (stem != null ? cell.ruMu.contains(stem) : cell.ruMu.isNotEmpty) f.add(Factor.ruMu);
    if (cell.horse) f.add(Factor.horse);
    if (chart.doorFuYin || chart.starFuYin) f.add(Factor.fuYin);
    if (chart.doorFanYin || chart.starFanYin) f.add(Factor.fanYin);
    if (main.spec.kind != YongShenKind.door && cell.door != null) {
      if (cell.door!.luck == Luck.good) f.add(Factor.goodDoor);
      if (cell.door!.luck == Luck.bad) f.add(Factor.badDoor);
    }
    if (main.spec.kind != YongShenKind.god) {
      if (_goodGods.contains(cell.god)) f.add(Factor.goodGod);
      if (_badGods.contains(cell.god)) f.add(Factor.badGod);
    }
    final star = main.spec.kind == YongShenKind.star ? null : starLuck(cell);
    if (star != null) f.add(Factor.values.byName(star.name));
    for (final g in stemPatterns(cell)) {
      f.add(Factor.values.byName(g.name));
    }
    if (rule.relation && self.palace != null) {
      final sp = palaceElement[self.palace!]!;
      if (self.palace == p) {
        f.add(Factor.sameAsSelf);
      } else if (pe.generates(sp)) {
        f.add(Factor.supportsSelf);
      } else if (sp.generates(pe)) {
        f.add(Factor.selfSupports);
      } else if (sp.overcomes(pe)) {
        f.add(Factor.selfControls);
      } else if (pe.overcomes(sp)) {
        f.add(Factor.controlsSelf);
      }
    }
    return f;
  }

  static const _goodGods = {God.zhiFu, God.taiYin, God.liuHe, God.jiuDi, God.jiuTian};
  static const _badGods = {God.baiHu, God.xuanWu, God.tengShe};
}
