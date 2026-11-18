import 'package:shared_preferences/shared_preferences.dart';

import '../../app/settings/app_settings.dart';
import '../../app/widgets/hour_window.dart';
import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import 'travel_text.dart';

/// 出行訣的設定（本機）。
class TravelPrefs {
  TravelPrefs._(this._p);
  final SharedPreferences _p;

  static Future<TravelPrefs> load() async => TravelPrefs._(await SharedPreferences.getInstance());

  /// 吉時推播：預設開（比照謙卦每日提醒）。
  bool get notify => _p.getBool('travel_notify') ?? true;
  Future<void> setNotify(bool v) => _p.setBool('travel_notify', v);

  TravelEvent get event =>
      TravelEvent.values.firstWhere((e) => e.name == _p.getString('travel_event'), orElse: () => TravelEvent.general);
  Future<void> setEvent(TravelEvent e) => _p.setString('travel_event', e.name);

  /// 吉時前幾分鐘通知（10／20／30／60）。
  static const leadOptions = [10, 20, 30, 60];
  int get leadMinutes {
    final v = _p.getInt('travel_notify_lead') ?? 10;
    return leadOptions.contains(v) ? v : 10;
  }

  Future<void> setLeadMinutes(int v) => _p.setInt('travel_notify_lead', v);

  /// 推播時段（預設 7–21 點，可設全天）。
  HourWindow get window => HourWindow.read(_p.getInt('travel_notify_from'), _p.getInt('travel_notify_to'));
  Future<void> setWindow(HourWindow w) async {
    await _p.setInt('travel_notify_from', w.from);
    await _p.setInt('travel_notify_to', w.to);
  }

  /// 每天最多幾則（1–3）。
  int get perDay => (_p.getInt('travel_notify_per_day') ?? 1).clamp(1, 3);
  Future<void> setPerDay(int v) => _p.setInt('travel_notify_per_day', v);

  /// 是否已請求過通知權限（第一次看到結果時請求一次）。
  bool get askedPermission => _p.getBool('notify_permission_asked') ?? false;
  Future<void> setAskedPermission() => _p.setBool('notify_permission_asked', true);

  /// 首次進出行訣顯示 3 頁引導。
  bool get introSeen => _p.getBool('travel_intro_seen') ?? false;
  Future<void> setIntroSeen() => _p.setBool('travel_intro_seen', true);
}

/// 吉時推播：一次排未來 7 天，每天在設定時段內最佳的 1–3 個吉時（未達「吉」不提醒），開始前 N 分鐘通知（預設 7–21 點、10 分鐘、1 則）。
/// 夜間（22–6 點）的時辰在標題標示。App 每次啟動、切換事類或改設定時重排。
class TravelReminders {
  TravelReminders._();

  static const dailyFrom = 1000, dailyTo = 1019;
  static const slotReminderFrom = 1020, slotReminderTo = 1039;
  static const sessionEnd = 1040;
  static const lead = Duration(minutes: 10);
  static const channelId = 'qm_lucky_hours';

  /// 排盤設定（時區取裝置；子時換日、真太陽時取設定頁）。
  static TimeSettings get timeSettings => AppSettings.instance.timeSettingsAt(DateTime.now());

  static Future<void> reschedule() async {
    final prefs = await TravelPrefs.load();
    await Notifications.cancelRange(dailyFrom, dailyTo);
    if (!prefs.notify || !await Notifications.enabled()) return;
    final now = DateTime.now().toUtc();
    final w = prefs.window;
    final slots = const ChuXingPlanner()
        .dailyBest(now, prefs.event, settings: timeSettings, fromHour: w.from, toHour: w.to, perDay: prefs.perDay);
    final lead = Duration(minutes: prefs.leadMinutes);
    var id = dailyFrom;
    for (final s in slots) {
      if (id > dailyTo) break;
      final at = s.startUtc.subtract(lead);
      if (!at.isAfter(now)) continue;
      await _scheduleSlot(id++, s, prefs.event, at);
    }
  }

  /// 使用者在列表上點「提醒我」：該時辰開始前 10 分鐘提醒。
  static Future<bool> remindSlot(TravelSlot s, TravelEvent event) async {
    if (!await Notifications.enabled() && !await Notifications.requestPermission()) return false;
    final now = DateTime.now().toUtc();
    var at = s.startUtc.subtract(lead);
    if (!at.isAfter(now)) at = now.add(const Duration(seconds: 5));
    final id = slotReminderFrom + (s.startUtc.millisecondsSinceEpoch ~/ 7200000) % (slotReminderTo - slotReminderFrom + 1);
    await _scheduleSlot(id, s, event, at);
    return true;
  }

  static Future<void> _scheduleSlot(int id, TravelSlot s, TravelEvent event, DateTime at) {
    final l = L10n.current;
    final lang = L10n.language;
    final dir = TravelText.direction(l, s.palace);
    return Notifications.schedule(
      id: id,
      title: _night(s) ? '${l.travelNotifyTitle(TravelText.event(l, event), dir)}${l.travelNightTag}' : l.travelNotifyTitle(TravelText.event(l, event), dir),
      body: l.travelNotifyBody(TravelText.timeRange(s), dir, QimenTerms.door(s.door, lang)),
      atUtc: at,
      channelId: channelId,
      channelName: l.travelChannelName,
      payload: payload,
    );
  }

  static bool _night(TravelSlot s) =>
      HourWindow.isNight(const ChuXingPlanner().engine.calendar.clockTime(s.startUtc, timeSettings).hour);

  /// 點通知開出行訣頁。
  static const payload = 'travel';
}
