/// 地圖八門的地理計算（純 Dart，可單元測試）：真北方位角、距離、扇形頂點。
library;

import 'dart:math' as math;

const _earthR = 6371008.8; // 公尺

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// 從 (lat1, lon1) 往 (lat2, lon2) 的起始方位角（真北＝0，順時針，0–360）。
double bearingTo(double lat1, double lon1, double lat2, double lon2) {
  final p1 = _rad(lat1), p2 = _rad(lat2), dl = _rad(lon2 - lon1);
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// 大圓距離（公尺）。
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  final p1 = _rad(lat1), p2 = _rad(lat2);
  final dp = p2 - p1, dl = _rad(lon2 - lon1);
  final a = math.pow(math.sin(dp / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
  return 2 * _earthR * math.asin(math.min(1, math.sqrt(a.toDouble())));
}

/// 從起點沿方位角 [bearing] 走 [meters] 公尺的終點 (lat, lon)。
(double, double) destinationPoint(double lat, double lon, double bearing, double meters) {
  final d = meters / _earthR, b = _rad(bearing), p1 = _rad(lat), l1 = _rad(lon);
  final p2 = math.asin(math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(b));
  final l2 = l1 + math.atan2(math.sin(b) * math.sin(d) * math.cos(p1), math.cos(d) - math.sin(p1) * math.sin(p2));
  return (_deg(p2), (_deg(l2) + 540) % 360 - 180);
}

/// 以 (lat, lon) 為中心、方位 [center]±22.5° 的扇形頂點（含中心點），[steps] 段弧線。
List<(double, double)> sectorPoints(double lat, double lon, double center, double radius, {int steps = 12}) => [
      (lat, lon),
      for (var i = 0; i <= steps; i++) destinationPoint(lat, lon, center - 22.5 + 45 * i / steps, radius),
    ];
