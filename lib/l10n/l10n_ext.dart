import '../engine/qimen_types.dart';
import 'app_localizations.dart';
import 'terms.dart';

/// 依引擎列舉取 ARB 文字（ARB 不支援列舉，集中在這裡對照）。
extension QimenL10n on AppLocalizations {
  String luck(Luck l) => switch (l) { Luck.good => luckGood, Luck.neutral => luckNeutral, Luck.bad => luckBad };

  /// 宮位方位（洛書數 1–9）。
  String palaceDirection(int p) => switch (p) {
        1 => dirN,
        8 => dirNE,
        3 => dirE,
        4 => dirSE,
        9 => dirS,
        2 => dirSW,
        7 => dirW,
        6 => dirNW,
        _ => dirCenter,
      };

  String markHint(ChartMark m) => switch (m) {
        ChartMark.kongWang => markKongWang,
        ChartMark.horse => markHorse,
        ChartMark.menPo => markMenPo,
        ChartMark.jiXing => markJiXing,
        ChartMark.ruMu => markRuMu,
      };
}
