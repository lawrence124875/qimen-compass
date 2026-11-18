import 'calendar_service.dart';
import 'divination.dart';
import 'ganzhi.dart';
import 'qimen_types.dart';

/// 問事的延伸解讀：決斷、把握度、應期、我方與對方、宜往／忌往方位。
/// 都由 [Reading] 推得，文句由 UI 依語言組合。

/// 決斷：可行／可行但有阻／宜緩／不宜。
enum Decision { go, goWithCare, wait, avoid }

/// 把握度：各因素一致＝高；互相抵銷＝吉凶參半。
enum Confidence { high, medium, mixed }

/// 應期快慢。
enum Pace { fast, medium, slow }

/// 我方（日干）與對方（主用神）誰佔上風。
enum Standing { selfStronger, balanced, otherStronger }

/// 應期：快慢、對應地支、大約日期。
class Timing {
  const Timing({required this.pace, required this.branches, required this.date, required this.afterEmpty});

  final Pace pace;

  /// 應期地支（用神落宮的地支；逢空亡時為空亡的地支＝出空）。
  final List<int> branches;

  /// 大約日期（鐘面日期）；快、中看日支，慢看月支。
  final DateTime date;

  /// 用神逢空亡，應在出空（填實）之時。
  final bool afterEmpty;
}

int _seasonWeight(Season s) => const {Season.wang: 2, Season.xiang: 1, Season.xiu: 0, Season.qiu: -1, Season.si: -2}[s]!;

extension ReadingMore on Reading {
  int get _plus => factors.map((f) => factorWeight[f]!).where((w) => w > 0).fold(0, (a, b) => a + b);
  int get _minus => factors.map((f) => factorWeight[f]!).where((w) => w < 0).fold(0, (a, b) => a - b);

  Decision get decision => switch (verdict) {
        Verdict.great => Decision.go,
        Verdict.good => _minus > 0 ? Decision.goWithCare : Decision.go,
        Verdict.neutral => score >= 0 ? Decision.goWithCare : Decision.wait,
        Verdict.minor => Decision.wait,
        Verdict.blocked => Decision.avoid,
      };

  Confidence get confidence {
    final total = _plus + _minus;
    if (total == 0) return Confidence.medium;
    final ratio = (_plus - _minus).abs() / total;
    if (ratio >= 0.6 && total >= 2) return Confidence.high;
    if (ratio <= 0.3) return Confidence.mixed;
    return Confidence.medium;
  }

  /// 一個用神的強弱：月令旺衰＋落宮生剋＋空亡。
  int strengthOf(YongShenHit h) {
    var s = _seasonWeight(seasonOf(h.element, chart.month.branch));
    final p = h.palace;
    if (p == null) return s - 2;
    final pe = palaceElement[p]!;
    if (pe == h.element || pe.generates(h.element)) s += 1;
    if (pe.overcomes(h.element)) s -= 1;
    if (chart[p].kongWang) s -= 2;
    return s;
  }

  /// 有對象的事（rule.relation）才比較；日干找不到時為 null。
  Standing? get standing {
    if (!rule.relation || self.palace == null) return null;
    final d = strengthOf(self) - strengthOf(main);
    if (d >= 2) return Standing.selfStronger;
    if (d <= -2) return Standing.otherStronger;
    return Standing.balanced;
  }

  /// 宜往方位：吉時取用神落宮；否則取生、開、休門中不逢空亡的第一個宮。中宮不算。
  int? get goodDirection {
    final p = main.palace;
    if ((verdict == Verdict.great || verdict == Verdict.good) && p != null && p != 5) return p;
    for (final d in const [Door.sheng, Door.kai, Door.xiu]) {
      final q = chart.palaceOfDoor(d);
      if (q != 5 && !chart[q].kongWang) return q;
    }
    return null;
  }

  /// 忌往方位：天盤庚所在宮（阻隔），沒有時取白虎宮。
  int? get avoidDirection {
    for (final c in chart.palaces.values) {
      if (c.palace != 5 && c.heavenStems.contains(6)) return c.palace;
    }
    final p = chart.palaces.values.where((c) => c.god == God.baiHu).firstOrNull?.palace;
    return p == 5 ? null : p;
  }

  Pace get pace {
    final cell = mainCell;
    final season = seasonOf(main.element, chart.month.branch);
    var fast = 0, slow = 0;
    if (cell?.horse ?? false) fast++;
    if (chart.doorFanYin || chart.starFanYin) fast++;
    if (season == Season.wang || season == Season.xiang) fast++;
    if (chart.doorFuYin || chart.starFuYin) slow++;
    if (factors.contains(Factor.ruMu)) slow++;
    if (season == Season.qiu || season == Season.si) slow++;
    return fast > slow ? Pace.fast : (slow > fast ? Pace.slow : Pace.medium);
  }

  /// 應期。用神找不到或落中宮時為 null。[asked] 為起局時刻（UTC）。
  Timing? timing(DateTime asked, TimeSettings settings, {CalendarService calendar = const CalendarService()}) {
    final p = main.palace;
    if (p == null || p == 5) return null;
    final empty = chart[p].kongWang;
    final branches = [
      for (var b = 0; b < 12; b++)
        if (branchPalace[b] == p && (!empty || chart.hour.kongWang.contains(b))) b,
    ];
    if (branches.isEmpty) return null;
    final pc = pace;
    final clock = calendar.clockTime(asked, settings);
    final today = DateTime.utc(clock.year, clock.month, clock.day);
    if (pc != Pace.slow) {
      // 快：12 天內第一個應期日；中：第 13 天起的第一個應期日。
      final start = pc == Pace.fast ? 1 : 13;
      for (var i = start; i < start + 12; i++) {
        final d = today.add(Duration(days: i));
        final gz = CalendarService.dayGanZhi(CalendarService.civilDayNumber(d));
        if (branches.contains(gz.branch)) return Timing(pace: pc, branches: branches, date: d, afterEmpty: empty);
      }
    }
    // 慢：下一個月支相符的月份（每 5 天取樣找節氣月，跳過本月）。
    final nowMonth = calendar.momentAt(asked, settings).month.branch;
    for (var i = 5; i <= 400; i += 5) {
      final at = asked.add(Duration(days: i));
      final m = calendar.momentAt(at, settings).month.branch;
      if (m != nowMonth && branches.contains(m)) {
        final c = calendar.clockTime(at, settings);
        return Timing(pace: Pace.slow, branches: branches, date: DateTime.utc(c.year, c.month, c.day), afterEmpty: empty);
      }
    }
    return null;
  }

  /// 宜忌提示的鍵：同宮的門、神，以及盤面標記（文句在內容檔 tips）。
  List<String> get tipKeys {
    final cell = mainCell;
    return [
      if (cell?.door != null) 'door:${cell!.door!.zh}',
      if (cell?.god != null) 'god:${cell!.god!.zh}',
      for (final f in factors)
        if (const {Factor.kongWang, Factor.menPo, Factor.horse, Factor.fuYin, Factor.fanYin, Factor.jiXing, Factor.ruMu}
            .contains(f))
          'flag:${f.name}',
    ];
  }
}
