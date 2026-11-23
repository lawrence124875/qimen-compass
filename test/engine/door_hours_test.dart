import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  test('門宮五行關係', () {
    expect(DoorPalaceRelation.of(Door.kai, 3), DoorPalaceRelation.menPo); // 金剋木
    expect(DoorPalaceRelation.of(Door.kai, 2), DoorPalaceRelation.palaceGen); // 土生金
    expect(DoorPalaceRelation.of(Door.kai, 1), DoorPalaceRelation.doorGen); // 金生水
    expect(DoorPalaceRelation.of(Door.kai, 6), DoorPalaceRelation.same);
    expect(DoorPalaceRelation.of(Door.kai, 9), DoorPalaceRelation.palaceKe); // 火剋金
    expect(boostElement(Door.xiu), Element.metal);
  });

  test('大門吉時只列開休生且方位吉以上，時辰遞增', () {
    final from = DateTime.utc(2026, 11, 23, 0);
    for (final p in palaceRing) {
      final hs = doorLuckyHours(p, from);
      for (final v in hs) {
        expect(v.door!.luck, Luck.good);
        expect(v.recommended, isTrue);
        expect(v.endUtc!.difference(v.startUtc!), const Duration(hours: 2));
      }
      for (var i = 1; i < hs.length; i++) {
        expect(hs[i].startUtc!.isAfter(hs[i - 1].startUtc!), isTrue);
      }
    }
    expect([for (final p in palaceRing) ...doorLuckyHours(p, from)], isNotEmpty);
  });
}
