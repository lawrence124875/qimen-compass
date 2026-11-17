import 'dart:math' as math;

import 'package:lunar/lunar.dart';

import 'ganzhi.dart';

/// 二十四節氣，序號自冬至起（0＝冬至 … 23＝大雪）。
const List<String> solarTermNames = [
  '冬至', '小寒', '大寒', '立春', '雨水', '驚蟄', '春分', '清明', '穀雨', '立夏', '小滿', '芒種', //
  '夏至', '小暑', '大暑', '立秋', '處暑', '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪',
];

/// `lunar` 套件的節氣名稱（簡體），順序同 [solarTermNames]。
const List<String> _lunarTermNames = [
  '冬至', '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满', '芒种', //
  '夏至', '小暑', '大暑', '立秋', '处暑', '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪',
];

/// 子時換日方式。
enum ZiHourMode {
  /// 23 點起即算次日（日柱、時柱都用次日），奇門常用，預設。
  nextDay,

  /// 分早晚子時：23–24 點為晚子時，日柱仍用當日，時柱用次日子時的干支。
  lateZi,
}

/// 時間設定：時區、真太陽時、子時換日。
class TimeSettings {
  const TimeSettings({
    this.utcOffset = const Duration(hours: 8),
    this.trueSolarTime = false,
    this.longitude,
    this.ziHour = ZiHourMode.nextDay,
  }) : assert(!trueSolarTime || longitude != null, '真太陽時需要經度');

  /// 使用者所在時區（標準時，不含夏令時；夏令時由呼叫端換算）。
  final Duration utcOffset;

  /// 是否依經度修正為真太陽時（平太陽時＋均時差）。
  final bool trueSolarTime;

  /// 東經為正，西經為負。
  final double? longitude;

  final ZiHourMode ziHour;
}

/// 一個節氣的交節時刻。
class SolarTerm {
  const SolarTerm(this.index, this.startUtc);

  /// 0＝冬至 … 23＝大雪。
  final int index;
  final DateTime startUtc;

  String get name => solarTermNames[index];

  /// 陽遁（冬至～芒種）。
  bool get isYang => index < 12;

  @override
  String toString() => '$name@${startUtc.toIso8601String()}';
}

/// 某一時刻的曆法資料（四柱、節氣）。
class CalendarMoment {
  const CalendarMoment({
    required this.instantUtc,
    required this.clock,
    required this.dayNumber,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.term,
  });

  /// 真實時刻（UTC）。
  final DateTime instantUtc;

  /// 排盤用的鐘面時間（當地標準時或真太陽時；以 UTC 欄位表示，不受裝置時區影響）。
  final DateTime clock;

  /// 日柱對應的儒略日數（已處理子時換日）。
  final int dayNumber;

  final GanZhi year;
  final GanZhi month;
  final GanZhi day;
  final GanZhi hour;

  /// 目前所在節氣（依真實時刻判斷）。
  final SolarTerm term;
}

/// 曆法服務：包裝 `lunar`（6tail）取得節氣，干支由儒略日自行推算。
/// 純 Dart，日後可抽成共用套件。
class CalendarService {
  const CalendarService();

  static const _beijing = Duration(hours: 8);

  /// 取得某一時刻的曆法資料。
  CalendarMoment momentAt(DateTime instant, TimeSettings settings) {
    final utc = instant.toUtc();
    final clock = clockTime(utc, settings);
    final civil = civilDayNumber(clock);
    final late = clock.hour == 23;
    final dayNumber = late && settings.ziHour == ZiHourMode.nextDay ? civil + 1 : civil;
    final day = dayGanZhi(dayNumber);
    final hourBranch = ((clock.hour + 1) ~/ 2) % 12;
    // 五鼠遁：子時天干＝(日干 % 5) × 2；晚子時用次日日干。
    final hourDayStem = late ? dayGanZhi(civil + 1).stem : day.stem;
    final hour = GanZhi.of(((hourDayStem % 5) * 2 + hourBranch) % 10, hourBranch);

    // 年柱、月柱依節氣交接的真實時刻（lunar 以北京時間計）。
    final bj = utc.add(_beijing);
    final lunar = Solar.fromYmdHms(bj.year, bj.month, bj.day, bj.hour, bj.minute, bj.second).getLunar();
    return CalendarMoment(
      instantUtc: utc,
      clock: clock,
      dayNumber: dayNumber,
      year: GanZhi.parse(lunar.getYearInGanZhiExact()),
      month: GanZhi.parse(lunar.getMonthInGanZhiExact()),
      day: day,
      hour: hour,
      term: termAt(utc),
    );
  }

  /// 鐘面時間：時區標準時，或真太陽時（經度 × 4 分鐘＋均時差）。
  DateTime clockTime(DateTime utc, TimeSettings s) {
    utc = utc.toUtc();
    if (!s.trueSolarTime) return utc.add(s.utcOffset);
    final mean = utc.add(Duration(microseconds: (s.longitude! * 4 * 60 * 1e6).round()));
    return mean.add(Duration(microseconds: (equationOfTime(utc) * 60 * 1e6).round()));
  }

  /// 均時差（分鐘，真太陽時－平太陽時），NOAA 近似式，誤差約 ±0.5 分。
  static double equationOfTime(DateTime utc) {
    final start = DateTime.utc(utc.year);
    final doy = utc.difference(start).inMinutes / 1440.0; // 0 起算
    final daysInYear = DateTime.utc(utc.year + 1).difference(start).inDays;
    final g = 2 * math.pi / daysInYear * (doy - 0.5);
    return 229.18 *
        (0.000075 +
            0.001868 * math.cos(g) -
            0.032077 * math.sin(g) -
            0.014615 * math.cos(2 * g) -
            0.040849 * math.sin(2 * g));
  }

  /// 鐘面日期的儒略日數（整數，該日中午）。
  static int civilDayNumber(DateTime clock) {
    final a = (14 - clock.month) ~/ 12;
    final y = clock.year + 4800 - a;
    final m = clock.month + 12 * a - 3;
    return clock.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  }

  /// 儒略日數 → 日柱。（2000-01-01 為戊午日，JDN 2451545）
  static GanZhi dayGanZhi(int dayNumber) => GanZhi((dayNumber + 49) % 60);

  /// 某一時刻所在的節氣。
  SolarTerm termAt(DateTime instantUtc) {
    final utc = instantUtc.toUtc();
    final terms = termsBetween(utc.subtract(const Duration(days: 40)), utc.add(const Duration(days: 1)));
    return terms.lastWhere((t) => !t.startUtc.isAfter(utc));
  }

  /// [fromUtc]～[toUtc] 之間（含）所有節氣交節時刻，依時間排序。
  List<SolarTerm> termsBetween(DateTime fromUtc, DateTime toUtc) {
    final seen = <int, SolarTerm>{};
    for (var y = fromUtc.year - 1; y <= toUtc.year + 1; y++) {
      final table = Lunar.fromYmd(y, 6, 1).getJieQiTable();
      for (final e in table.entries) {
        final idx = _termIndex(e.key);
        if (idx < 0) continue;
        final s = e.value;
        final utc = DateTime.utc(s.getYear(), s.getMonth(), s.getDay(), s.getHour(), s.getMinute(), s.getSecond())
            .subtract(_beijing);
        if (utc.isBefore(fromUtc) || utc.isAfter(toUtc)) continue;
        // 同一節氣在相鄰年份表中會重複出現，以分鐘為鍵去重。
        seen[utc.millisecondsSinceEpoch ~/ 60000] = SolarTerm(idx, utc);
      }
    }
    return seen.values.toList()..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  static int _termIndex(String key) {
    const pinyin = {
      'DONG_ZHI': 0, 'XIAO_HAN': 1, 'DA_HAN': 2, 'LI_CHUN': 3, 'YU_SHUI': 4, 'JING_ZHE': 5, 'DA_XUE': 23, //
    };
    return pinyin[key] ?? _lunarTermNames.indexOf(key);
  }
}
