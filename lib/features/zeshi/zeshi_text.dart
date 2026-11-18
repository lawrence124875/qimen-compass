import '../../engine/engine.dart';
import '../../l10n/l10n.dart';

/// 擇時擇日的顯示文字（介面文字一律經 ARB）。
class ZeShiText {
  ZeShiText._();

  static String event(AppLocalizations l, ZeShiEvent e) => switch (e) {
        ZeShiEvent.contract => l.zeshiEventContract,
        ZeShiEvent.opening => l.zeshiEventOpening,
        ZeShiEvent.interview => l.zeshiEventInterview,
        ZeShiEvent.dating => l.zeshiEventDating,
        ZeShiEvent.engagement => l.zeshiEventEngagement,
        ZeShiEvent.journey => l.zeshiEventJourney,
      };

  static bool isPlus(ZeShiFlag f) => f.index <= ZeShiFlag.mingJi.index;

  static String flag(AppLocalizations l, ZeShiFlag f) => switch (f) {
        ZeShiFlag.wangXiang => l.zeshiFlagWangXiang,
        ZeShiFlag.goodGod => l.flagGoodGod,
        ZeShiFlag.favoredGod => l.zeshiFlagFavoredGod,
        ZeShiFlag.sanQi => l.zeshiFlagSanQi,
        ZeShiFlag.qingLong => l.zeshiFlagQingLong,
        ZeShiFlag.feiNiao => l.zeshiFlagFeiNiao,
        ZeShiFlag.mingJi => l.zeshiFlagMingJi,
        ZeShiFlag.qiuSi => l.zeshiFlagQiuSi,
        ZeShiFlag.menPo => l.flagMenPo,
        ZeShiFlag.kongWang => l.flagKongWang,
        ZeShiFlag.fuYin => l.flagFuYin,
        ZeShiFlag.fanYin => l.flagFanYin,
        ZeShiFlag.jiXing => l.flagJiXing,
        ZeShiFlag.ruMu => l.flagRuMu,
        ZeShiFlag.badGod => l.flagBadGod,
        ZeShiFlag.mingXiong => l.zeshiFlagMingXiong,
        ZeShiFlag.goodStar => l.flagGoodStar,
        ZeShiFlag.sanDun => l.flagSanDun,
        ZeShiFlag.badStar => l.flagBadStar,
        ZeShiFlag.siXiong => l.flagSiXiong,
        ZeShiFlag.gengBing => l.flagGengBing,
      };

  /// 例如「11/18（三）11:00–13:00 午時」（裝置當地時間）。
  static String when(AppLocalizations l, ZeShiSlot s) {
    String two(int n) => n.toString().padLeft(2, '0');
    final a = s.startUtc.toLocal();
    final b = s.endUtc.toLocal();
    final wd = l.zeshiWeekdays.split(',')[a.weekday - 1];
    return '${a.month}/${a.day}（$wd）${two(a.hour)}:${two(a.minute)}–${two(b.hour)}:${two(b.minute)}  '
        '${l.travelHourName(branchNames[s.chart.hour.branch])}';
  }
}
