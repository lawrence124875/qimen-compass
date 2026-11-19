import 'calendar_service.dart';
import 'chuxing.dart';
import 'ganzhi.dart';
import 'qimen_types.dart';
import 'shijia_engine.dart';

/// 今日奇門黃曆（HANDOFF §12 P3）：一天 12 個時辰（子時起）的出行吉方，挑出吉時與今日吉方。
/// 規則沿用出行訣「一般出行」（開休生取最佳）。
class DailyAlmanac {
  DailyAlmanac._(this.date, this.day, this.slots);

  /// 當地日期（只看年月日）。
  final DateTime date;

  /// 日柱。
  final GanZhi day;

  /// 子時起 12 個時辰。
  final List<TravelSlot> slots;

  /// 吉時：「吉」以上，分數高者優先，最多 [n] 個，依時間排序。
  List<TravelSlot> best([int n = 3]) {
    final list = slots.where((s) => s.recommended).toList()
      ..sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : a.startUtc.compareTo(b.startUtc);
      });
    return list.take(n).toList()..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  /// 今日吉方：最高分時辰的吉門方位（宮）；全天都未達「吉」時為 null。
  int? get bestPalace {
    final b = best(1);
    return b.isEmpty ? null : b.first.palace;
  }

  static DailyAlmanac of(
    DateTime date, {
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
    ShiJiaEngine engine = const ShiJiaEngine(),
  }) {
    final d = DateTime(date.year, date.month, date.day);
    // 當地正午的 UTC 時刻 → 當天日柱；子時起點＝前一天 23:00（時辰邊界依 slotStart）
    final noonUtc = DateTime.utc(d.year, d.month, d.day, 12).subtract(settings.utcOffset);
    final planner = ChuXingPlanner(engine: engine);
    final dayPillar = engine.compute(noonUtc, settings: settings, method: method).day;
    final firstUtc = DateTime.utc(d.year, d.month, d.day, 0, 30).subtract(settings.utcOffset);
    final slots = planner.plan(firstUtc, TravelEvent.general, settings: settings, method: method, count: 12);
    return DailyAlmanac._(d, dayPillar, slots);
  }
}
