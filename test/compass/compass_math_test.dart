import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/compass/compass_math.dart';
import 'package:qimen_compass/compass/declination.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  test('方位角對應後天八卦宮位', () {
    expect(palaceAtBearing(0), 1);
    expect(palaceAtBearing(359), 1);
    expect(palaceAtBearing(22.4), 1);
    expect(palaceAtBearing(22.6), 8);
    expect(palaceAtBearing(90), 3);
    expect(palaceAtBearing(135), 4);
    expect(palaceAtBearing(180), 9);
    expect(palaceAtBearing(225), 2);
    expect(palaceAtBearing(270), 7);
    expect(palaceAtBearing(315), 6);
    expect(palaceAtBearing(-45), 6);
    for (final e in palaceBearing.entries) {
      expect(palaceAtBearing(e.value), e.key);
    }
  });

  test('轉向角取最短方向', () {
    expect(turnDelta(350, 10), 20);
    expect(turnDelta(10, 350), -20);
    expect(turnDelta(0, 180), 180);
    expect(turnDelta(90, 45), -45);
  });

  test('方位平滑跨越 0°', () {
    final h = smoothHeading(350, 10, alpha: 0.5);
    expect(h, closeTo(0, 1e-9));
  });

  test('磁場監測', () {
    final m = MagneticMonitor();
    expect(m.status, FieldStatus.unknown);
    for (var i = 0; i < 10; i++) {
      m.add(20, 30, -30); // ≈ 46.9 μT
    }
    expect(m.status, FieldStatus.ok);
    for (var i = 0; i < 30; i++) {
      m.add(100, 0, 0);
    }
    expect(m.status, FieldStatus.outOfRange);
    final u = MagneticMonitor();
    for (var i = 0; i < 20; i++) {
      u.add(i.isEven ? 30 : 60, 0, 0);
    }
    expect(u.status, FieldStatus.unstable);
  });

  test('精度等級與傾斜角', () {
    expect(accuracyFromDegrees(null), CompassAccuracy.unknown);
    expect(accuracyFromDegrees(10), CompassAccuracy.high);
    expect(accuracyFromDegrees(20), CompassAccuracy.medium);
    expect(accuracyFromDegrees(45), CompassAccuracy.low);
    expect(tiltDegrees(0, 0, 9.8), closeTo(0, 1e-9));
    expect(tiltDegrees(9.8, 0, 0), closeTo(90, 1e-9));
  });

  test('八門方位：每門落在外八宮，前方門與方位一致', () {
    const engine = ShiJiaEngine();
    final chart = engine.compute(DateTime.utc(2026, 3, 10, 2, 20));
    final seen = <int>{};
    for (final d in Door.values) {
      final b = doorBearing(chart, d);
      expect(doorAtBearing(chart, b), d);
      seen.add(palaceAtBearing(b));
    }
    expect(seen.length, 8);
  });

  test('下個時辰：在奇數整點換盤', () {
    const engine = ShiJiaEngine();
    QimenChart at(DateTime t) => engine.compute(t); // 預設 UTC+8
    // 北京時間 2026-03-10 10:20 → 11:00（午時）換盤
    final now = DateTime.utc(2026, 3, 10, 2, 20);
    final next = nextChartChange(now, at);
    expect(next, DateTime.utc(2026, 3, 10, 3));
    expect(chartKey(at(next!)), isNot(chartKey(at(now))));
    expect(chartKey(at(next.subtract(const Duration(seconds: 1)))), chartKey(at(now)));
  });

  test('磁偏角（WMM 2025）：台北約西偏 4–5°', () {
    final d = Declination.at(25.03, 121.56, DateTime.utc(2026, 11, 17));
    expect(d, inInclusiveRange(-6.0, -3.0));
  });
}
