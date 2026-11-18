import 'calendar_service.dart';
import 'chuxing.dart';
import 'geju.dart';
import 'ganzhi.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';

/// 擇時擇日的情境與用神（HANDOFF §7；V2 起規則表移到 qimen-content）。
enum ZeShiEvent {
  /// 簽約：開門，六合加分（契約、合作）。
  contract([Door.kai], God.liuHe),

  /// 開幕、開業：生門、開門取佳，值符加分。
  opening([Door.sheng, Door.kai], God.zhiFu),

  /// 面試：開門，九天加分（求名、表現）。
  interview([Door.kai], God.jiuTian),

  /// 相親：休門，六合加分。
  dating([Door.xiu], God.liuHe),

  /// 訂婚：休門、生門取佳，六合加分。
  engagement([Door.xiu, Door.sheng], God.liuHe),

  /// 遠行：開、休、生三吉門取佳，九天加分。
  journey([Door.kai, Door.xiu, Door.sheng], God.jiuTian);

  const ZeShiEvent(this.doors, this.favoredGod);
  final List<Door> doors;

  /// 此情境特別加分的八神。
  final God favoredGod;
}

/// 計分項目（UI 用來列出理由）。
enum ZeShiFlag {
  // 加分
  wangXiang, // 用神門落宮旺相（宮生門或比和）
  goodGod, // 吉神同宮
  favoredGod, // 情境特別加分的神
  sanQi, // 三奇（乙丙丁）臨用神宮
  qingLong, // 青龍返首（天盤戊加地盤丙）
  feiNiao, // 飛鳥跌穴（天盤丙加地盤戊）
  goodStar, // 天輔、天禽、天心同宮
  sanDun, // 天遁、地遁、人遁
  mingJi, // 年命宮逢吉門
  // 扣分
  qiuSi, // 用神門受宮剋（囚死）
  menPo,
  kongWang,
  fuYin,
  fanYin,
  jiXing,
  ruMu,
  badGod,
  mingXiong, // 年命宮逢空亡或入墓
  badStar, // 天蓬、天芮同宮
  siXiong, // 四凶格（青龍逃走、白虎猖狂、朱雀投江、螣蛇夭矯）
  gengBing, // 太白入熒、熒入太白
}

/// 使用者生辰（選填）：年命（出生年干支）與日干。
class BirthInfo {
  const BirthInfo({required this.year, required this.day});

  /// 由出生時刻推出年柱（依立春）與日柱。
  factory BirthInfo.fromInstant(DateTime birth, {TimeSettings settings = const TimeSettings()}) {
    final m = const CalendarService().momentAt(birth, settings);
    return BirthInfo(year: m.year, day: m.day);
  }

  final GanZhi year;
  final GanZhi day;

  /// 年命在盤上取的天干：年干，甲年取所在旬遁藏的六儀。
  int get yearStem => year.stem == 0 ? xunHiddenStem[year.xunBranch]! : year.stem;

  /// 日干，甲日同理。
  int get dayStem => day.stem == 0 ? xunHiddenStem[day.xunBranch]! : day.stem;
}

/// 一個候選時段的分數。
class ZeShiSlot {
  const ZeShiSlot({
    required this.startUtc,
    required this.endUtc,
    required this.chart,
    required this.door,
    required this.palace,
    required this.score,
    required this.flags,
  });

  final DateTime startUtc, endUtc;
  final QimenChart chart;
  final Door door;
  final int palace;
  final int score;
  final List<ZeShiFlag> flags;

  double get bearing => palaceBearing[palace]!;

  /// 五級（比照出行訣門檻，分數範圍較寬）。
  TravelLevel get level => score >= 7
      ? TravelLevel.great
      : score >= 5
          ? TravelLevel.good
          : score >= 3
              ? TravelLevel.neutral
              : score >= 1
                  ? TravelLevel.minor
                  : TravelLevel.blocked;
}

/// 擇時擇日：掃描未來 N 天的時盤，依情境打分，列出前幾名。
class ZeShiPlanner {
  const ZeShiPlanner({this.chuXing = const ChuXingPlanner()});

  final ChuXingPlanner chuXing;
  ShiJiaEngine get engine => chuXing.engine;

  /// 從 [from] 起 [days] 天，只看鐘面時間 [fromHour]–[toHour] 開始的時辰；
  /// 依分數排序取前 [top] 名，同一天最多 [perDay] 個。
  List<ZeShiSlot> best(
    DateTime from,
    ZeShiEvent event, {
    int days = 7,
    int top = 5,
    int perDay = 2,
    int fromHour = 7,
    int toHour = 21,
    BirthInfo? birth,
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
  }) {
    final all = scan(from, event,
        days: days, fromHour: fromHour, toHour: toHour, birth: birth, settings: settings, method: method);
    all.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.startUtc.compareTo(b.startUtc);
    });
    final perDayCount = <int, int>{};
    final out = <ZeShiSlot>[];
    for (final s in all) {
      final key = _dayKey(s.startUtc, settings);
      if ((perDayCount[key] ?? 0) >= perDay) continue;
      perDayCount[key] = (perDayCount[key] ?? 0) + 1;
      out.add(s);
      if (out.length >= top) break;
    }
    return out;
  }

  /// 所有候選時段（依時間排序）。
  List<ZeShiSlot> scan(
    DateTime from,
    ZeShiEvent event, {
    int days = 7,
    int fromHour = 7,
    int toHour = 21,
    BirthInfo? birth,
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
  }) {
    final out = <ZeShiSlot>[];
    var start = chuXing.slotStart(from, settings);
    final end = from.toUtc().add(Duration(days: days));
    while (start.isBefore(end)) {
      final next = start.add(const Duration(hours: 2));
      final clock = engine.calendar.clockTime(start, settings);
      if (start.isAfter(from) && clock.hour >= fromHour && clock.hour < toHour) {
        out.add(evaluate(start, next, event, birth: birth, settings: settings, method: method));
      }
      start = next;
    }
    return out;
  }

  /// 評估一個時辰（以中點起局），各用神門取最高分。
  ZeShiSlot evaluate(
    DateTime startUtc,
    DateTime endUtc,
    ZeShiEvent event, {
    BirthInfo? birth,
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
  }) {
    final mid = startUtc.add(endUtc.difference(startUtc) ~/ 2);
    final chart = engine.compute(mid, settings: settings, method: method);
    ZeShiSlot? best;
    for (final d in event.doors) {
      final p = chart.palaceOfDoor(d);
      final r = scorePalace(chart, d, p, event, birth: birth);
      final slot = ZeShiSlot(
        startUtc: startUtc,
        endUtc: endUtc,
        chart: chart,
        door: d,
        palace: p,
        score: r.$1,
        flags: r.$2,
      );
      if (best == null || slot.score > best.score) best = slot;
    }
    return best!;
  }

  /// 計分：基礎 4 分，加分、扣分各 1。
  static (int, List<ZeShiFlag>) scorePalace(QimenChart chart, Door door, int palace, ZeShiEvent event,
      {BirthInfo? birth}) {
    final cell = chart[palace];
    final plus = <ZeShiFlag>[];
    final minus = <ZeShiFlag>[];
    final pe = palaceElement[palace]!;

    // 旺相：宮生門或比和；囚死：宮剋門。（門剋宮＝門迫另計）
    if (pe == door.element || _generates(pe, door.element)) {
      plus.add(ZeShiFlag.wangXiang);
    } else if (pe.overcomes(door.element)) {
      minus.add(ZeShiFlag.qiuSi);
    }
    if (cell.menPo) minus.add(ZeShiFlag.menPo);
    if (cell.kongWang) minus.add(ZeShiFlag.kongWang);
    if (chart.doorFuYin || chart.starFuYin) minus.add(ZeShiFlag.fuYin);
    if (chart.doorFanYin || chart.starFanYin) minus.add(ZeShiFlag.fanYin);
    if (cell.jiXing.isNotEmpty) minus.add(ZeShiFlag.jiXing);
    if (cell.ruMu.isNotEmpty) minus.add(ZeShiFlag.ruMu);

    if (cell.god == event.favoredGod) {
      plus.add(ZeShiFlag.favoredGod);
    } else if (_goodGods.contains(cell.god)) {
      plus.add(ZeShiFlag.goodGod);
    } else if (_badGods.contains(cell.god)) {
      minus.add(ZeShiFlag.badGod);
    }

    // 吉格。
    if (cell.heavenStems.any((s) => s >= 1 && s <= 3)) plus.add(ZeShiFlag.sanQi);
    if (cell.heavenStems.contains(4) && cell.earthStems.contains(2)) plus.add(ZeShiFlag.qingLong);
    if (cell.heavenStems.contains(2) && cell.earthStems.contains(4)) plus.add(ZeShiFlag.feiNiao);
    for (final g in geJuOf(cell)) {
      (g.good ? plus : minus).add(_geJuFlag[g]!);
    }

    // 年命、日干：所落宮（天盤）逢吉門加分，逢空亡、入墓扣分。
    if (birth != null) {
      for (final stem in {birth.yearStem, birth.dayStem}) {
        final pc = chart.palaces.values.where((c) => c.palace != 5 && c.heavenStems.contains(stem));
        if (pc.isEmpty) continue;
        final c = pc.first;
        if (c.kongWang || c.ruMu.contains(stem)) {
          if (!minus.contains(ZeShiFlag.mingXiong)) minus.add(ZeShiFlag.mingXiong);
        } else if (c.door?.luck == Luck.good) {
          if (!plus.contains(ZeShiFlag.mingJi)) plus.add(ZeShiFlag.mingJi);
        }
      }
    }
    return (4 + plus.length - minus.length, [...plus, ...minus]);
  }

  /// 本五行是否生 [b]（木生火、火生土、土生金、金生水、水生木）。
  static bool _generates(Element a, Element b) => b.index == (a.index + 1) % 5;

  int _dayKey(DateTime utc, TimeSettings s) {
    final c = engine.calendar.clockTime(utc, s);
    return c.year * 10000 + c.month * 100 + c.day;
  }

  static const _geJuFlag = {
    GeJu.goodStar: ZeShiFlag.goodStar,
    GeJu.sanDun: ZeShiFlag.sanDun,
    GeJu.badStar: ZeShiFlag.badStar,
    GeJu.siXiong: ZeShiFlag.siXiong,
    GeJu.gengBing: ZeShiFlag.gengBing,
  };

  static const _goodGods = {God.zhiFu, God.taiYin, God.liuHe, God.jiuDi, God.jiuTian};
  static const _badGods = {God.baiHu, God.xuanWu, God.tengShe};
}
