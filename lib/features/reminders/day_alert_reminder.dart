import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/settings/app_settings.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import '../family/family_store.dart';
import '../personal/profile.dart';

/// 節氣與重要日提醒（HANDOFF §12 1.3.0）：前一晚（預設 20:00）提醒明天換局、歲破、月破、四離、四絕，
/// 每項附一句具體建議；訂閱（或 `qm_free_alert_clash`=1）再加「日沖誰的生年」。
/// 一次排 14 天（id 1200–1213），App 每次啟動、改設定、改家人時重排。沒有重要日的晚上不發。
class DayAlertReminder {
  DayAlertReminder._();

  static const idFrom = 1200, idTo = 1213;
  static const channelId = 'qm_day_alert';
  static const days = 14;

  /// 是否加上「日沖家人生年」那一行（main 依訂閱與 Remote Config 設定）。
  static bool clashEnabled = false;

  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<bool> enabled() async => (await _p).getBool('alert_on') ?? true;

  static Future<TimeOfDay> time() async {
    final p = await _p;
    return TimeOfDay(hour: p.getInt('alert_hour') ?? 20, minute: p.getInt('alert_minute') ?? 0);
  }

  static Future<void> set({required bool on, TimeOfDay? at}) async {
    final p = await _p;
    await p.setBool('alert_on', on);
    if (at != null) {
      await p.setInt('alert_hour', at.hour);
      await p.setInt('alert_minute', at.minute);
    }
    await reschedule();
  }

  static String kindShort(AppLocalizations l, DayAlertKind k, DayAlerts a) => switch (k) {
        DayAlertKind.termChange => l.alertTermShort(QimenTerms.solarTerm(a.term!.index, L10n.language)),
        DayAlertKind.suiPo => l.alertSuiPo,
        DayAlertKind.yuePo => l.alertYuePo,
        DayAlertKind.siLi => l.alertSiLi,
        DayAlertKind.siJue => l.alertSiJue,
      };

  static String kindBody(AppLocalizations l, DayAlertKind k, DayAlerts a) => switch (k) {
        DayAlertKind.termChange => l.alertTermBody(_hm(a.term!.startUtc), QimenTerms.solarTerm(a.term!.index, L10n.language)),
        DayAlertKind.suiPo => l.alertSuiPoBody,
        DayAlertKind.yuePo => l.alertYuePoBody,
        DayAlertKind.siLi => l.alertSiLiBody,
        DayAlertKind.siJue => l.alertSiJueBody,
      };

  static String _hm(DateTime t) {
    final x = t.toLocal();
    return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }

  /// 生年與 [a] 日支相沖的人（自己用 [meName]）。
  static Future<List<String>> clashNames(AppLocalizations l, DayAlerts a) async {
    final s = AppSettings.instance;
    final me = await Profile.load();
    final family = await FamilyStore.load();
    bool hit(DateTime birth) => a.clashes(BirthInfo.fromInstant(birth, settings: s.timeSettingsAt(birth)).year);
    return [
      if (me != null && hit(me.birthInstant)) l.familyMe,
      for (final m in family)
        if (hit(m.birthInstant)) m.name,
    ];
  }

  /// [a] 這一天的提醒內文（每項一行）；沒有任何重要日時為空。
  static Future<List<String>> lines(AppLocalizations l, DayAlerts a, {required bool withClash}) async {
    final names = withClash ? await clashNames(l, a) : const <String>[];
    return [
      for (final k in a.kinds) kindBody(l, k, a),
      if (names.isNotEmpty) l.alertClashBody(names.join(l.listJoiner)),
    ];
  }

  static Future<void> reschedule() async {
    await Notifications.cancelRange(idFrom, idTo);
    if (!await enabled() || !await Notifications.enabled()) return;
    final at = await time();
    final l = L10n.current;
    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final eve = DateTime(now.year, now.month, now.day + i, at.hour, at.minute);
      if (!eve.isAfter(now)) continue;
      final target = DateTime(now.year, now.month, now.day + i + 1);
      final a = DayAlerts.of(target, settings: AppSettings.instance.timeSettingsAt(target));
      final body = await lines(l, a, withClash: clashEnabled);
      if (body.isEmpty) continue;
      final short = [for (final k in a.kinds) kindShort(l, k, a)];
      await Notifications.schedule(
        id: idFrom + i,
        title: l.alertNotifyTitle(short.isEmpty ? l.alertClashShort : short.join(l.listJoiner)),
        body: body.join('\n'),
        atUtc: eve.toUtc(),
        channelId: channelId,
        channelName: l.alertChannel,
      );
    }
  }
}

/// 設定頁對話框：開關＋時間。
Future<void> showDayAlertDialog(BuildContext context) async {
  final l = context.l10n;
  var on = await DayAlertReminder.enabled();
  var at = await DayAlertReminder.time();
  if (!context.mounted) return;
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.alertTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.alertOn),
            subtitle: Text(l.alertHint),
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
  await DayAlertReminder.set(on: on, at: at);
}
