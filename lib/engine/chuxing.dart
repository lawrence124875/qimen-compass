import 'calendar_service.dart';
import 'ganzhi.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';

/// 出行訣的事類與用神門（V1 規則寫死；V2 起規則表移到 qimen-content）。
enum TravelEvent {
  /// 一般出行：開、休、生三吉門取最佳。
  general([Door.kai, Door.xiu, Door.sheng]),

  /// 求財：生門。
  wealth([Door.sheng]),

  /// 事業、面試、談判：開門。
  career([Door.kai]),

  /// 感情、人際：休門。
  love([Door.xiu]),

  /// 考試、文書：景門。
  exam([Door.jingScene]);

  const TravelEvent(this.doors);
  final List<Door> doors;
}

/// 五級（比照謙卦交叉解讀，不用「凶」字）。
enum TravelLevel { great, good, neutral, minor, blocked }

/// 扣分或加分的原因（UI 用來顯示提示）。
enum TravelFlag { menPo, kongWang, fuYin, fanYin, jiXing, ruMu, goodGod, badGod }

/// 宮位 → 方位角（度，正北＝0，順時針）。
const Map<int, double> palaceBearing = {1: 0, 8: 45, 3: 90, 4: 135, 9: 180, 2: 225, 7: 270, 6: 315};

/// 一個時辰的出行建議。
class TravelSlot {
  const TravelSlot({
    required this.startUtc,
    required this.endUtc,
    required this.hour,
    required this.door,
    required this.palace,
    required this.score,
    required this.flags,
  });

  final DateTime startUtc, endUtc;

  /// 時柱。
  final GanZhi hour;

  /// 本時辰此事類最佳的用神門與所在宮。
  final Door door;
  final int palace;

  final int score;
  final List<TravelFlag> flags;

  double get bearing => palaceBearing[palace]!;

  TravelLevel get level => score >= 5
      ? TravelLevel.great
      : score >= 4
          ? TravelLevel.good
          : score >= 3
              ? TravelLevel.neutral
              : score >= 2
                  ? TravelLevel.minor
                  : TravelLevel.blocked;

  /// 是否值得推薦（吉以上）。
  bool get recommended => score >= 4;

  bool contains(DateTime t) => !t.isBefore(startUtc) && t.isBefore(endUtc);
}

/// 出行訣：列出當下與接下來各時辰的吉方。
class ChuXingPlanner {
  const ChuXingPlanner({this.engine = const ShiJiaEngine()});

  final ShiJiaEngine engine;

  /// 從 [from] 所在時辰起，連續 [count] 個時辰。
  List<TravelSlot> plan(
    DateTime from,
    TravelEvent event, {
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
    int count = 12,
  }) {
    final slots = <TravelSlot>[];
    var start = slotStart(from, settings);
    for (var i = 0; i < count; i++) {
      final end = start.add(const Duration(hours: 2));
      slots.add(evaluate(start, end, event, settings: settings, method: method));
      start = end;
    }
    return slots;
  }

  /// 從 [from] 起 [days] 天，每天在鐘面時間 [fromHour]–[toHour] 之間開始的時辰中取最佳一個（未達「吉」則略過）。
  /// 吉時推播用。
  List<TravelSlot> dailyBest(
    DateTime from,
    TravelEvent event, {
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
    int days = 7,
    int fromHour = 7,
    int toHour = 21,
  }) {
    final all = plan(from, event, settings: settings, method: method, count: days * 12 + 1)
        .where((s) => s.startUtc.isAfter(from));
    final byDay = <int, TravelSlot>{};
    for (final s in all) {
      final clock = engine.calendar.clockTime(s.startUtc, settings);
      if (clock.hour < fromHour || clock.hour >= toHour) continue;
      final key = DateTime.utc(clock.year, clock.month, clock.day).millisecondsSinceEpoch;
      final best = byDay[key];
      if (best == null || s.score > best.score) byDay[key] = s;
    }
    return byDay.values.where((s) => s.recommended).take(days).toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  /// [t] 所在時辰的起點（UTC）。時辰以鐘面時間的奇數點為界（23–1 子、1–3 丑…）。
  DateTime slotStart(DateTime t, TimeSettings settings) {
    final utc = t.toUtc();
    final clock = engine.calendar.clockTime(utc, settings);
    final offset = clock.difference(utc);
    var h = clock.hour;
    var day = DateTime.utc(clock.year, clock.month, clock.day);
    if (h.isEven) {
      h -= 1;
      if (h < 0) {
        h = 23;
        day = day.subtract(const Duration(days: 1));
      }
    }
    return day.add(Duration(hours: h)).subtract(offset);
  }

  /// 評估一個時辰（以時辰中點起局）。
  TravelSlot evaluate(
    DateTime startUtc,
    DateTime endUtc,
    TravelEvent event, {
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
  }) {
    final mid = startUtc.add(endUtc.difference(startUtc) ~/ 2);
    final chart = engine.compute(mid, settings: settings, method: method);
    TravelSlot? best;
    for (final d in event.doors) {
      final p = chart.palaceOfDoor(d);
      final cell = chart[p];
      final flags = <TravelFlag>[];
      var score = 4;
      if (cell.menPo) flags.add(TravelFlag.menPo);
      if (cell.kongWang) flags.add(TravelFlag.kongWang);
      if (chart.doorFuYin || chart.starFuYin) flags.add(TravelFlag.fuYin);
      if (chart.doorFanYin || chart.starFanYin) flags.add(TravelFlag.fanYin);
      if (cell.jiXing.isNotEmpty) flags.add(TravelFlag.jiXing);
      if (cell.ruMu.isNotEmpty) flags.add(TravelFlag.ruMu);
      score -= flags.length;
      if (_goodGods.contains(cell.god)) {
        flags.add(TravelFlag.goodGod);
        score += 1;
      } else if (_badGods.contains(cell.god)) {
        flags.add(TravelFlag.badGod);
        score -= 1;
      }
      final slot = TravelSlot(
        startUtc: startUtc,
        endUtc: endUtc,
        hour: chart.hour,
        door: d,
        palace: p,
        score: score,
        flags: flags,
      );
      if (best == null || slot.score > best.score) best = slot;
    }
    return best!;
  }

  static const _goodGods = {God.zhiFu, God.taiYin, God.liuHe, God.jiuDi, God.jiuTian};
  static const _badGods = {God.baiHu, God.xuanWu, God.tengShe};
}
