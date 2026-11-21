import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../compass/building_facing.dart';
import '../../compass/compass_intro.dart';
import '../../compass/compass_math.dart';
import '../../compass/declination.dart';
import 'house_model.dart';

/// 對牆結果。
enum WallAlign { ok, notFlat, notStill, noBuilding }

/// 宅盤用的方位來源：沿用羅盤的磁場監測與室內鎖定（[MagneticMonitor]、[GyroLock]），
/// 北方基準與羅盤共用（真北／磁北／建築座向，見 [BuildingStore]）；建築座向用目前這間房子綁定的地點。
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
  double _gyroRate = 0;
  DateTime? lockedAt;

  NorthMode mode = NorthMode.trueNorth;
  bool _magBasis = false; // 建築座向輸出磁北
  double? _decl;
  String? houseId;

  /// 目前這間房子綁定的建築座向地點。
  BuildingFacing? building;

  /// 最近一次對牆的時間（建築座向）。
  DateTime? wallAt;

  bool get locked => _gyro.locked;

  /// 目前顯示的是否為磁北。
  bool get showsMagnetic => switch (mode) {
        NorthMode.magnetic => true,
        NorthMode.trueNorth => _decl == null,
        NorthMode.building => _magBasis && _decl != null,
      };

  /// 未鎖定時的方向（真北模式加磁偏角）。
  double? get _unlocked {
    final h = _mag;
    if (h == null) return null;
    return mode == NorthMode.magnetic || _decl == null ? h : normalizeDeg(h + _decl!);
  }

  /// 目前方位角（依北方基準）；鎖定或對牆後改用陀螺儀累計。
  double? get heading {
    if (mode == NorthMode.building) {
      // 陀螺儀以真北為準；輸出磁北時扣磁偏角
      final t = _gyro.locked ? _gyro.heading : (_mag == null ? null : normalizeDeg(_mag! + (_decl ?? 0)));
      if (t == null) return null;
      return showsMagnetic ? normalizeDeg(t - _decl!) : t;
    }
    return _gyro.locked ? _gyro.heading : _unlocked;
  }

  /// 未鎖定且磁場不正常時要提醒。
  bool get disturbed => !locked && (field.status == FieldStatus.outOfRange || field.status == FieldStatus.unstable);

  void acquire() {
    reloadSettings();
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
        final m = e.magneticField; // iOS：已校正磁場
        if (m != null) field.addStrength(m);
      }, onError: (_) => noSensor = true));
    }
    // iOS 的 sensors_plus 磁力計是未校正原始值（含機身與 MagSafe 偏差，常達數百 μT），不能拿來判斷干擾；
    // iOS 改用羅盤事件附帶的已校正磁場（CompassEvent.magneticField）。
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      _subs.add(magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval)
          .listen((e) => field.add(e.x, e.y, e.z), onError: (_) {}));
    }
    _subs.add(gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
      _gyro.update(e.z, DateTime.now());
      _gyroRate = _gyroRate * 0.8 + math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z) * 0.2;
    }, onError: (_) {}));
    _subs.add(accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) => tilt = tiltDegrees(e.x, e.y, e.z), onError: (_) {}));
    // 畫面更新限制在每秒約 15 次。
    _tick = Timer.periodic(const Duration(milliseconds: 66), (_) => notifyListeners());
  }

  /// 重新讀取北方基準、磁偏角與目前房子綁定的建築座向（羅盤改了設定、換房子後呼叫）。
  Future<void> reloadSettings() async {
    final p = await CompassPrefs.load();
    final m = await BuildingStore.mode(p.trueNorth);
    final magBasis = await BuildingStore.magneticBasis();
    final house = await HouseStore.load();
    final bid = await BuildingStore.buildingOfHouse(house.id);
    final list = await BuildingStore.load();
    final b = list.where((x) => x.id == bid).firstOrNull;
    if (p.fieldUt != null) field.setExpected(p.fieldUt!); // 當地地磁強度（羅盤開真北時存的）
    var decl = p.declination;
    if (b?.lat != null && b?.lon != null) {
      decl = Declination.at(b!.lat!, b.lon!); // 建築座向：以房子座標算磁偏角
      field.setExpected(Declination.fieldAt(b.lat!, b.lon!));
    }
    final changed = m != mode || b?.id != building?.id || b?.wall != building?.wall || house.id != houseId;
    mode = m;
    _magBasis = magBasis;
    _decl = decl;
    houseId = house.id;
    building = b;
    if (changed) {
      _gyro.unlock();
      lockedAt = null;
      wallAt = null;
    }
    notifyListeners();
  }

  /// 把目前這間房子綁定到某個建築座向地點。
  Future<void> bindBuilding(BuildingFacing b) async {
    final id = houseId ?? (await HouseStore.load()).id;
    await BuildingStore.bindHouse(id, b.id);
    await reloadSettings();
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
    wallAt = null;
    _mag = null;
  }

  void lock() {
    final h = _unlocked;
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

  /// 對牆：手機平放、長邊貼牆，取最接近的牆向後改用陀螺儀（以真北為準）。
  /// 回傳 ok 時，[alignOffset] 為和指南針的差（磁場正常時才有，供提醒）。
  WallAlign alignWall() {
    final b = building;
    if (b == null) return WallAlign.noBuilding;
    if (tilt > 12) return WallAlign.notFlat;
    if (_gyroRate > 0.15) return WallAlign.notStill;
    final est = _gyro.locked ? _gyro.heading! : (_mag == null ? b.wall : normalizeDeg(_mag! + (_decl ?? 0)));
    final snapped = snapToWall(est, b.wall);
    _gyro.lock(snapped);
    wallAt = DateTime.now();
    final m = _mag;
    alignOffset = field.status == FieldStatus.ok && m != null ? turnDelta(normalizeDeg(m + (_decl ?? 0)), snapped).abs() : null;
    notifyListeners();
    return WallAlign.ok;
  }

  double? alignOffset;

  void rotate90(int dir) {
    final h = _gyro.heading;
    if (h == null) return;
    _gyro.lock(h + 90.0 * dir);
    notifyListeners();
  }
}
