import 'calendar_service.dart';
import 'chuxing.dart';
import 'direction.dart';
import 'ganzhi.dart';
import 'personal.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';
import 'zeshi.dart';

/// 本命報告（終身局）：時家轉盤拆補法起本命盤，大運借子平八字（陽男陰女順、陰男陽女逆，
/// 從月柱起每十年一柱，起運歲依出生到下一／上一「節」的時間，三天折一年），
/// 大運天干落本命盤哪一宮，以該宮星門神吉凶＋與日干宮的五行生剋論十年運勢。

/// 某宮與「你」（日干宮）的五行關係。
enum Relation {
  shengWo, // 該宮生日干宮：得助
  woSheng, // 日干宮生該宮：付出
  keWo, // 該宮剋日干宮：壓力
  woKe, // 日干宮剋該宮：掌控
  biHe, // 比和
}

Relation relationTo(int palace, int selfPalace) {
  final a = palaceElement[palace]!, b = palaceElement[selfPalace]!;
  if (a == b) return Relation.biHe;
  if ((a.index + 1) % 5 == b.index) return Relation.shengWo;
  if ((b.index + 1) % 5 == a.index) return Relation.woSheng;
  if (a.overcomes(b)) return Relation.keWo;
  return Relation.woKe;
}

/// 報告的一個主題（事業、財運、感情、六親）落在哪一宮。
class TopicReading {
  const TopicReading({required this.verdict, required this.relation});

  final DirectionVerdict verdict;

  /// 與日干宮的關係；就落在日干宮時為 null。
  final Relation? relation;

  int get palace => verdict.palace;
}

enum NatalTopic { career, wealth, love, parents, siblings, children }

class DaYunStep {
  const DaYunStep({required this.pillar, required this.startAge, required this.startYear, this.reading});

  final GanZhi pillar;

  /// 起運歲數（實歲，可含小數）。
  final double startAge;

  /// 交運的西元年。
  final int startYear;

  /// 大運天干落本命盤的宮（找不到時 null）。
  final TopicReading? reading;
}

class KeyYear {
  const KeyYear({required this.year, required this.verdict, this.daYunChange = false});

  final int year;
  final DirectionVerdict? verdict;

  /// 該年交大運。
  final bool daYunChange;
}

class NatalReport {
  const NatalReport({
    required this.natal,
    required this.topics,
    required this.forward,
    required this.daYun,
    required this.keyYears,
  });

  final NatalReading natal;
  final Map<NatalTopic, TopicReading> topics;

  /// 大運順排；未設定性別時 null（[daYun] 為空）。
  final bool? forward;
  final List<DaYunStep> daYun;
  final List<KeyYear> keyYears;

  int? get selfPalace => natal.self?.palace;
}

/// 盤上取天干：甲取所在旬遁藏的六儀。
int hiddenStemOf(GanZhi gz) => gz.stem == 0 ? xunHiddenStem[gz.xunBranch]! : gz.stem;

class NatalReportEngine {
  const NatalReportEngine({this.engine = const ShiJiaEngine()});

  final ShiJiaEngine engine;

  /// [male]：null＝未設定性別（不排大運）；[knowTime]：false 時不論子女（時干不準）。
  NatalReport build(
    DateTime birth, {
    bool? male,
    bool knowTime = true,
    required DateTime now,
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
    int steps = 8,
    int keyYearSpan = 10,
  }) {
    final personal = PersonalEngine(engine: engine);
    final natal = personal.natal(birth, settings: settings, method: method);
    final chart = natal.chart;
    final self = natal.self?.palace;

    TopicReading? at(int? palace) {
      if (palace == null) return null;
      return TopicReading(
        verdict: DirectionPlanner.judge(chart, palace),
        relation: self == null || palace == self ? null : relationTo(palace, self),
      );
    }

    final topics = <NatalTopic, TopicReading>{};
    void put(NatalTopic t, int? palace) {
      final r = at(palace);
      if (r != null) topics[t] = r;
    }

    put(NatalTopic.career, chart.palaceOfDoor(Door.kai));
    put(NatalTopic.wealth, chart.palaceOfDoor(Door.sheng));
    // 感情：男看乙（妻）、女看庚（夫）；未設定性別看六合。
    put(
        NatalTopic.love,
        male == null
            ? chart.palaces.values.where((c) => c.god == God.liuHe).firstOrNull?.palace
            : stemPalace(chart, male ? 1 : 6));
    put(NatalTopic.parents, stemPalace(chart, hiddenStemOf(chart.year)));
    put(NatalTopic.siblings, stemPalace(chart, hiddenStemOf(chart.month)));
    if (knowTime) put(NatalTopic.children, stemPalace(chart, hiddenStemOf(chart.hour)));

    bool? forward;
    final daYun = <DaYunStep>[];
    if (male != null) {
      final yang = chart.year.stem.isEven;
      forward = yang == male;
      final age = startAge(birth, forward: forward);
      final birthYear = engine.calendar.clockTime(birth, settings).year;
      for (var i = 0; i < steps; i++) {
        final gz = GanZhi((chart.month.index + (forward ? i + 1 : -(i + 1)) + 600) % 60);
        final a = age + 10 * i;
        daYun.add(DaYunStep(
          pillar: gz,
          startAge: a,
          startYear: birthYear + a.round(),
          reading: at(stemPalace(chart, hiddenStemOf(gz))),
        ));
      }
    }

    final keyYears = <KeyYear>[];
    for (var y = now.year; y < now.year + keyYearSpan; y++) {
      final f = personal.fortune(natal.birth, DateTime(y, 7, 1), PanUnit.year, settings: settings, method: method);
      final change = daYun.any((d) => d.startYear == y);
      final lv = f.verdict?.level;
      if (change || lv == TravelLevel.great || lv == TravelLevel.blocked) {
        keyYears.add(KeyYear(year: y, verdict: f.verdict, daYunChange: change));
      }
    }

    return NatalReport(natal: natal, topics: topics, forward: forward, daYun: daYun, keyYears: keyYears);
  }

  /// 起運歲數：順排算到下一個「節」，逆排算到上一個「節」；三天折一年。
  double startAge(DateTime birth, {required bool forward}) {
    final utc = birth.toUtc();
    final terms = engine.calendar
        .termsBetween(utc.subtract(const Duration(days: 40)), utc.add(const Duration(days: 40)))
        .where((t) => t.index.isOdd); // 節：小寒、立春、驚蟄…大雪（自冬至起的奇數序）
    final jie = forward
        ? terms.firstWhere((t) => t.startUtc.isAfter(utc))
        : terms.lastWhere((t) => !t.startUtc.isAfter(utc));
    final minutes = jie.startUtc.difference(utc).inMinutes.abs();
    return minutes / (3 * 24 * 60);
  }
}
