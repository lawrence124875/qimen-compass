import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../compass/compass_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import '../travel/travel_text.dart';
import 'house_model.dart';

/// 大門吉時（居家心法「大門不佳就擇時出入」）：大門方位在接下來兩天逢開休生門、方位吉以上的時辰。
/// 大門＝標記名稱為「大門」的房間（各語預設清單第一項），沒有時坐向用大門法就取向的方位。
/// 推播：id 1320–1325，時辰開始前 15 分鐘；開關 `qm_door_hours_on`，App 啟動與宅盤變動時重排。
class DoorHours {
  DoorHours._();

  static const idFrom = 1320, idTo = 1325;
  static const channelId = 'qm_door_hours';
  static const _kOn = 'qm_door_hours_on';

  /// 大門所在宮；找不到回傳 null。
  static int? doorPalace(House h, AppLocalizations l) {
    final names = {
      for (final s in [l.houseRoomPresets, l.houseOfficePresets, l.houseShopPresets]) s.split(',').first.trim(),
    };
    final rooms = h.roomsByPalace();
    for (final e in rooms.entries) {
      if (e.key != 5 && e.value.any((n) => names.contains(n.trim()))) return e.key;
    }
    final f = h.facing;
    if (f != null && (h.sittingMethod == SittingMethod.door || h.sittingMethod == SittingMethod.groundDoor)) {
      return palaceAtBearing(f);
    }
    return null;
  }

  static List<DirectionVerdict> upcoming(int palace, {int slots = 24}) {
    final s = AppSettings.instance;
    final now = DateTime.now();
    return doorLuckyHours(palace, now.toUtc(), slots: slots, settings: s.timeSettingsAt(now), method: s.juMethod);
  }

  static Future<bool> isOn() async => (await SharedPreferences.getInstance()).getBool(_kOn) ?? false;

  static Future<void> setOn(bool v) async {
    await (await SharedPreferences.getInstance()).setBool(_kOn, v);
    await reschedule();
  }

  static String range(DirectionVerdict v) {
    String two(int n) => n.toString().padLeft(2, '0');
    final a = v.startUtc!.toLocal();
    final b = v.endUtc!.toLocal();
    return '${a.month}/${a.day} ${two(a.hour)}:${two(a.minute)}–${two(b.hour)}:${two(b.minute)}';
  }

  static Future<void> reschedule() async {
    await Notifications.cancelRange(idFrom, idTo);
    if (!await isOn() || !await Notifications.enabled()) return;
    if ((await HouseStore.all()).isEmpty) return;
    final house = await HouseStore.load();
    final l = L10n.current;
    final p = doorPalace(house, l);
    if (p == null) return;
    final now = DateTime.now().toUtc();
    var id = idFrom;
    for (final v in upcoming(p)) {
      final at = v.startUtc!.subtract(const Duration(minutes: 15));
      if (!at.isAfter(now)) continue;
      await Notifications.schedule(
        id: id++,
        title: l.doorHoursNotifyTitle,
        body: l.doorHoursNotifyBody(range(v), QimenTerms.doorName(v.door!, L10n.language), TravelText.direction(l, p)),
        atUtc: at,
        channelId: channelId,
        channelName: l.doorHoursTitle,
      );
      if (id > idTo) break;
    }
  }
}

/// 宅盤內的「大門吉時」卡片。
class DoorHoursCard extends StatefulWidget {
  const DoorHoursCard({super.key, required this.house});

  final House house;

  @override
  State<DoorHoursCard> createState() => _DoorHoursCardState();
}

class _DoorHoursCardState extends State<DoorHoursCard> {
  bool? _on;

  @override
  void initState() {
    super.initState();
    DoorHours.isOn().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  Future<void> _toggle(bool v) async {
    if (v && !await Notifications.requestPermission()) return;
    await DoorHours.setOn(v);
    if (mounted) setState(() => _on = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final p = DoorHours.doorPalace(widget.house, l);
    final slots = p == null ? const <DirectionVerdict>[] : DoorHours.upcoming(p);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.door_front_door_outlined, color: qm.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l.doorHoursTitle, style: text.titleMedium)),
            if (p != null) Text(TravelText.direction(l, p), style: text.bodySmall?.copyWith(color: qm.textMuted)),
          ]),
          const SizedBox(height: 4),
          Text(l.doorHoursIntro, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          const SizedBox(height: 6),
          if (p == null)
            Text(l.doorHoursNoDoor, style: text.bodyMedium)
          else if (slots.isEmpty)
            Text(l.doorHoursNone, style: text.bodyMedium)
          else
            for (final v in slots.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${DoorHours.range(v)}  ${QimenTerms.doorName(v.door!, L10n.language)}・${TravelText.level(l, v.level)}',
                  style: text.bodyMedium?.copyWith(color: qm.good),
                ),
              ),
          if (p != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l.doorHoursRemind),
              value: _on ?? false,
              onChanged: _on == null ? null : _toggle,
            ),
        ]),
      ),
    );
  }
}
