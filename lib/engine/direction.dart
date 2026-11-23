import 'calendar_service.dart';
import 'chuxing.dart';
import 'geju.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';

/// 方位吉凶（地圖八門、目的地吉凶、搬家方位共用，HANDOFF §12 P2／P5）。
/// 與出行訣同一套計分，但評的是「指定方位那一宮」而不是用神門：
/// 基礎 3 分，門吉（開休生）+1、門凶（死驚傷）−1，其餘加減同出行訣（門迫、空亡、伏反吟、擊刑、入墓、吉凶神、格局）。
/// 五級沿用 [TravelLevel]：≥5 大吉、4 吉、3 平、2 小阻、其餘阻。
class DirectionVerdict {
  const DirectionVerdict({required this.palace, required this.door, required this.score, required this.flags, this.startUtc, this.endUtc});

  final int palace;
  final Door? door;
  final int score;
  final List<TravelFlag> flags;

  /// 時盤才有：該時辰起訖（UTC）。
  final DateTime? startUtc, endUtc;

  TravelLevel get level => score >= 5
      ? TravelLevel.great
      : score >= 4
          ? TravelLevel.good
          : score >= 3
              ? TravelLevel.neutral
              : score >= 2
                  ? TravelLevel.minor
                  : TravelLevel.blocked;

  bool get recommended => score >= 4;
}

class DirectionPlanner {
  const DirectionPlanner({this.engine = const ShiJiaEngine()});

  final ShiJiaEngine engine;

  /// 任一張盤（時、月、年盤）上某宮的方位吉凶。
  static DirectionVerdict judge(QimenChart chart, int palace, {DateTime? startUtc, DateTime? endUtc}) {
    final cell = chart[palace];
    final flags = <TravelFlag>[];
    var score = 3;
    final door = cell.door;
    if (door != null) score += door.luck == Luck.good ? 1 : (door.luck == Luck.bad ? -1 : 0);
    if (cell.menPo) flags.add(TravelFlag.menPo);
    if (cell.kongWang) flags.add(TravelFlag.kongWang);
    if (chart.doorFuYin || chart.starFuYin) flags.add(TravelFlag.fuYin);
    if (chart.doorFanYin || chart.starFanYin) flags.add(TravelFlag.fanYin);
    if (cell.jiXing.isNotEmpty) flags.add(TravelFlag.jiXing);
    if (cell.ruMu.isNotEmpty) flags.add(TravelFlag.ruMu);
    score -= flags.length;
    if (const {God.zhiFu, God.taiYin, God.liuHe, God.jiuDi, God.jiuTian}.contains(cell.god)) {
      flags.add(TravelFlag.goodGod);
      score += 1;
    } else if (const {God.baiHu, God.xuanWu, God.tengShe}.contains(cell.god)) {
      flags.add(TravelFlag.badGod);
      score -= 1;
    }
    for (final g in geJuOf(cell)) {
      flags.add(TravelFlag.values.byName(g.name));
      score += g.good ? 1 : -1;
    }
    return DirectionVerdict(palace: palace, door: door, score: score, flags: flags, startUtc: startUtc, endUtc: endUtc);
  }

  /// 從 [from] 所在時辰起連續 [count] 個時辰，往 [palace] 方位的吉凶（以時辰中點起局）。
  List<DirectionVerdict> plan(
    DateTime from,
    int palace, {
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
    int count = 12,
  }) {
    final out = <DirectionVerdict>[];
    var start = ChuXingPlanner(engine: engine).slotStart(from, settings);
    for (var i = 0; i < count; i++) {
      final end = start.add(const Duration(hours: 2));
      final mid = start.add(const Duration(hours: 1));
      out.add(judge(engine.compute(mid, settings: settings, method: method), palace, startUtc: start, endUtc: end));
      start = end;
    }
    return out;
  }
}

/// 大門吉時（宅盤）：從 [fromUtc] 起 [slots] 個時辰內，[palace] 方位逢開、休、生門且方位吉以上的時辰。
/// 每個時辰以中點起局，結果帶起訖時間。
List<DirectionVerdict> doorLuckyHours(
  int palace,
  DateTime fromUtc, {
  int slots = 24,
  TimeSettings settings = const TimeSettings(),
  JuMethod method = JuMethod.chaiBu,
  ChuXingPlanner planner = const ChuXingPlanner(),
}) {
  final out = <DirectionVerdict>[];
  var start = planner.slotStart(fromUtc, settings);
  for (var i = 0; i < slots; i++) {
    final end = start.add(const Duration(hours: 2));
    final mid = start.add(const Duration(hours: 1));
    final c = planner.engine.compute(mid, settings: settings, method: method);
    final v = DirectionPlanner.judge(c, palace, startUtc: start, endUtc: end);
    if (v.door?.luck == Luck.good && v.recommended) out.add(v);
    start = end;
  }
  return out;
}
