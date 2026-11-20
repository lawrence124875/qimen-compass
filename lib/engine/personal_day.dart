import 'calendar_service.dart';
import 'chuxing.dart';
import 'direction.dart';
import 'ganzhi.dart';
import 'natal_report.dart';
import 'personal.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';

/// 今日個人運（HANDOFF §10 訂閱平衡 B）：本命 × 大運 × 流日。
/// 日家盤尚未支援（V3），「今日」以當天 7–21 點各時盤代表：
/// - [fortune]：今天各時辰年命宮（年干所在宮）吉凶的中位數。
/// - [hours]：今天（[now] 起到當天 21 點）年命宮達吉的時辰，最多 3 個；方位＝年命宮。
/// - [daYun]、[daYunToday]：目前大運（需性別），與大運天干在今天各時盤落宮吉凶的中位數。
class PersonalDay {
  const PersonalDay({required this.fortune, required this.hours, this.daYun, this.daYunToday});

  final DirectionVerdict? fortune;
  final List<DirectionVerdict> hours;
  final GanZhi? daYun;
  final DirectionVerdict? daYunToday;

  /// 卡片等級：以年命宮為主；沒有時用大運宮。
  TravelLevel? get level => (fortune ?? daYunToday)?.level;

  static PersonalDay of(
    DateTime birthInstant, {
    bool? male,
    required DateTime now,
    TimeSettings birthSettings = const TimeSettings(),
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
    ShiJiaEngine engine = const ShiJiaEngine(),
  }) {
    final personal = PersonalEngine(engine: engine);
    final birth = personal.natal(birthInstant, settings: birthSettings, method: method).birth;
    final local = now.toLocal();
    final hours = personal
        .luckyHours(birth, now, settings: settings, method: method, days: 1, limit: 3)
        .where((v) {
          final t = v.startUtc!.toLocal();
          return t.year == local.year && t.month == local.month && t.day == local.day;
        })
        .toList();
    // 今天 7–21 點各時辰盤（時辰中點）
    final planner = ChuXingPlanner(engine: engine);
    final clockNow = engine.calendar.clockTime(now, settings);
    var start = planner.slotStart(now.subtract(Duration(hours: clockNow.hour, minutes: clockNow.minute)), settings);
    final charts = <QimenChart>[];
    for (var i = 0; i < 13; i++) {
      final c = engine.calendar.clockTime(start, settings);
      if (c.hour >= 7 && c.hour < 21) charts.add(engine.compute(start.add(const Duration(hours: 1)), settings: settings, method: method));
      start = start.add(const Duration(hours: 2));
    }
    DirectionVerdict? median(int stem) {
      final vs = [
        for (final c in charts)
          if (stemPalace(c, stem) case final p?) DirectionPlanner.judge(c, p),
      ]..sort((a, b) => a.score.compareTo(b.score));
      return vs.isEmpty ? null : vs[vs.length ~/ 2];
    }

    final fortune = median(birth.yearStem);
    GanZhi? pillar;
    DirectionVerdict? dy;
    if (male != null) {
      final r = NatalReportEngine(engine: engine)
          .build(birthInstant, male: male, now: now, settings: birthSettings, method: method, keyYearSpan: 0);
      final cur = r.daYun.where((d) => d.startYear <= local.year).lastOrNull;
      if (cur != null) {
        pillar = cur.pillar;
        dy = median(hiddenStemOf(cur.pillar));
      }
    }
    return PersonalDay(fortune: fortune, hours: hours, daYun: pillar, daYunToday: dy);
  }
}
