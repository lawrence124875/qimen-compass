import '../../engine/engine.dart';
import '../../l10n/l10n.dart';

/// 出行訣的顯示文字（介面文字一律經 ARB）。
class TravelText {
  TravelText._();

  static String event(AppLocalizations l, TravelEvent e) => switch (e) {
        TravelEvent.general => l.travelEventGeneral,
        TravelEvent.wealth => l.travelEventWealth,
        TravelEvent.career => l.travelEventCareer,
        TravelEvent.love => l.travelEventLove,
        TravelEvent.exam => l.travelEventExam,
      };

  static String level(AppLocalizations l, TravelLevel v) => switch (v) {
        TravelLevel.great => l.levelGreat,
        TravelLevel.good => l.levelGood,
        TravelLevel.neutral => l.levelNeutral,
        TravelLevel.minor => l.levelMinor,
        TravelLevel.blocked => l.levelBlocked,
      };

  static String flag(AppLocalizations l, TravelFlag f) => switch (f) {
        TravelFlag.menPo => l.flagMenPo,
        TravelFlag.kongWang => l.flagKongWang,
        TravelFlag.fuYin => l.flagFuYin,
        TravelFlag.fanYin => l.flagFanYin,
        TravelFlag.jiXing => l.flagJiXing,
        TravelFlag.ruMu => l.flagRuMu,
        TravelFlag.goodGod => l.flagGoodGod,
        TravelFlag.badGod => l.flagBadGod,
      };

  static String direction(AppLocalizations l, int palace) => switch (palace) {
        1 => l.dirN,
        8 => l.dirNE,
        3 => l.dirE,
        4 => l.dirSE,
        9 => l.dirS,
        2 => l.dirSW,
        7 => l.dirW,
        _ => l.dirNW,
      };

  static String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  /// 例如「11:00–13:00」（裝置當地時間）。
  static String timeRange(TravelSlot s) => '${_hm(s.startUtc)}–${_hm(s.endUtc)}';

  /// 時辰名，例如「午時」。
  static String hourName(AppLocalizations l, TravelSlot s) => l.travelHourName(branchNames[s.hour.branch]);
}
