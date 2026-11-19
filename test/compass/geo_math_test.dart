import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/compass/compass_math.dart';
import 'package:qimen_compass/compass/geo_math.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  test('方位角與距離', () {
    // 台北車站 → 台北 101：東南偏東、約 4.6 km
    final b = bearingTo(25.0478, 121.5170, 25.0340, 121.5645);
    expect(b, closeTo(108, 3));
    expect(palaceAtBearing(b), 3); // 震宮（東）
    expect(distanceMeters(25.0478, 121.5170, 25.0340, 121.5645), closeTo(5000, 400));
    expect(bearingTo(0, 0, 1, 0), closeTo(0, 1e-6));
    expect(bearingTo(0, 0, 0, -1), closeTo(270, 1e-6));
  });

  test('終點與扇形', () {
    final (lat, lon) = destinationPoint(25, 121, 90, 1000);
    expect(distanceMeters(25, 121, lat, lon), closeTo(1000, 1));
    expect(bearingTo(25, 121, lat, lon), closeTo(90, 0.1));
    final pts = sectorPoints(25, 121, 0, 3000);
    expect(pts.length, 14);
    expect(bearingTo(25, 121, pts[1].$1, pts[1].$2), closeTo(337.5, 0.1));
  });

  test('方位吉凶：每宮都有分數，時辰連續', () {
    final now = DateTime.utc(2026, 11, 19, 4);
    final list = const DirectionPlanner().plan(now, 9, settings: const TimeSettings(utcOffset: Duration(hours: 8)));
    expect(list.length, 12);
    for (var i = 1; i < list.length; i++) {
      expect(list[i].startUtc, list[i - 1].endUtc);
    }
    final chart = const ShiJiaEngine().compute(now, settings: const TimeSettings(utcOffset: Duration(hours: 8)));
    for (final p in palaceBearing.keys) {
      final v = DirectionPlanner.judge(chart, p);
      expect(v.door, isNotNull);
      expect(v.recommended, v.score >= 4);
    }
  });
}
