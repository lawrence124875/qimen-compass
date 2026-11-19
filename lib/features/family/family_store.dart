import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 家人（HANDOFF §12 1.3.0）：稱呼＋出生日期（＋選填時間），存在 `qm_family`（JSON 陣列）。自己用個人資料（Profile）。
class FamilyMember {
  const FamilyMember({required this.id, required this.name, required this.birthDate, this.birthMinutes});

  final String id;
  final String name;
  final DateTime birthDate;

  /// 出生時間（當天第幾分鐘）；null＝不知道。
  final int? birthMinutes;

  /// 起年命用的時刻：不知道時間時取當天 12:00（年命只看年柱，立春當天才有差）。
  DateTime get birthInstant => DateTime(birthDate.year, birthDate.month, birthDate.day, 0, birthMinutes ?? 12 * 60);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'birth': '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        if (birthMinutes != null) 'min': birthMinutes,
      };

  static FamilyMember? fromJson(Object? j) {
    if (j is! Map) return null;
    final d = DateTime.tryParse('${j['birth']}');
    final name = '${j['name'] ?? ''}'.trim();
    if (d == null || name.isEmpty) return null;
    final m = j['min'];
    return FamilyMember(id: '${j['id'] ?? name}', name: name, birthDate: d, birthMinutes: m is int ? m : null);
  }
}

class FamilyStore {
  FamilyStore._();

  static const _key = 'qm_family';

  /// 存檔後 +1（此刻頁、提醒等監聽後重算）。
  static final changed = ValueNotifier<int>(0);

  static Future<List<FamilyMember>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map(FamilyMember.fromJson).whereType<FamilyMember>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<FamilyMember> members) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode([for (final m in members) m.toJson()]));
    changed.value++;
  }
}
