/// 奇門羅盤的純計算（不依賴 Flutter，可單元測試）：方位↔宮位、轉向角、磁場品質、下一個時辰。
library;

import 'dart:math' as math;

import '../engine/engine.dart';

/// 後天八卦各宮中心方位角（度，正北 0、順時針）：坎北、艮東北、震東、巽東南、離南、坤西南、兌西、乾西北。
const Map<int, double> palaceBearing = {
  1: 0, 8: 45, 3: 90, 4: 135, 9: 180, 2: 225, 7: 270, 6: 315, //
};

/// 角度正規化到 [0, 360)。
double normalizeDeg(double d) {
  final r = d % 360;
  return r < 0 ? r + 360 : r;
}

/// 從 [from] 轉到 [to] 的最短角度，範圍 (-180, 180]；正值＝向右（順時針）轉。
double turnDelta(double from, double to) {
  final d = normalizeDeg(to - from);
  return d > 180 ? d - 360 : d;
}

/// 方位角落在哪一宮（每宮 45°，以中心方位 ±22.5°）。
int palaceAtBearing(double bearing) {
  final i = (normalizeDeg(bearing + 22.5) ~/ 45) % 8;
  return const [1, 8, 3, 4, 9, 2, 7, 6][i];
}

/// 盤上某門的方位角。
double doorBearing(QimenChart chart, Door door) => palaceBearing[chart.palaceOfDoor(door)]!;

/// 某方位角上的門（中五宮沒有門，外八宮一定有）。
Door doorAtBearing(QimenChart chart, double bearing) => chart[palaceAtBearing(bearing)].door!;

/// 環形低通濾波：處理 359°→0° 的跳動。[alpha] 越大越跟手。
double smoothHeading(double? previous, double next, {double alpha = 0.25}) {
  if (previous == null) return normalizeDeg(next);
  return normalizeDeg(previous + turnDelta(previous, next) * alpha);
}

/// 精度等級。
enum CompassAccuracy { high, medium, low, unknown }

/// 由感測器回報的誤差角（度）換算精度等級。
CompassAccuracy accuracyFromDegrees(double? deg) {
  if (deg == null || deg.isNaN || deg < 0) return CompassAccuracy.unknown;
  if (deg <= 15) return CompassAccuracy.high;
  if (deg <= 30) return CompassAccuracy.medium;
  return CompassAccuracy.low;
}

/// 磁場狀態。
enum FieldStatus { ok, outOfRange, unstable, unknown }

/// 磁力計監測：地磁正常範圍 25–65 μT；最近一段樣本的標準差過大視為抖動（附近有金屬或家電）。
class MagneticMonitor {
  MagneticMonitor({this.window = 25, this.min = 25, this.max = 65, this.maxStdDev = 4});

  final int window;
  final double min, max, maxStdDev;
  final List<double> _samples = [];

  /// 最近一筆磁場強度（μT）。
  double? get strength => _samples.isEmpty ? null : _samples.last;

  void add(double x, double y, double z) {
    _samples.add(math.sqrt(x * x + y * y + z * z));
    if (_samples.length > window) _samples.removeAt(0);
  }

  double get stdDev {
    if (_samples.length < 2) return 0;
    final mean = _samples.reduce((a, b) => a + b) / _samples.length;
    final v = _samples.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) / _samples.length;
    return math.sqrt(v);
  }

  FieldStatus get status {
    if (_samples.length < 5) return FieldStatus.unknown;
    final s = _samples.last;
    if (s < min || s > max) return FieldStatus.outOfRange;
    if (stdDev > maxStdDev) return FieldStatus.unstable;
    return FieldStatus.ok;
  }
}

/// 手機傾斜角（度）：0＝平放螢幕朝上。由加速度計 (x, y, z) 算出。
double tiltDegrees(double x, double y, double z) {
  final g = math.sqrt(x * x + y * y + z * z);
  if (g == 0) return 0;
  return math.acos((z / g).clamp(-1.0, 1.0)) * 180 / math.pi;
}

/// 盤的身分：時柱與局數相同就是同一張盤。
String chartKey(QimenChart c) => '${c.hour.index}/${c.dun.index}/${c.ju}';

/// 找出 [now] 之後盤面第一次改變的時刻（換時辰，或節氣交界造成換局）。
/// 先以 [step] 粗掃 [horizon]，再對第一個變動區間二分到秒。找不到回傳 null。
DateTime? nextChartChange(
  DateTime now,
  QimenChart Function(DateTime) compute, {
  Duration step = const Duration(minutes: 5),
  Duration horizon = const Duration(hours: 2, minutes: 5),
}) {
  final key = chartKey(compute(now));
  var lo = now;
  DateTime? hi;
  for (var t = now.add(step); !t.isAfter(now.add(horizon)); t = t.add(step)) {
    if (chartKey(compute(t)) != key) {
      hi = t;
      break;
    }
    lo = t;
  }
  if (hi == null) return null;
  // 以整秒二分：lo 同一張盤、hi 已換盤。
  var loS = lo.millisecondsSinceEpoch ~/ 1000;
  var hiS = (hi.millisecondsSinceEpoch + 999) ~/ 1000;
  DateTime at(int s) => DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: now.isUtc);
  while (hiS - loS > 1) {
    final mid = (loS + hiS) ~/ 2;
    if (chartKey(compute(at(mid))) == key) {
      loS = mid;
    } else {
      hiS = mid;
    }
  }
  return at(hiS);
}

/// 室內鎖定：在干擾少的地方（門口、陽台）鎖定方位後，改用陀螺儀累計轉動角，
/// 不再受室內金屬、家電影響。手機平放時，繞 z 軸逆時針轉（俯視）為正。
class GyroLock {
  double? _heading;
  DateTime? _last;

  bool get locked => _heading != null;
  double? get heading => _heading;

  void lock(double heading) {
    _heading = normalizeDeg(heading);
    _last = null;
  }

  void unlock() {
    _heading = null;
    _last = null;
  }

  /// [wz] 為陀螺儀 z 軸角速度（rad/s）；[at] 為樣本時間。
  void update(double wz, DateTime at) {
    final h = _heading;
    if (h == null) return;
    final last = _last;
    _last = at;
    if (last == null) return;
    final dt = at.difference(last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.5) return; // 樣本中斷時不累計，避免暴衝
    _heading = normalizeDeg(h - wz * dt * 180 / math.pi);
  }
}
