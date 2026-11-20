import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../app/settings/app_settings.dart';
import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../meaning/meaning_content.dart';
import '../personal/profile.dart';
import '../reminders/day_alert_reminder.dart';
import '../travel/travel_text.dart';

/// 桌面小工具可選的顯示項目（HANDOFF §12 小工具自訂）。順序＝設定頁與原生設定畫面的列出順序。
enum WidgetItem {
  door,
  next,
  color,
  almanac,
  msg,
  term,
  pdir(premium: true),
  pcolor(premium: true);

  const WidgetItem({this.premium = false});

  /// 訂閱項目：免費版顯示「訂閱後顯示」，點了開訂閱頁。
  final bool premium;

  static WidgetItem? byName(String s) => WidgetItem.values.where((e) => e.name == s).firstOrNull;
}

/// 小工具尺寸：小 2×1（1 項）、中 4×2（最多 3 項）、大 4×4（九宮盤＋最多 2 項，九宮盤訂閱）。
enum WidgetSize {
  small(1, [WidgetItem.door], 'com.lclab.qimen_compass.QimenWidgetProvider'),
  medium(3, [WidgetItem.door, WidgetItem.next, WidgetItem.color], 'com.lclab.qimen_compass.QimenWidgetMediumProvider'),
  large(2, [WidgetItem.door, WidgetItem.next], 'com.lclab.qimen_compass.QimenWidgetLargeProvider');

  const WidgetSize(this.max, this.defaults, this.androidName);

  final int max;
  final List<WidgetItem> defaults;
  final String androidName;
}

String widgetItemName(AppLocalizations l, WidgetItem i) => switch (i) {
      WidgetItem.door => l.widgetTitle,
      WidgetItem.next => l.nowNextGood,
      WidgetItem.color => l.luckyTitle,
      WidgetItem.almanac => l.widgetItemAlmanac,
      WidgetItem.msg => l.msgTitle,
      WidgetItem.term => l.widgetItemTerm,
      WidgetItem.pdir => l.compassNatal,
      WidgetItem.pcolor => l.luckyPersonal,
    };

/// 桌面小工具：App 開啟時預算 7 天的各項內容（每筆帶起訖時間）交給原生端，
/// 原生端（android_extra/kotlin/QimenWidget*.kt）依時間挑選並在時辰交界自動更新，不需 App 在背景執行。
///
/// 存到 home_widget 的鍵：
/// - `qm_w_items`：{項目: [{s, e, t 標題, m 主文, b 副文?, c 倒數目標 ms?, u 點擊網址?}]}
/// - `qm_w_board`：[{s, e, c: 1–9 宮文字, h: 吉門宮, g: 是否吉}]（訂閱才有）
/// - `qm_w_premium`、`qm_w_names`（原生設定畫面用的文字）、`qm_w_def`（各尺寸預設項目）、`qm_w_cfg`（各小工具自訂，原生端寫）
class QimenHomeWidget {
  QimenHomeWidget._();

  static const uriTravel = 'qimen://travel';
  static const uriPaywall = 'qimen://paywall';
  static const uriMe = 'qimen://me';

  static const _days = 7;

  /// 開 App、訂閱狀態改變、改設定時呼叫（失敗不影響 App）。
  static Future<void> sync(AppLocalizations l, {required bool premium}) async {
    try {
      final data = await build(l, premium: premium, now: DateTime.now());
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.saveWidgetData<bool>('qm_w_premium', premium);
      await refresh();
    } catch (_) {}
  }

  /// 通知三種尺寸的小工具重畫。
  static Future<void> refresh() async {
    for (final s in WidgetSize.values) {
      try {
        await HomeWidget.updateWidget(qualifiedAndroidName: s.androidName);
      } catch (_) {}
    }
  }

  /// 各尺寸預設項目（設定頁存的；沒存過用 [WidgetSize.defaults]）。
  static Future<Map<WidgetSize, List<WidgetItem>>> defaults() async {
    Map<String, dynamic> m = const {};
    try {
      m = jsonDecode(await HomeWidget.getWidgetData<String>('qm_w_def') ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    return {
      for (final s in WidgetSize.values)
        s: m['${s.index}'] is String
            ? (m['${s.index}'] as String).split(',').map(WidgetItem.byName).whereType<WidgetItem>().toList()
            : s.defaults,
    };
  }

  /// 存預設項目；[resetCustom] 時清掉各小工具自己的設定（全部改用預設）。
  static Future<void> saveDefaults(Map<WidgetSize, List<WidgetItem>> d, {bool resetCustom = false}) async {
    await HomeWidget.saveWidgetData<String>(
        'qm_w_def', jsonEncode({for (final e in d.entries) '${e.key.index}': e.value.map((x) => x.name).join(',')}));
    if (resetCustom) await HomeWidget.saveWidgetData<String>('qm_w_cfg', '{}');
    await refresh();
  }

  /// 算出要存的資料（鍵 → JSON 字串）。
  static Future<Map<String, String>> build(AppLocalizations l, {required bool premium, required DateTime now}) async {
    final s = AppSettings.instance;
    final lang = L10n.language;
    final method = s.juMethod;
    final ts = s.timeSettingsAt(now);
    final meaning = await MeaningContent.load(lang);
    final profile = await Profile.load();
    String colorName(Element e) => meaning?.lookup('color', e.zh) ?? e.zh;
    String hm(DateTime t) {
      final x = t.toLocal();
      return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
    }

    int ms(DateTime t) => t.millisecondsSinceEpoch;
    Map<String, Object> entry(DateTime start, DateTime end, String title, String main, {String? sub, DateTime? countdown, String? uri}) => {
          's': ms(start),
          'e': ms(end),
          't': title,
          'm': main,
          if (sub != null && sub.isNotEmpty) 'b': sub,
          if (countdown != null) 'c': ms(countdown),
          if (uri != null) 'u': uri,
        };
    final span = (now.subtract(const Duration(days: 1)), now.add(const Duration(days: _days + 1)));
    final items = <String, List<Map<String, Object>>>{};

    // 此刻吉門、下個吉時（出行訣一般出行，84 個時辰）
    final slots = const ChuXingPlanner().plan(now, TravelEvent.general, settings: ts, method: method, count: _days * 12);
    String dirDoor(TravelSlot x) => l.widgetLine(TravelText.direction(l, x.palace), QimenTerms.doorName(x.door, lang));
    items[WidgetItem.door.name] = [
      for (final x in slots)
        entry(x.startUtc, x.endUtc, l.widgetTitle, dirDoor(x),
            sub: '${TravelText.level(l, x.level)}${l.separator}${TravelText.timeRange(x)}'),
    ];
    items[WidgetItem.next.name] = [
      for (var i = 0; i < slots.length; i++)
        () {
          final x = slots[i];
          final n = slots.skip(i + 1).where((y) => y.recommended).firstOrNull;
          return n == null
              ? entry(x.startUtc, x.endUtc, l.nowNextGood, l.widgetNoneGood)
              : entry(x.startUtc, x.endUtc, l.nowNextGood, dirDoor(n),
                  sub: '${hm(n.startUtc)} ${TravelText.hourName(l, n)}', countdown: n.startUtc);
        }(),
    ];

    // 發訊息時機
    final msgSlots = const ZeShiPlanner().upcoming(now, ZeShiEvent.message, count: _days * 12, settings: ts, method: method);
    bool good(ZeShiSlot x) => x.level == TravelLevel.great || x.level == TravelLevel.good;
    items[WidgetItem.msg.name] = [
      for (var i = 0; i < msgSlots.length; i++)
        () {
          final x = msgSlots[i];
          final n = msgSlots.skip(i).where(good).firstOrNull;
          if (n == null) return entry(x.startUtc, x.endUtc, l.msgTitle, l.msgNoneGood);
          return entry(x.startUtc, x.endUtc, l.msgTitle, identical(n, x) ? l.msgNowGood : l.msgBestAt(hm(n.startUtc)),
              sub: TravelText.level(l, n.level), countdown: identical(n, x) ? null : n.startUtc);
        }(),
    ];

    // 每天：今日吉時、今日吉色、個人吉色
    final birth = profile == null
        ? null
        : BirthInfo.fromInstant(profile.birthInstant, settings: s.timeSettingsAt(profile.birthInstant));
    final almanac = <Map<String, Object>>[], colors = <Map<String, Object>>[], pcolors = <Map<String, Object>>[];
    for (var d = 0; d <= _days; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      final end = DateTime(now.year, now.month, now.day + d + 1);
      final a = DailyAlmanac.of(date, settings: s.timeSettingsAt(date), method: method);
      final best = a.best(3);
      almanac.add(entry(date, end, l.widgetItemAlmanac,
          best.isEmpty ? l.widgetNoGoodToday : best.map((x) => '${hm(x.startUtc)} ${TravelText.direction(l, x.palace)}').join('  ')));
      final c = LuckyColors.ofDay(a.day);
      colors.add(entry(date, end, l.luckyTitle, colorName(c.of(ColorRank.great)),
          sub: [
            l.labelValue(l.luckyWealth, colorName(c.of(ColorRank.wealth))),
            l.labelValue(l.luckyAvoid, colorName(c.of(ColorRank.avoid))),
          ].join(l.separator)));
      if (premium && birth != null) {
        final (b, w) = c.personal(birth.year.stem);
        pcolors.add(entry(date, end, l.luckyPersonal, colorName(b), sub: l.labelValue(l.luckyPersonalAvoid, colorName(w))));
      }
    }
    items[WidgetItem.almanac.name] = almanac;
    items[WidgetItem.color.name] = colors;

    // 節氣與重要日倒數（往後 45 天找）
    final alerts = <DayAlerts>[];
    for (var d = 0; d < 45 + _days; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      final a = DayAlerts.of(date, settings: s.timeSettingsAt(date));
      if (!a.isEmpty) alerts.add(a);
    }
    items[WidgetItem.term.name] = [
      for (var d = 0; d <= _days; d++)
        () {
          final date = DateTime(now.year, now.month, now.day + d);
          final end = DateTime(now.year, now.month, now.day + d + 1);
          final a = alerts.where((x) => !x.date.isBefore(date)).firstOrNull;
          if (a == null) return entry(date, end, l.widgetItemTerm, l.widgetNoAlert);
          final n = DateTime(a.date.year, a.date.month, a.date.day).difference(date).inDays;
          final when = n == 0 ? l.widgetToday : n == 1 ? l.widgetTomorrow : l.widgetInDays(n);
          return entry(date, end, l.widgetItemTerm, DayAlertReminder.kindShort(l, a.kinds.first, a),
              sub: '$when${l.separator}${a.date.month}/${a.date.day}');
        }(),
    ];

    // 訂閱項目
    Map<String, Object> locked(String title) => entry(span.$1, span.$2, title, l.widgetLocked, uri: uriPaywall);
    Map<String, Object> needBirth(String title) => entry(span.$1, span.$2, title, l.luckyNeedBirth, uri: uriMe);
    if (!premium) {
      items[WidgetItem.pdir.name] = [locked(l.compassNatal)];
      items[WidgetItem.pcolor.name] = [locked(l.luckyPersonal)];
    } else if (profile == null) {
      items[WidgetItem.pdir.name] = [needBirth(l.compassNatal)];
      items[WidgetItem.pcolor.name] = [needBirth(l.luckyPersonal)];
    } else {
      final at = profile.birthInstant;
      final natal = const PersonalEngine().natal(at, settings: s.timeSettingsAt(at), method: method);
      final year = const ShiJiaEngine().compute(now, settings: ts, method: method, unit: PanUnit.year);
      final vs = natalLuckyIn(natal, year);
      items[WidgetItem.pdir.name] = [
        entry(span.$1, span.$2, l.compassNatal,
            vs.isEmpty ? l.widgetNoneGood : vs.map((v) => TravelText.direction(l, v.palace)).join('、')),
      ];
      items[WidgetItem.pcolor.name] = pcolors;
    }

    // 迷你九宮時盤（大尺寸，訂閱）
    final board = <Map<String, Object>>[];
    if (premium) {
      const engine = ShiJiaEngine();
      for (final x in slots) {
        final mid = x.startUtc.add(x.endUtc.difference(x.startUtc) ~/ 2);
        final chart = engine.compute(mid, settings: s.timeSettingsAt(mid), method: method);
        final cells = <String>[];
        for (var p = 1; p <= 9; p++) {
          if (p == 5) {
            cells.add('${QimenTerms.dunName(chart.dun, lang)}${chart.ju}\n${hm(x.startUtc)}');
            continue;
          }
          final pc = chart[p];
          cells.add([
            if (pc.god != null) QimenTerms.godName(pc.god!, lang),
            if (pc.stars.isNotEmpty) QimenTerms.starName(pc.stars.first, lang),
            if (pc.door != null) QimenTerms.doorName(pc.door!, lang),
          ].join('\n'));
        }
        board.add({'s': ms(x.startUtc), 'e': ms(x.endUtc), 'c': cells, 'h': x.palace, 'g': x.recommended});
      }
    }

    // 原生設定畫面用的文字
    final names = <String, String>{
      for (final i in WidgetItem.values) i.name: widgetItemName(l, i),
      '_title': l.widgetSettingsTitle,
      '_hint0': l.widgetPickHint(WidgetSize.small.max),
      '_hint1': l.widgetPickHint(WidgetSize.medium.max),
      '_hint2': l.widgetPickHint(WidgetSize.large.max),
      '_tap': l.widgetTapTravel,
      '_lock': l.widgetLockedShort,
      '_done': l.ok,
      '_travel': l.homeTravel,
      '_left': l.widgetLeft,
      '_empty': l.widgetOpenApp,
      '_boardLock': l.widgetLocked,
    };

    return {
      'qm_w_items': jsonEncode(items),
      'qm_w_board': jsonEncode(board),
      'qm_w_names': jsonEncode(names),
      // 舊版原生端（v1.4 以前）讀的鍵，保留給尚未更新的情況
      'qm_widget_slots': jsonEncode([
        for (final e in items[WidgetItem.door.name]!) {'s': e['s'], 'e': e['e'], 'a': e['m'], 'b': e['b'] ?? ''},
      ]),
      'qm_widget_title': l.widgetTitle,
      'qm_widget_empty': l.widgetOpenApp,
    };
  }
}
