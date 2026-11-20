import 'calendar_service.dart';
import 'chuxing.dart';
import 'direction.dart';
import 'ganzhi.dart';
import 'natal_report.dart';
import 'personal.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';

/// 今日個人運（HANDOFF §10 訂閱平衡 B）：本命 × 大運 × 流日。
/// - [fortune]：今日日盤上年命宮（年干所在宮）的吉凶。
/// - [hours]：今天（[now] 起到當天 21 點）年命宮達吉的時辰，最多 3 個；方位＝年命宮。
/// - [daYun]、[daYunToday]：目前大運（需性別），與大運天干落今日日盤那一宮的吉凶。
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
    final day = personal.fortune(birth, now, PanUnit.day, settings: settings, method: method);
    final local = now.toLocal();
    final hours = personal
        .luckyHours(birth, now, settings: settings, method: method, days: 1, limit: 3)
        .where((v) {
          final t = v.startUtc!.toLocal();
          return t.year == local.year && t.month == local.month && t.day == local.day;
        })
        .toList();
    GanZhi? pillar;
    DirectionVerdict? dy;
    if (male != null) {
      final r = NatalReportEngine(engine: engine)
          .build(birthInstant, male: male, now: now, settings: birthSettings, method: method, keyYearSpan: 0);
      final cur = r.daYun.where((d) => d.startYear <= local.year).lastOrNull;
      if (cur != null) {
        pillar = cur.pillar;
        final p = stemPalace(day.chart, hiddenStemOf(cur.pillar));
        if (p != null) dy = DirectionPlanner.judge(day.chart, p);
      }
    }
    return PersonalDay(fortune: day.verdict, hours: hours, daYun: pillar, daYunToday: dy);
  }
}
