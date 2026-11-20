import '../../app/settings/app_settings.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import '../personal/profile.dart';
import '../travel/travel_text.dart';
import 'day_alert_reminder.dart';

/// 流年流月關鍵期推播（訂閱）：接下來 3 個「節」起的月盤，年命宮大吉或受阻時，
/// 交節前 3 天、與重要日提醒同一時間發一則，附該月第一週最佳時辰與方位；遇立春另附新一年流年。
/// id 1300–1302；開關沿用重要日提醒（`alert_on`）。App 啟動、訂閱狀態改變、改生日時重排。
class NatalAlertReminder {
  NatalAlertReminder._();

  static const idFrom = 1300, idTo = 1302;
  static const channelId = 'qm_natal_alert';

  /// 訂閱戶才排（main 依訂閱狀態設定）。
  static bool premium = false;

  static Future<void> reschedule() async {
    await Notifications.cancelRange(idFrom, idTo);
    if (!premium || !await DayAlertReminder.enabled() || !await Notifications.enabled()) return;
    final p = await Profile.load();
    if (p == null) return;
    final s = AppSettings.instance;
    final birth = BirthInfo.fromInstant(p.birthInstant, settings: s.timeSettingsAt(p.birthInstant));
    final now = DateTime.now();
    final at = await DayAlertReminder.time();
    final l = L10n.current;
    final lang = L10n.language;
    final alerts = fortuneAlerts(birth, now.toUtc(), settings: s.timeSettingsAt(now), method: s.juMethod);
    var i = 0;
    for (final a in alerts) {
      final local = a.term.startUtc.toLocal();
      final eve = DateTime(local.year, local.month, local.day - 3, at.hour, at.minute);
      if (!eve.isAfter(now)) continue;
      final term = QimenTerms.solarTerm(a.term.index, lang);
      final level = TravelText.level(l, a.verdict.level);
      final b = a.best;
      final when = b == null ? null : _when(b);
      final lines = [
        a.good ? l.natalAlertGood(level) : l.natalAlertBad(level),
        if (b != null && when != null) l.natalAlertBest(when, TravelText.direction(l, b.palace)) else l.natalAlertNoHour,
        if (a.year != null) l.natalAlertYear('${local.year}', TravelText.level(l, a.year!.level)),
      ];
      await Notifications.schedule(
        id: idFrom + i++,
        title: a.good ? l.natalAlertTitleGood(term) : l.natalAlertTitleBad(term),
        body: lines.join('\n'),
        atUtc: eve.toUtc(),
        channelId: channelId,
        channelName: l.natalAlertChannel,
      );
      if (idFrom + i > idTo) break;
    }
  }

  static String _when(DirectionVerdict v) {
    String two(int n) => n.toString().padLeft(2, '0');
    final a = v.startUtc!.toLocal(), b = v.endUtc!.toLocal();
    return '${two(a.month)}/${two(a.day)} ${two(a.hour)}:${two(a.minute)}–${two(b.hour)}:${two(b.minute)}';
  }
}
