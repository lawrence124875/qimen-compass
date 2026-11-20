import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/ymd_date_picker.dart';

/// 個人資料（HANDOFF §12 P4）：出生日期（與擇時共用 `qm_birth_date`）＋出生時間（選填，`qm_birth_time` 分鐘數）。
class Profile {
  const Profile({required this.birthDate, this.birthMinutes});

  final DateTime birthDate;

  /// 出生時間（當天第幾分鐘）；null＝不知道。
  final int? birthMinutes;

  /// 起本命盤用的時刻：不知道時間時取當天 12:00。
  DateTime get birthInstant => DateTime(birthDate.year, birthDate.month, birthDate.day, 0, birthMinutes ?? 12 * 60);

  static const _kDate = 'qm_birth_date';
  static const _kTime = 'qm_birth_time';

  static Future<Profile?> load() async {
    final p = await SharedPreferences.getInstance();
    final d = DateTime.tryParse(p.getString(_kDate) ?? '');
    if (d == null) return null;
    final m = p.getInt(_kTime);
    return Profile(birthDate: d, birthMinutes: m);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    final d = birthDate;
    await p.setString(_kDate, '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    if (birthMinutes == null) {
      await p.remove(_kTime);
    } else {
      await p.setInt(_kTime, birthMinutes!);
    }
  }
}

/// 設定出生日期與時間；存檔後回傳新的 [Profile]。
Future<Profile?> editProfile(BuildContext context, Profile? current) async {
  final l = context.l10n;
  final d = await showYmdDatePicker(
    context: context,
    helpText: l.profileBirthDate,
    initialDate: current?.birthDate ?? DateTime(1990, 1, 1),
    firstDate: DateTime(1920),
    lastDate: DateTime.now(),
  );
  if (d == null || !context.mounted) return null;
  final m0 = current?.birthMinutes;
  final t = await showTimePicker(
    context: context,
    helpText: l.profileBirthTime,
    cancelText: l.profileTimeUnknown,
    initialTime: m0 == null ? const TimeOfDay(hour: 12, minute: 0) : TimeOfDay(hour: m0 ~/ 60, minute: m0 % 60),
    initialEntryMode: TimePickerEntryMode.input,
  );
  final p = Profile(birthDate: d, birthMinutes: t == null ? null : t.hour * 60 + t.minute);
  await p.save();
  return p;
}
