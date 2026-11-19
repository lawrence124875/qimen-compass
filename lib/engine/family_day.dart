import 'calendar_service.dart';
import 'day_alerts.dart';
import 'qimen_types.dart';
import 'zeshi.dart';

/// 家人盤（HANDOFF §12 1.3.0）：某人某天出門、簽約的最佳時辰（擇時計分＋年命），以及當天是否沖生年。
class MemberDay {
  const MemberDay({required this.travel, required this.contract, required this.clash});

  /// 當天（7–21 點、尚未結束的時辰）出門（遠行情境）與簽約的最佳時辰；沒有候選時為 null。
  final ZeShiSlot? travel, contract;

  /// 日支沖此人生年。
  final bool clash;

  /// 「適合」：最佳時辰達「吉」以上且當天不沖生年。
  bool suits(ZeShiSlot? s) => s != null && s.score >= 5 && !clash;
}

class FamilyDayPlanner {
  const FamilyDayPlanner({this.zeShi = const ZeShiPlanner()});

  final ZeShiPlanner zeShi;

  /// [date]（當地日期）的評估；[notBefore] 之前已結束的時辰不列（看今天時傳現在）。
  /// [alerts] 可由呼叫端傳入同一天的 [DayAlerts]，避免每人重算。
  MemberDay evaluate(
    BirthInfo birth,
    DateTime date, {
    DateTime? notBefore,
    DayAlerts? alerts,
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
  }) {
    final d = DateTime(date.year, date.month, date.day);
    final startUtc = DateTime.utc(d.year, d.month, d.day).subtract(settings.utcOffset);
    ZeShiSlot? best(ZeShiEvent e) {
      ZeShiSlot? top;
      final all = zeShi.scan(startUtc.subtract(const Duration(minutes: 1)), e,
          days: 1, fromHour: 7, toHour: 21, birth: birth, settings: settings, method: method);
      for (final s in all) {
        if (notBefore != null && !s.endUtc.isAfter(notBefore.toUtc())) continue;
        if (top == null || s.score > top.score) top = s;
      }
      return top;
    }

    final a = alerts ?? DayAlerts.of(d, settings: settings);
    return MemberDay(travel: best(ZeShiEvent.journey), contract: best(ZeShiEvent.contract), clash: a.clashes(birth.year));
  }
}
