import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../compass/compass_math.dart';

/// 宅盤用的方位來源：沿用羅盤的磁場監測與室內鎖定（[MagneticMonitor]、[GyroLock]）。
/// 宅盤功能內共用一份（[instance]），在門口鎖定後走進屋內各頁仍維持鎖定；
/// 用 [acquire]／[release] 計數，全部頁面離開後停止感測器並解除鎖定。
class HeadingTracker extends ChangeNotifier {
  HeadingTracker._();

  static final instance = HeadingTracker._();

  final field = MagneticMonitor();
  final _gyro = GyroLock();
  final _subs = <StreamSubscription<dynamic>>[];
  int _users = 0;
  Timer? _tick;

  double? _mag;
  bool noSensor = false;
  double tilt = 0;
  DateTime? lockedAt;

  bool get locked => _gyro.locked;

  /// 目前方位角（磁北）；鎖定時改用陀螺儀累計。
  double? get heading => _gyro.locked ? _gyro.heading : _mag;

  /// 未鎖定且磁場不正常時要提醒。
  bool get disturbed => !locked && (field.status == FieldStatus.outOfRange || field.status == FieldStatus.unstable);

  void acquire() {
    if (_users++ > 0) return;
    final compass = FlutterCompass.events;
    if (compass == null) {
      noSensor = true;
    } else {
      _subs.add(compass.listen((e) {
        final h = e.heading;
        if (h == null) {
          noSensor = true;
          return;
        }
        noSensor = false;
        _mag = smoothHeading(_mag, h);
      }, onError: (_) => noSensor = true));
    }
    _subs.add(magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) => field.add(e.x, e.y, e.z), onError: (_) {}));
    _subs.add(gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen((e) => _gyro.update(e.z, DateTime.now()), onError: (_) {}));
    _subs.add(accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) => tilt = tiltDegrees(e.x, e.y, e.z), onError: (_) {}));
    // 畫面更新限制在每秒約 15 次。
    _tick = Timer.periodic(const Duration(milliseconds: 66), (_) => notifyListeners());
  }

  void release() {
    if (_users == 0 || --_users > 0) return;
    _tick?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _gyro.unlock();
    lockedAt = null;
    _mag = null;
  }

  void lock() {
    final h = _mag;
    if (h == null) return;
    _gyro.lock(h);
    lockedAt = DateTime.now();
    notifyListeners();
  }

  void unlock() {
    _gyro.unlock();
    lockedAt = null;
    notifyListeners();
  }
}
