import 'calendar_service.dart';
import 'chuxing.dart';
import 'direction.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';
import 'zeshi.dart';

/// 個人化（HANDOFF §12 P4）：本命盤、流年流月、個人吉方。全部以「年命宮」（年干在天盤所落宮，甲取遁藏六儀）
/// 與「日干宮」為核心，吉凶沿用 [DirectionPlanner.judge] 的五級計分。

/// 天干 [stem] 在天盤落哪一宮（中五寄坤，只找外八宮）；找不到回傳 null。
int? stemPalace(QimenChart chart, int stem) =>
    chart.palaces.values.where((c) => c.palace != 5 && c.heavenStems.contains(stem)).firstOrNull?.palace;

class NatalReading {
  const NatalReading({required this.chart, required this.birth, required this.ming, required this.self});

  final QimenChart chart;
  final BirthInfo birth;

  /// 年命宮、日干宮的吉凶（宮位見 `.palace`）。
  final DirectionVerdict? ming, self;
}

class FortuneReading {
  const FortuneReading({required this.at, required this.unit, required this.chart, required this.verdict});

  final DateTime at;
  final PanUnit unit;
  final QimenChart chart;
  final DirectionVerdict? verdict;
}

class PersonalEngine {
  const PersonalEngine({this.engine = const ShiJiaEngine()});

  final ShiJiaEngine engine;

  /// 本命盤：出生時刻起時盤（不知道時辰時由呼叫端給當天 12:00）。
  NatalReading natal(DateTime birth, {TimeSettings settings = const TimeSettings(), JuMethod method = JuMethod.chaiBu}) {
    final chart = engine.compute(birth, settings: settings, method: method);
    final info = BirthInfo.fromInstant(birth, settings: settings);
    DirectionVerdict? at(int stem) {
      final p = stemPalace(chart, stem);
      return p == null ? null : DirectionPlanner.judge(chart, p);
    }

    return NatalReading(chart: chart, birth: info, ming: at(info.yearStem), self: at(info.dayStem));
  }

  /// 流年（[unit]=year）或流月（month）：該年盤／月盤上年命宮的吉凶。
  FortuneReading fortune(BirthInfo birth, DateTime at, PanUnit unit,
      {TimeSettings settings = const TimeSettings(), JuMethod method = JuMethod.chaiBu}) {
    final chart = engine.compute(at, settings: settings, method: method, unit: unit);
    final p = stemPalace(chart, birth.yearStem);
    return FortuneReading(at: at, unit: unit, chart: chart, verdict: p == null ? null : DirectionPlanner.judge(chart, p));
  }

  /// 個人吉方：從 [from] 起 [days] 天、鐘面 [fromHour]–[toHour] 開始的時辰中，年命宮達「吉」以上者，
  /// 依分數取前 [limit] 個（同分取早），依時間排序。方位＝年命宮。
  List<DirectionVerdict> luckyHours(
    BirthInfo birth,
    DateTime from, {
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
    int days = 7,
    int fromHour = 7,
    int toHour = 21,
    int limit = 5,
  }) {
    final planner = ChuXingPlanner(engine: engine);
    var start = planner.slotStart(from, settings);
    final hits = <DirectionVerdict>[];
    for (var i = 0; i < days * 12; i++) {
      final end = start.add(const Duration(hours: 2));
      final clock = engine.calendar.clockTime(start, settings);
      if (clock.hour >= fromHour && clock.hour < toHour && end.isAfter(from)) {
        final chart = engine.compute(start.add(const Duration(hours: 1)), settings: settings, method: method);
        final p = stemPalace(chart, birth.yearStem);
        if (p != null) {
          final v = DirectionPlanner.judge(chart, p, startUtc: start, endUtc: end);
          if (v.recommended) hits.add(v);
        }
      }
      start = end;
    }
    hits.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.startUtc!.compareTo(b.startUtc!);
    });
    return hits.take(limit).toList()..sort((a, b) => a.startUtc!.compareTo(b.startUtc!));
  }
}
