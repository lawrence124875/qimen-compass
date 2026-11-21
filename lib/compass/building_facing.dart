/// 建築座向（第三種北）：大樓的牆向不會變，在衛星地圖上沿外牆畫一次線就永久保存；
/// 室內手機平放、長邊貼牆按「對牆」，取最接近的牆向（每 90° 一個）對齊，之後改用陀螺儀維持。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'compass_math.dart';
import 'geo_math.dart';

/// 羅盤的北方基準。
enum NorthMode { trueNorth, magnetic, building }

/// 一個地點（家、公司…）的牆向。
class BuildingFacing {
  const BuildingFacing({required this.id, required this.name, required this.wall, this.lat, this.lon});

  final String id;
  final String name;

  /// 外牆的方位角（真北＝0，順時針），正規化到 [0, 180)。
  final double wall;
  final double? lat, lon;

  BuildingFacing copyWith({String? name, double? wall, double? lat, double? lon}) =>
      BuildingFacing(id: id, name: name ?? this.name, wall: wall ?? this.wall, lat: lat ?? this.lat, lon: lon ?? this.lon);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'wall': wall, if (lat != null) 'lat': lat, if (lon != null) 'lon': lon};

  static BuildingFacing? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'], wall = j['wall'];
    if (id is! String || name is! String || wall is! num) return null;
    return BuildingFacing(
      id: id,
      name: name,
      wall: wallAxis(wall.toDouble()),
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
    );
  }
}

/// 牆線方向與反方向相同，正規化到 [0, 180)。
double wallAxis(double bearing) {
  final d = normalizeDeg(bearing) % 180;
  return d < 0 ? d + 180 : d;
}

/// 地圖上兩點連成的牆線方位角，[0, 180)。
double wallBearingOf(double lat1, double lon1, double lat2, double lon2) =>
    wallAxis(bearingTo(lat1, lon1, lat2, lon2));

/// 手機貼牆時的朝向：[wall] + k·90° 中最接近 [estimate]（磁力計或陀螺儀的大約方向）的那一個。
double snapToWall(double estimate, double wall) {
  final base = normalizeDeg(wall);
  var best = base;
  var bestD = 999.0;
  for (var k = 0; k < 4; k++) {
    final c = normalizeDeg(base + 90.0 * k);
    final d = turnDelta(estimate, c).abs();
    if (d < bestD) {
      bestD = d;
      best = c;
    }
  }
  return best;
}

/// 對牆多久後提示可能漂移（陀螺儀累計誤差）。
const wallDriftAfter = Duration(minutes: 3);

/// 建築座向與北方基準的保存（SharedPreferences）。
class BuildingStore {
  BuildingStore._();

  static const _kList = 'qm_buildings';
  static const _kSelected = 'qm_building_selected';
  static const _kMode = 'qm_compass_north_mode';

  static Future<SharedPreferences?> _p() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<List<BuildingFacing>> load() async {
    final raw = (await _p())?.getString(_kList);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map(BuildingFacing.fromJson).whereType<BuildingFacing>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<BuildingFacing> list) async =>
      (await _p())?.setString(_kList, jsonEncode([for (final b in list) b.toJson()]));

  static Future<String?> selected() async => (await _p())?.getString(_kSelected);

  static Future<void> select(String? id) async {
    final p = await _p();
    if (id == null) {
      await p?.remove(_kSelected);
    } else {
      await p?.setString(_kSelected, id);
    }
  }

  /// 北方基準；舊版只存真北開關，[legacyTrueNorth] 用來換算。
  static Future<NorthMode> mode(bool legacyTrueNorth) async {
    final s = (await _p())?.getString(_kMode);
    return NorthMode.values.where((m) => m.name == s).firstOrNull ??
        (legacyTrueNorth ? NorthMode.trueNorth : NorthMode.magnetic);
  }

  static Future<void> saveMode(NorthMode m) async => (await _p())?.setString(_kMode, m.name);
}
