import 'calendar_service.dart';
import 'ganzhi.dart';
import 'qimen_types.dart';

/// 局數表：[節氣序（冬至＝0）] → [上元, 中元, 下元]。
const List<List<int>> juTable = [
  [1, 7, 4], [2, 8, 5], [3, 9, 6], [8, 5, 2], [9, 6, 3], [1, 7, 4], // 冬至 小寒 大寒 立春 雨水 驚蟄
  [3, 9, 6], [4, 1, 7], [5, 2, 8], [4, 1, 7], [5, 2, 8], [6, 3, 9], // 春分 清明 穀雨 立夏 小滿 芒種
  [9, 3, 6], [8, 2, 5], [7, 1, 4], [2, 5, 8], [1, 4, 7], [9, 3, 6], // 夏至 小暑 大暑 立秋 處暑 白露
  [7, 1, 4], [6, 9, 3], [5, 8, 2], [6, 9, 3], [5, 8, 2], [4, 7, 1], // 秋分 寒露 霜降 立冬 小雪 大雪
];

/// 三奇六儀在地盤的排列順序：戊己庚辛壬癸丁丙乙。
const List<int> qiYiOrder = [4, 5, 6, 7, 8, 9, 3, 2, 1];

/// 六甲旬首遁藏的六儀：甲子戊、甲戌己、甲申庚、甲午辛、甲辰壬、甲寅癸（以旬首地支為鍵）。
const Map<int, int> xunHiddenStem = {0: 4, 10: 5, 8: 6, 6: 7, 4: 8, 2: 9};

/// 六儀擊刑：天干 → 擊刑宮。
const Map<int, int> jiXingPalace = {4: 3, 5: 2, 6: 8, 7: 9, 8: 4, 9: 4};

/// 十干入墓：天干 → 墓宮（甲癸未2、乙丙戊戌6、丁己庚丑8、辛壬辰4）。
const Map<int, int> ruMuPalace = {0: 2, 1: 6, 2: 6, 3: 8, 4: 6, 5: 8, 6: 8, 7: 4, 8: 4, 9: 2};

/// 定局結果。
class JuInfo {
  const JuInfo(this.dun, this.ju, this.yuan, this.termIndex);
  final Dun dun;
  final int ju;
  final Yuan yuan;
  final int termIndex;
}

/// 時家轉盤奇門引擎（純 Dart）。
class ShiJiaEngine {
  const ShiJiaEngine({this.calendar = const CalendarService()});

  final CalendarService calendar;

  /// 起局。[unit] 目前只支援 [PanUnit.hour]。
  QimenChart compute(
    DateTime instant, {
    TimeSettings settings = const TimeSettings(),
    JuMethod method = JuMethod.chaiBu,
    PanUnit unit = PanUnit.hour,
  }) {
    if (unit != PanUnit.hour) {
      throw UnsupportedError('V1 只實作時家盤（PanUnit.hour）');
    }
    final m = calendar.momentAt(instant, settings);
    final ju = method == JuMethod.chaiBu ? juChaiBu(m) : juZhiRun(m, settings);
    return buildChart(m, ju, method: method);
  }

  /// 拆補法：節氣取真實節氣，元取符頭（最近的甲日或己日）地支。
  /// 符頭地支：子午卯酉＝上元、寅申巳亥＝中元、辰戌丑未＝下元；
  /// 等同於日柱在 15 日循環（甲子、己卯、甲午、己酉起）中的位置。
  JuInfo juChaiBu(CalendarMoment m) => _juOf(m.term.index, _yuanOf(m.dayNumber));

  /// 置閏法：每 15 日（上元符頭甲子／己卯／甲午／己酉起）配一個節氣；
  /// 符頭在節氣前為超神、在後為接氣；芒種、大雪時若超神超過 9 日則該節氣再排一次（置閏）。
  /// 自 6 年前的芒種／大雪起推算，經過一次置閏後即與起點無關。
  JuInfo juZhiRun(CalendarMoment m, TimeSettings settings) {
    final from = m.instantUtc.subtract(const Duration(days: 365 * 6));
    final terms = calendar.termsBetween(from, m.instantUtc.add(const Duration(days: 40)));
    int dayOf(SolarTerm t) => _effectiveDay(calendar.clockTime(t.startUtc, settings), settings);

    var j = terms.indexWhere((t) => t.index == 11 || t.index == 23);
    // 起點：取超神天數落在 (-6, 9] 的上元符頭。
    final t0 = dayOf(terms[j]);
    var block = _blockStart(t0);
    if (t0 - block > 9) block += 15;
    var leaped = false;
    final target = _blockStart(m.dayNumber);
    while (block < target) {
      final t = terms[j];
      final checkpoint = t.index == 11 || t.index == 23;
      if (checkpoint && !leaped && dayOf(t) - block > 9) {
        leaped = true; // 下一個 15 日仍用此節氣
      } else {
        leaped = false;
        j++;
      }
      block += 15;
    }
    return _juOf(terms[j].index, _yuanOf(m.dayNumber));
  }

  static int _effectiveDay(DateTime clock, TimeSettings s) {
    final civil = CalendarService.civilDayNumber(clock);
    return clock.hour == 23 && s.ziHour == ZiHourMode.nextDay ? civil + 1 : civil;
  }

  /// 該日所在 15 日循環的起日（上元符頭）。
  static int _blockStart(int dayNumber) => dayNumber - (dayNumber + 49) % 15;

  static Yuan _yuanOf(int dayNumber) => Yuan.values[((dayNumber + 49) % 15) ~/ 5];

  static JuInfo _juOf(int term, Yuan yuan) =>
      JuInfo(term < 12 ? Dun.yang : Dun.yin, juTable[term][yuan.index], yuan, term);

  /// 依已定的局排盤。
  QimenChart buildChart(CalendarMoment m, JuInfo info, {JuMethod method = JuMethod.chaiBu}) {
    final yang = info.dun == Dun.yang;
    final palaces = {for (var p = 1; p <= 9; p++) p: PalaceChart(p)};
    int step(int from, int n) => ((from - 1 + (yang ? n : -n)) % 9 + 9) % 9 + 1;
    int lodge(int p) => p == 5 ? 2 : p;
    int ringIdx(int p) => palaceRing.indexOf(p);

    // 1. 地盤：戊起於局數宮，陽順陰逆排三奇六儀。
    final earthPalaceOf = <int, int>{};
    for (var i = 0; i < 9; i++) {
      final p = step(info.ju, i);
      earthPalaceOf[qiYiOrder[i]] = p;
      palaces[p]!.earthStems.add(qiYiOrder[i]);
    }
    palaces[2]!.earthStems.addAll(palaces[5]!.earthStems); // 中五寄坤二

    // 2. 旬首 → 值符、值使。
    final hour = m.hour;
    final xun = GanZhi(hour.xunStart);
    final hidden = xunHiddenStem[xun.branch]!;
    final p0 = earthPalaceOf[hidden]!;
    final zhiFu = Star.atHome(p0);
    final zhiShi = Door.atHome(lodge(p0));

    // 3. 天盤九星：值符隨時干（甲時用旬首六儀）落宮，其餘沿外環順時針同轉。
    final hourStem = hour.stem == 0 ? hidden : hour.stem;
    final starTarget = lodge(earthPalaceOf[hourStem]!);
    final starShift = (ringIdx(starTarget) - ringIdx(lodge(p0)) + 8) % 8;
    for (var i = 0; i < 8; i++) {
      final home = palaceRing[i];
      final dest = palaces[palaceRing[(i + starShift) % 8]]!;
      dest.stars.add(Star.atHome(home));
      dest.heavenStems.addAll(palaces[home]!.earthStems);
      if (home == 2) dest.stars.add(Star.qin); // 禽寄芮
    }
    // 坤二宮的地盤已含中五宮天干，所以天芮所落宮的天盤同時帶上天禽的天干。

    // 4. 人盤八門：值使從旬首宮起，依時干序數陽順陰逆走九宮（入中五寄坤二），其餘沿外環同轉。
    final doorTarget = lodge(step(p0, hour.stem));
    final doorShift = (ringIdx(doorTarget) - ringIdx(zhiShi.home) + 8) % 8;
    for (var i = 0; i < 8; i++) {
      palaces[palaceRing[(i + doorShift) % 8]]!.door = Door.atHome(palaceRing[i]);
    }

    // 5. 神盤八神：值符隨值符星，陽遁順時針、陰遁逆時針。
    final godStart = ringIdx(starTarget);
    for (var i = 0; i < 8; i++) {
      final idx = ((godStart + (yang ? i : -i)) % 8 + 8) % 8;
      palaces[palaceRing[idx]]!.god = God.values[i];
    }

    // 6. 標記。
    for (final b in hour.kongWang) {
      palaces[branchPalace[b]]!.kongWang = true;
    }
    palaces[branchPalace[_horseBranch(hour.branch)]]!.horse = true;
    for (final p in palaces.values) {
      if (p.palace == 5) continue;
      p.menPo = p.door!.element.overcomes(palaceElement[p.palace]!);
      for (final s in p.heavenStems) {
        if (jiXingPalace[s] == p.palace) p.jiXing.add(s);
        if (ruMuPalace[s] == p.palace) p.ruMu.add(s);
      }
    }

    return QimenChart(
      unit: PanUnit.hour,
      method: method,
      dun: info.dun,
      ju: info.ju,
      yuan: info.yuan,
      termIndex: info.termIndex,
      year: m.year,
      month: m.month,
      day: m.day,
      hour: hour,
      xunShou: xun,
      zhiFu: zhiFu,
      zhiShi: zhiShi,
      palaces: palaces,
      starFuYin: starShift == 0,
      starFanYin: starShift == 4,
      doorFuYin: doorShift == 0,
      doorFanYin: doorShift == 4,
    );
  }

  /// 驛馬：申子辰馬在寅、寅午戌馬在申、巳酉丑馬在亥、亥卯未馬在巳。
  static int _horseBranch(int b) => const [2, 11, 8, 5, 2, 11, 8, 5, 2, 11, 8, 5][b];
}
