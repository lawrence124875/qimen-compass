import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import '../travel/travel_reminders.dart';
import '../travel/travel_text.dart';

/// 每日提醒（比照謙卦）：預設開、早上 8 點，一次排 7 天一次性通知（id 1050–1056），內容是當天最佳吉時。
/// 不請求精確鬧鐘權限；啟動時不要求通知權限（出行訣第一次看到結果才要求）。App 每次啟動、改設定時重排。
class DailyReminder {
  DailyReminder._();

  static const idFrom = 1050, idTo = 1056;
  static const channelId = 'qm_daily';

  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<bool> enabled() async => (await _p).getBool('daily_on') ?? true;

  static Future<TimeOfDay> time() async {
    final p = await _p;
    return TimeOfDay(hour: p.getInt('daily_hour') ?? 8, minute: p.getInt('daily_minute') ?? 0);
  }

  static Future<void> set({required bool on, TimeOfDay? at}) async {
    final p = await _p;
    await p.setBool('daily_on', on);
    if (at != null) {
      await p.setInt('daily_hour', at.hour);
      await p.setInt('daily_minute', at.minute);
    }
    await reschedule();
  }

  static Future<void> reschedule() async {
    await Notifications.cancelRange(idFrom, idTo);
    if (!await enabled() || !await Notifications.enabled()) return;
    final at = await time();
    final prefs = await TravelPrefs.load();
    final event = prefs.event;
    final now = DateTime.now();
    final best = const ChuXingPlanner()
        .dailyBest(now.toUtc(), event, settings: TravelReminders.timeSettings, days: 8);
    final l = L10n.current;
    final lang = L10n.language;
    for (var i = 0; i < 7; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final fire = DateTime(day.year, day.month, day.day, at.hour, at.minute);
      if (!fire.isAfter(now)) continue;
      TravelSlot? slot;
      for (final s in best) {
        final local = s.startUtc.toLocal();
        if (local.year == day.year && local.month == day.month && local.day == day.day) slot = s;
      }
      final body = slot == null
          ? l.dailyBodyNone
          : l.dailyBody(TravelText.timeRange(slot), TravelText.direction(l, slot.palace), QimenTerms.door(slot.door, lang));
      await Notifications.schedule(
        id: idFrom + i,
        title: l.dailyTitle(TravelText.event(l, event)),
        body: body,
        atUtc: fire.toUtc(),
        channelId: channelId,
        channelName: l.dailyChannelName,
      );
    }
  }
}

/// 設定頁的每日提醒對話框：開關＋時間。開啟時若還沒允許通知就請求一次。
Future<void> showDailyReminderDialog(BuildContext context) async {
  final l = context.l10n;
  var on = await DailyReminder.enabled();
  var at = await DailyReminder.time();
  if (!context.mounted) return;
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.dailyReminder),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.dailyReminderOn),
            subtitle: Text(l.dailyReminderHint),
            value: on,
            onChanged: (v) => setState(() => on = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: on,
            title: Text(l.dailyReminderTime),
            trailing: Text(at.format(ctx)),
            onTap: () async {
              final picked = await showTimePicker(context: ctx, initialTime: at);
              if (picked != null) setState(() => at = picked);
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.ok)),
        ],
      ),
    ),
  );
  if (saved != true) return;
  if (on && !await Notifications.enabled()) await Notifications.requestPermission();
  await DailyReminder.set(on: on, at: at);
}
