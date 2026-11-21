import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/compass/building_facing.dart';

void main() {
  test('牆向正規化到 [0, 180)', () {
    expect(wallAxis(200), closeTo(20, 1e-9));
    expect(wallAxis(-10), closeTo(170, 1e-9));
    expect(wallAxis(180), closeTo(0, 1e-9));
  });

  test('對牆取最接近的 90° 牆向', () {
    expect(snapToWall(40, 30), closeTo(30, 1e-9));
    expect(snapToWall(100, 30), closeTo(120, 1e-9));
    expect(snapToWall(250, 30), closeTo(210, 1e-9));
    expect(snapToWall(355, 30), closeTo(30, 1e-9)); // 30 距 35°、300 距 55°
  });

  test('跨 0° 的對牆', () {
    expect(snapToWall(350, 5), closeTo(5, 1e-9));
    expect(snapToWall(10, 85), closeTo(355, 1e-9));
  });

  test('地圖兩點算牆向（正東西向的牆＝90°）', () {
    expect(wallBearingOf(25, 121, 25, 121.001), closeTo(90, 0.01));
    expect(wallBearingOf(25, 121.001, 25, 121), closeTo(90, 0.01));
  });
}
