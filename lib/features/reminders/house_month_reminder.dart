import '../../app/settings/app_settings.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import '../house/house_model.dart';
import '../travel/travel_text.dart';
import 'day_alert_reminder.dart';

/// 宅盤流月提醒（訂閱，HANDOFF §10 C）：接下來 3 個「節」（月令交接）前一晚、與重要日提醒同一時間，
/// 告訴你新月盤哪兩方轉吉、哪兩方轉凶（有標房間時附房間名），提醒打開宅盤看擺件調整。
/// id 1310–1312；開關沿用重要日提醒（`alert_on`）；沒存過宅盤不排。App 啟動、訂閱狀態改變時重排。
class HouseMonthReminder {
  HouseMonthReminder._();

  static const idFrom = 1310, idTo = 1312;
  static const channelId = 'qm_house_month';

  /// 訂閱戶才排（main 依訂閱狀態設定）。
  static bool premium = false;

  static Future<void> reschedule() async {
    await Notifications.cancelRange(idFrom, idTo);
    if (!premium || !await DayAlertReminder.enabled() || !await Notifications.enabled()) return;
    final houses = await HouseStore.all();
    if (houses.isEmpty) return;
    final house = await HouseStore.load();
    final rooms = house.roomsByPalace();
    final s = AppSettings.instance;
    final now = DateTime.now();
    final at = await DayAlertReminder.time();
    final l = L10n.current;
    final lang = L10n.language;
    const engine = ShiJiaEngine();
    final from = now.toUtc();
    final terms = engine.calendar
        .termsBetween(from, from.add(const Duration(days: 100)))
        .where((t) => t.index.isOdd && t.startUtc.isAfter(from))
        .take(3);
    String name(int p) {
      final r = rooms[p];
      final dir = TravelText.direction(l, p);
      return r == null || r.isEmpty ? dir : '$dir（${r.join(l.separator)}）';
    }

    var id = idFrom;
    for (final t in terms) {
      final local = t.startUtc.toLocal();
      final eve = DateTime(local.year, local.month, local.day - 1, at.hour, at.minute);
      if (!eve.isAfter(now)) continue;
      final mid = t.startUtc.add(const Duration(days: 1));
      final chart = engine.compute(mid, settings: s.timeSettingsAt(mid.toLocal()), method: s.juMethod, unit: PanUnit.month);
      final vs = [for (final p in palaceRing) DirectionPlanner.judge(chart, p)]..sort((a, b) => b.score.compareTo(a.score));
      final good = vs.where((v) => v.recommended).take(2).map((v) => name(v.palace)).toList();
      final bad = vs.reversed.where((v) => !v.recommended && v.level != TravelLevel.neutral).take(2).map((v) => name(v.palace)).toList();
      await Notifications.schedule(
        id: id++,
        title: l.houseMonthTitle(QimenTerms.solarTerm(t.index, lang)),
        body: l.houseMonthBody(good.isEmpty ? '—' : good.join(l.separator), bad.isEmpty ? '—' : bad.join(l.separator)),
        atUtc: eve.toUtc(),
        channelId: channelId,
        channelName: l.houseMonthChannel,
      );
      if (id > idTo) break;
    }
  }
}
