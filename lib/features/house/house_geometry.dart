/// 宅盤九宮的幾何計算（純計算，可單元測試）：平面圖座標↔方位、宮位、重心、透視校正。
///
/// 平面圖座標：x 向右、y 向下（與螢幕相同），單位任意；「圖的上方」在現實中的方位角為 upBearing。
library;

import 'dart:math' as math;
import 'dart:ui';

import '../../compass/compass_math.dart';

/// 平面上一點相對 [center] 的現實方位角（度，正北 0、順時針）。
double bearingInPlan(Offset center, Offset p, double upBearing) {
  final d = p - center;
  final a = math.atan2(d.dx, -d.dy) * 180 / math.pi; // 從圖上方順時針
  return normalizeDeg(upBearing + a);
}

/// 現實方位角在平面圖上的單位向量。
Offset planDirection(double bearing, double upBearing) {
  final a = (bearing - upBearing) * math.pi / 180;
  return Offset(math.sin(a), -math.cos(a));
}

/// 中宮半徑：取平面圖等面積正方形邊長的 1/6（九宮格中格的內切圓）。
double centerRadius(double area) => math.sqrt(area) / 6;

/// 平面上一點所在的宮（離中心太近算中五宮）。
int palaceAtPoint(Offset center, Offset p, double upBearing, {required double centerR}) {
  if ((p - center).distance <= centerR) return 5;
  return palaceAtBearing(bearingInPlan(center, p, upBearing));
}

/// 房間（長方形）所在的宮：包含中心點的房間算中五宮，否則看房間中心的方位。
int palaceOfRect(Offset center, Rect r, double upBearing, {required double centerR}) {
  if (r.contains(center)) return 5;
  return palaceAtPoint(center, r.center, upBearing, centerR: centerR);
}

/// 從 [from] 沿 [dir]（單位向量）到矩形 [bounds] 邊界的距離；起點在外面時回傳 0。
double rayToBounds(Offset from, Offset dir, Rect bounds) {
  if (!bounds.contains(from)) return 0;
  var t = double.infinity;
  if (dir.dx > 1e-9) t = math.min(t, (bounds.right - from.dx) / dir.dx);
  if (dir.dx < -1e-9) t = math.min(t, (bounds.left - from.dx) / dir.dx);
  if (dir.dy > 1e-9) t = math.min(t, (bounds.bottom - from.dy) / dir.dy);
  if (dir.dy < -1e-9) t = math.min(t, (bounds.top - from.dy) / dir.dy);
  return t.isFinite ? t : 0;
}

/// 多個長方形（可重疊）聯集的重心。以 [cell] 為格子掃描，長方形邊對齊格子時為精確值。
/// 沒有長方形時回傳 null。
Offset? unionCentroid(List<Rect> rects, {double cell = 0.25}) {
  if (rects.isEmpty) return null;
  final b = rects.reduce((a, r) => a.expandToInclude(r));
  final nx = (b.width / cell).ceil(), ny = (b.height / cell).ceil();
  if (nx * ny > 400000) cell = math.sqrt(b.width * b.height / 400000);
  var sx = 0.0, sy = 0.0, n = 0;
  for (var y = b.top + cell / 2; y < b.bottom; y += cell) {
    for (var x = b.left + cell / 2; x < b.right; x += cell) {
      final p = Offset(x, y);
      if (rects.any((r) => r.contains(p))) {
        sx += x;
        sy += y;
        n++;
      }
    }
  }
  if (n == 0) return b.center;
  return Offset(sx / n, sy / n);
}

/// 聯集面積（同 [unionCentroid] 的格子掃描）。
double unionArea(List<Rect> rects, {double cell = 0.25}) {
  if (rects.isEmpty) return 0;
  final b = rects.reduce((a, r) => a.expandToInclude(r));
  var n = 0;
  for (var y = b.top + cell / 2; y < b.bottom; y += cell) {
    for (var x = b.left + cell / 2; x < b.right; x += cell) {
      if (rects.any((r) => r.contains(Offset(x, y)))) n++;
    }
  }
  return n * cell * cell;
}

/// 透視校正：求 3×3 單應矩陣 H（列優先，h[8]=1），把 [src] 四點對應到 [dst] 四點。
/// 四點順序：左上、右上、右下、左下。三點共線（退化）時回傳 null。
List<double>? homography(List<Offset> src, List<Offset> dst) {
  assert(src.length == 4 && dst.length == 4);
  final a = List.generate(8, (_) => List<double>.filled(9, 0));
  for (var i = 0; i < 4; i++) {
    final u = src[i].dx, v = src[i].dy, x = dst[i].dx, y = dst[i].dy;
    a[2 * i]
      ..[0] = u
      ..[1] = v
      ..[2] = 1
      ..[6] = -u * x
      ..[7] = -v * x
      ..[8] = x;
    a[2 * i + 1]
      ..[3] = u
      ..[4] = v
      ..[5] = 1
      ..[6] = -u * y
      ..[7] = -v * y
      ..[8] = y;
  }
  // 高斯消去（部分選主元）
  for (var c = 0; c < 8; c++) {
    var piv = c;
    for (var r = c + 1; r < 8; r++) {
      if (a[r][c].abs() > a[piv][c].abs()) piv = r;
    }
    if (a[piv][c].abs() < 1e-12) return null;
    final t = a[c];
    a[c] = a[piv];
    a[piv] = t;
    for (var r = 0; r < 8; r++) {
      if (r == c) continue;
      final f = a[r][c] / a[c][c];
      if (f == 0) continue;
      for (var k = c; k < 9; k++) {
        a[r][k] -= f * a[c][k];
      }
    }
  }
  return [for (var i = 0; i < 8; i++) a[i][8] / a[i][i], 1];
}

/// 用單應矩陣轉換一點。
Offset applyHomography(List<double> h, Offset p) {
  final w = h[6] * p.dx + h[7] * p.dy + h[8];
  return Offset((h[0] * p.dx + h[1] * p.dy + h[2]) / w, (h[3] * p.dx + h[4] * p.dy + h[5]) / w);
}

/// 由四角（像素座標）估計校正後的長寬比（寬／高）。
double estimateAspect(List<Offset> c) {
  final w = (c[1] - c[0]).distance + (c[2] - c[3]).distance;
  final h = (c[3] - c[0]).distance + (c[2] - c[1]).distance;
  if (h <= 0) return 1;
  return (w / h).clamp(0.2, 5.0);
}

/// 坐向：向（面朝方位）的對面為坐。
double sittingOf(double facing) => normalizeDeg(facing + 180);
