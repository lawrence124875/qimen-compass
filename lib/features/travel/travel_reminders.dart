import 'package:shared_preferences/shared_preferences.dart';

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

  /// 是否已請求過通知權限（第一次看到結果時請求一次）。
  bool get askedPermission => _p.getBool('notify_permission_asked') ?? false;
  Future<void> setAskedPermission() => _p.setBool('notify_permission_asked', true);

  /// 首次進出行訣顯示 3 頁引導。
  bool get introSeen => _p.getBool('travel_intro_seen') ?? false;
  Future<void> setIntroSeen() => _p.setBool('travel_intro_seen', true);
}

/// 吉時推播：一次排未來 7 天，每天 7–21 點間最佳的吉時（未達「吉」的日子不提醒），開始前 10 分鐘通知。
/// App 每次啟動、切換事類或開關時重排。
class TravelReminders {
  TravelReminders._();

  static const dailyFrom = 1000, dailyTo = 1019;
  static const slotReminderFrom = 1020, slotReminderTo = 1039;
  static const sessionEnd = 1040;
  static const lead = Duration(minutes: 10);
  static const channelId = 'qm_lucky_hours';

  /// 目前時區的排盤設定（時區取裝置；真太陽時等設定待設定頁）。
  static TimeSettings get timeSettings => TimeSettings(utcOffset: DateTime.now().timeZoneOffset);

  static Future<void> reschedule() async {
    final prefs = await TravelPrefs.load();
    await Notifications.cancelRange(dailyFrom, dailyTo);
    if (!prefs.notify || !await Notifications.enabled()) return;
    final now = DateTime.now().toUtc();
    final slots = const ChuXingPlanner().dailyBest(now, prefs.event, settings: timeSettings);
    var id = dailyFrom;
    for (final s in slots) {
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
      title: l.travelNotifyTitle(TravelText.event(l, event), dir),
      body: l.travelNotifyBody(TravelText.timeRange(s), dir, QimenTerms.door(s.door, lang)),
      atUtc: at,
      channelId: channelId,
      channelName: l.travelChannelName,
      payload: payload,
    );
  }

  /// 點通知開出行訣頁。
  static const payload = 'travel';
}
