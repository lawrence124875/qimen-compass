import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../compass/compass_math.dart';
import 'house_geometry.dart';

/// 坐向定法（HANDOFF §6）。
enum SittingMethod { door, light, building, groundDoor }

/// 站在中心點用羅盤標記的房間。[bearing] 為 null 表示在中心（中五宮）。
class MarkedRoom {
  MarkedRoom(this.name, this.bearing);

  String name;
  double? bearing;

  int get palace => bearing == null ? 5 : palaceAtBearing(bearing!);

  Map<String, Object?> toJson() => {'n': name, 'b': bearing};
  static MarkedRoom fromJson(Map<String, Object?> j) => MarkedRoom(j['n'] as String? ?? '', (j['b'] as num?)?.toDouble());
}

/// 平面圖上的房間：長方形（手繪格局）或一個點（在照片上標記）。
class PlanRoom {
  PlanRoom(this.name, {this.rect, this.pin}) : assert(rect != null || pin != null);

  String name;
  Rect? rect;
  Offset? pin;

  Offset get anchor => rect?.center ?? pin!;

  Map<String, Object?> toJson() => {
        'n': name,
        if (rect != null) 'r': [rect!.left, rect!.top, rect!.right, rect!.bottom],
        if (pin != null) 'p': [pin!.dx, pin!.dy],
      };

  static PlanRoom? fromJson(Map<String, Object?> j) {
    final r = (j['r'] as List?)?.cast<num>();
    final p = (j['p'] as List?)?.cast<num>();
    if (r == null && p == null) return null;
    return PlanRoom(
      j['n'] as String? ?? '',
      rect: r == null ? null : Rect.fromLTRB(r[0].toDouble(), r[1].toDouble(), r[2].toDouble(), r[3].toDouble()),
      pin: p == null ? null : Offset(p[0].toDouble(), p[1].toDouble()),
    );
  }
}

/// 平面圖：照片（四角校正）或手繪。座標單位：高固定 [kPlanHeight]，寬依長寬比。
class FloorPlan {
  FloorPlan({
    this.imagePath,
    this.imageW = 0,
    this.imageH = 0,
    List<Offset>? corners,
    this.aspect = 1,
    this.upBearing = 0,
    this.northSet = false,
    this.manualCenter,
    List<PlanRoom>? rooms,
  })  : corners = corners ?? const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)],
        rooms = rooms ?? [];

  static const kPlanHeight = 12.0;

  /// 照片路徑（App 文件夾內）；手繪時為 null。
  String? imagePath;
  double imageW, imageH;

  /// 照片上的四角（0–1 正規化）：左上、右上、右下、左下。
  List<Offset> corners;

  /// 校正後的寬／高。
  double aspect;

  /// 圖的上方在現實中的方位角。
  double upBearing;
  bool northSet;

  /// 手動微調的中心；null 時自動算重心。
  Offset? manualCenter;

  final List<PlanRoom> rooms;

  bool get isPhoto => imagePath != null;
  double get width => kPlanHeight * aspect;
  double get height => kPlanHeight;
  Rect get bounds => Rect.fromLTWH(0, 0, width, height);

  List<Rect> get outline => [for (final r in rooms) if (r.rect != null) r.rect!];

  /// 重心：有手繪房間時取房間聯集的重心，否則取整張圖的中心。
  Offset get autoCenter => unionCentroid(outline) ?? bounds.center;
  Offset get center => manualCenter ?? autoCenter;

  double get centerR => centerRadius(outline.isEmpty ? width * height : unionArea(outline));

  int palaceOf(PlanRoom r) => r.rect != null
      ? palaceOfRect(center, r.rect!, upBearing, centerR: centerR)
      : palaceAtPoint(center, r.pin!, upBearing, centerR: centerR);

  Map<String, Object?> toJson() => {
        if (imagePath != null) 'img': imagePath,
        'iw': imageW,
        'ih': imageH,
        'c': [for (final o in corners) ...[o.dx, o.dy]],
        'a': aspect,
        'up': upBearing,
        'ns': northSet,
        if (manualCenter != null) 'mc': [manualCenter!.dx, manualCenter!.dy],
        'rooms': [for (final r in rooms) r.toJson()],
      };

  static FloorPlan fromJson(Map<String, Object?> j) {
    final c = (j['c'] as List?)?.cast<num>();
    final mc = (j['mc'] as List?)?.cast<num>();
    return FloorPlan(
      imagePath: j['img'] as String?,
      imageW: (j['iw'] as num?)?.toDouble() ?? 0,
      imageH: (j['ih'] as num?)?.toDouble() ?? 0,
      corners: c != null && c.length == 8
          ? [for (var i = 0; i < 4; i++) Offset(c[2 * i].toDouble(), c[2 * i + 1].toDouble())]
          : null,
      aspect: (j['a'] as num?)?.toDouble() ?? 1,
      upBearing: (j['up'] as num?)?.toDouble() ?? 0,
      northSet: j['ns'] as bool? ?? false,
      manualCenter: mc == null ? null : Offset(mc[0].toDouble(), mc[1].toDouble()),
      rooms: [
        for (final r in (j['rooms'] as List? ?? const []))
          if (PlanRoom.fromJson((r as Map).cast<String, Object?>()) case final room?) room,
      ],
    );
  }
}

/// 一間房子的宅盤資料。資料 JSON 帶 schemaVersion（HANDOFF §14）。
class House {
  House({
    String? id,
    this.name = '',
    this.sittingMethod = SittingMethod.door,
    this.facing,
    this.moveIn,
    this.moveInHasTime = false,
    List<MarkedRoom>? marked,
    this.plan,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        marked = marked ?? [];

  /// 多間房子：識別碼與名稱（空白名稱顯示「我的家」）。
  final String id;
  String name;

  static const schemaVersion = 1;

  SittingMethod sittingMethod;

  /// 向（面朝方位角）；null＝未量。
  double? facing;

  /// 入宅或大裝修時間（選填）。
  DateTime? moveIn;
  bool moveInHasTime;

  final List<MarkedRoom> marked;
  FloorPlan? plan;

  bool get isEmpty => marked.isEmpty && plan == null && facing == null;

  /// 每宮的房間名稱（羅盤標記＋平面圖）。
  Map<int, List<String>> roomsByPalace() {
    final m = <int, List<String>>{};
    for (final r in marked) {
      (m[r.palace] ??= []).add(r.name);
    }
    final p = plan;
    if (p != null) {
      for (final r in p.rooms) {
        if (r.name.isEmpty) continue;
        (m[p.palaceOf(r)] ??= []).add(r.name);
      }
    }
    return m;
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'sm': sittingMethod.name,
        'f': facing,
        if (moveIn != null) 'mi': moveIn!.toIso8601String(),
        'mit': moveInHasTime,
        'marked': [for (final r in marked) r.toJson()],
        if (plan != null) 'plan': plan!.toJson(),
      };

  static House fromJson(Map<String, Object?> j) => House(
        id: j['id'] as String?,
        name: j['name'] as String? ?? '',
        sittingMethod: SittingMethod.values.firstWhere((m) => m.name == j['sm'], orElse: () => SittingMethod.door),
        facing: (j['f'] as num?)?.toDouble(),
        moveIn: DateTime.tryParse(j['mi'] as String? ?? ''),
        moveInHasTime: j['mit'] as bool? ?? false,
        marked: [for (final r in (j['marked'] as List? ?? const [])) MarkedRoom.fromJson((r as Map).cast<String, Object?>())],
        plan: j['plan'] is Map ? FloorPlan.fromJson((j['plan'] as Map).cast<String, Object?>()) : null,
      );
}

/// 宅盤存取（SharedPreferences）：多間房子存在 `qm_houses`（schemaVersion 1：current＋houses），
/// 舊版單間 `qm_house` 第一次讀取時搬成第一間。
class HouseStore {
  HouseStore._();

  static const _legacyKey = 'qm_house';
  static const _key = 'qm_houses';
  static const schemaVersion = 1;

  static Future<(List<House>, String?)> _read() async {
    final p = await SharedPreferences.getInstance();
    try {
      final s = p.getString(_key);
      if (s != null) {
        final j = (jsonDecode(s) as Map).cast<String, Object?>();
        final list = [
          for (final h in (j['houses'] as List? ?? const [])) House.fromJson((h as Map).cast<String, Object?>()),
        ];
        return (list, j['current'] as String?);
      }
      final legacy = p.getString(_legacyKey);
      if (legacy != null) {
        final h = House.fromJson((jsonDecode(legacy) as Map).cast<String, Object?>());
        await _write([h], h.id);
        await p.remove(_legacyKey);
        return ([h], h.id);
      }
    } catch (_) {}
    return (<House>[], null);
  }

  static Future<void> _write(List<House> houses, String? current) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
          _key,
          jsonEncode({
            'schemaVersion': schemaVersion,
            'current': current,
            'houses': [for (final h in houses) h.toJson()],
          }));
    } catch (_) {}
  }

  /// 全部房子（依建立順序）。
  static Future<List<House>> all() async => (await _read()).$1;

  /// 目前選的房子；一間都沒有時建立一間（尚未存檔，第一次 [save] 才寫入）。
  static Future<House> load() async {
    final (list, current) = await _read();
    if (list.isEmpty) return House();
    return list.firstWhere((h) => h.id == current, orElse: () => list.first);
  }

  /// 存一間（不存在就加入），並設為目前的房子。
  static Future<void> save(House h) async {
    final (list, _) = await _read();
    final i = list.indexWhere((x) => x.id == h.id);
    if (i >= 0) {
      list[i] = h;
    } else {
      list.add(h);
    }
    await _write(list, h.id);
  }

  static Future<void> select(String id) async {
    final (list, _) = await _read();
    await _write(list, id);
  }

  /// 刪除一間，回傳原本的位置（供復原）；刪掉目前那間時改選第一間。
  static Future<int> delete(String id) async {
    final (list, current) = await _read();
    final i = list.indexWhere((x) => x.id == id);
    if (i < 0) return -1;
    list.removeAt(i);
    await _write(list, current == id ? (list.isEmpty ? null : list.first.id) : current);
    return i;
  }

  /// 復原刪除。
  static Future<void> restore(House h, int index) async {
    final (list, _) = await _read();
    if (list.any((x) => x.id == h.id)) return;
    list.insert(index.clamp(0, list.length), h);
    await _write(list, h.id);
  }
}
