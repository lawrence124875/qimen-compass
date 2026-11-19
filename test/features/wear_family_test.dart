import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/features/family/family_store.dart';
import 'package:qimen_compass/features/wear/wear_sync.dart';
import 'package:qimen_compass/l10n/l10n.dart';

void main() {
  test('手錶資料：36 個時辰、每個 8 宮、時間連續', () {
    final l = lookupAppLocalizations(const Locale('zh'));
    final d = WearSync.build(l, DateTime.utc(2026, 11, 20, 2), locked: false);
    final slots = d['slots']! as List;
    expect(slots, hasLength(36));
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i] as Map;
      expect((s['p'] as List), hasLength(8));
      if (i > 0) expect(s['s'], (slots[i - 1] as Map)['e']);
    }
    expect((d['doors']! as List), hasLength(8));
    expect((d['dirs']! as List), hasLength(8));
    expect(WearSync.build(l, DateTime.utc(2026, 11, 20), locked: true)['slots'], isEmpty);
  });

  test('家人 JSON 來回', () {
    final m = FamilyMember(id: '1', name: '小明', birthDate: DateTime(1988, 2, 4), birthMinutes: 600);
    final back = FamilyMember.fromJson(m.toJson())!;
    expect(back.name, '小明');
    expect(back.birthDate, DateTime(1988, 2, 4));
    expect(back.birthMinutes, 600);
    expect(FamilyMember.fromJson({'name': '', 'birth': '2000-01-01'}), isNull);
  });
}
