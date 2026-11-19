import 'calendar_service.dart';
import 'ganzhi.dart';

/// 節氣與重要日（HANDOFF §12 1.3.0）：交節換局、歲破、月破、四離、四絕，以及日支沖某人生年。
enum DayAlertKind {
  /// 當天交節氣：時家奇門換局，吉方整批改變。
  termChange,

  /// 歲破：日支沖年支（諸事不宜）。
  suiPo,

  /// 月破：日支沖月支（不宜簽約、搬家、開市、嫁娶）。
  yuePo,

  /// 四離：春分、夏至、秋分、冬至前一天（不宜出遠門、開市、嫁娶）。
  siLi,

  /// 四絕：立春、立夏、立秋、立冬前一天。
  siJue,
}

class DayAlerts {
  const DayAlerts({
    required this.date,
    required this.year,
    required this.month,
    required this.day,
    required this.kinds,
    this.term,
  });

  /// 當地日期（只看年月日）。
  final DateTime date;

  /// 當天正午的年柱、月柱、日柱。
  final GanZhi year, month, day;

  /// 依重要性排序：換局、歲破、月破、四離、四絕。
  final List<DayAlertKind> kinds;

  /// 當天交的節氣（[DayAlertKind.termChange] 時有值）。
  final SolarTerm? term;

  bool get isEmpty => kinds.isEmpty;

  /// 日支是否沖 [birthYear] 的年支（沖生肖）。
  bool clashes(GanZhi birthYear) => (day.branch + 6) % 12 == birthYear.branch;

  static const _siLi = {0, 6, 12, 18}; // 冬至、春分、夏至、秋分
  static const _siJue = {3, 9, 15, 21}; // 立春、立夏、立秋、立冬

  /// [date] 這一天（當地日期）的重要日。
  static DayAlerts of(DateTime date, {TimeSettings settings = const TimeSettings(), CalendarService calendar = const CalendarService()}) {
    final d = DateTime(date.year, date.month, date.day);
    final startUtc = DateTime.utc(d.year, d.month, d.day).subtract(settings.utcOffset);
    final endUtc = startUtc.add(const Duration(days: 1));
    final noon = calendar.momentAt(startUtc.add(const Duration(hours: 12)), settings);
    final day = CalendarService.dayGanZhi(CalendarService.civilDayNumber(d));
    final today = calendar.termsBetween(startUtc, endUtc.subtract(const Duration(milliseconds: 1)));
    final tomorrow = calendar.termsBetween(endUtc, endUtc.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
    final kinds = <DayAlertKind>[
      if (today.isNotEmpty) DayAlertKind.termChange,
      if ((day.branch + 6) % 12 == noon.year.branch) DayAlertKind.suiPo,
      if ((day.branch + 6) % 12 == noon.month.branch) DayAlertKind.yuePo,
      if (tomorrow.any((t) => _siLi.contains(t.index))) DayAlertKind.siLi,
      if (tomorrow.any((t) => _siJue.contains(t.index))) DayAlertKind.siJue,
    ];
    return DayAlerts(
      date: d,
      year: noon.year,
      month: noon.month,
      day: day,
      kinds: kinds,
      term: today.isEmpty ? null : today.first,
    );
  }
}
