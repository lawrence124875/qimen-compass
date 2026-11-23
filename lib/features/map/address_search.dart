import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../l10n/l10n.dart';
import '../../compass/geo_math.dart';
import 'map_location.dart' show distanceText;
import 'map_page.dart' show mapsEnabled;

/// 一筆地址查詢結果。
class Place {
  const Place(this.lat, this.lon, this.name);

  final double lat, lon;
  final String name;
}

/// 地址查詢（全部免費、不需金鑰，各國通用）：
/// 1. 手機內建 geocoder（Android 為 Google 服務、iOS 為 Apple），在地址寫法最熟悉；
/// 2. 同時查 OpenStreetMap Nominatim（沒有 Google 服務的手機、地名、外國地址）；
/// 3. 都查不到時去掉門牌再查一次（先找到路名，再到地圖上微調）；
/// 4. 仍找不到，由呼叫端提供「在地圖上點選」。
/// Nominatim 使用規範：每次使用者按下搜尋才查一次（不做即打即查）、帶 App 名稱的 User-Agent、標示 © OpenStreetMap。
class AddressSearch {
  AddressSearch._();

  static const osmCredit = '© OpenStreetMap contributors';

  /// [near]＝目前位置：附近優先查詢，結果依距離由近到遠排序。
  static Future<List<Place>> search(String query, {(double, double)? near}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    var r = await _both(q, near);
    if (r.isEmpty) {
      final short = _dropHouseNumber(q);
      if (short != null && short != q) r = await _both(short, near);
    }
    if (near != null) {
      r = [...r]..sort((a, b) => distanceMeters(near.$1, near.$2, a.lat, a.lon).compareTo(distanceMeters(near.$1, near.$2, b.lat, b.lon)));
    }
    return r;
  }

  static Future<List<Place>> _both(String q, (double, double)? near) async {
    final res = await Future.wait([_platform(q), _nominatim(q, near), _apple(q, near)]);
    // iOS：Apple 地圖地點搜尋（店名、地標都找得到）放最前面
    final out = <Place>[...res[2]];
    for (final p in res[0]) {
      if (out.every((o) => (o.lat - p.lat).abs() > 0.003 || (o.lon - p.lon).abs() > 0.003)) out.add(p);
    }
    for (final p in res[1]) {
      // 與手機 geocoder 結果相距 300 m 內視為同一處
      if (out.every((o) => (o.lat - p.lat).abs() > 0.003 || (o.lon - p.lon).abs() > 0.003)) out.add(p);
    }
    return out.take(8).toList();
  }

  static const _places = MethodChannel('qm/places');

  /// iOS 才有（packages/qm_places，MKLocalSearch，免費免金鑰）。
  static Future<List<Place>> _apple(String q, (double, double)? near) async {
    if (!Platform.isIOS) return const [];
    try {
      final r = await _places.invokeListMethod<Map<dynamic, dynamic>>('search', {
        'q': q,
        if (near != null) 'lat': near.$1,
        if (near != null) 'lon': near.$2,
      }).timeout(const Duration(seconds: 8));
      return [
        for (final e in r ?? const <Map<dynamic, dynamic>>[])
          if (e['lat'] is num && e['lon'] is num) Place((e['lat'] as num).toDouble(), (e['lon'] as num).toDouble(), '${e['name'] ?? q}'),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Place>> _platform(String q) async {
    try {
      final r = await geo.locationFromAddress(q).timeout(const Duration(seconds: 8));
      return [for (final x in r.take(3)) Place(x.latitude, x.longitude, q)];
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Place>> _nominatim(String q, (double, double)? near) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '6',
        // 附近優先（約 ±50 km，不排除範圍外）
        if (near != null) 'viewbox': '${near.$2 - 0.5},${near.$1 + 0.5},${near.$2 + 0.5},${near.$1 - 0.5}',
        'accept-language': L10n.language.locale.languageCode,
      });
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, 'QimenCompass/1.x (com.lclab.qimen; Flutter)');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
      final list = jsonDecode(body) as List<dynamic>;
      return [
        for (final e in list.cast<Map<String, dynamic>>())
          if (double.tryParse('${e['lat']}') case final la?)
            if (double.tryParse('${e['lon']}') case final lo?) Place(la, lo, '${e['display_name'] ?? q}'),
      ];
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  /// 去掉門牌：「…市府路1號」→「…市府路」、「1600 Amphitheatre Pkwy」→「Amphitheatre Pkwy」、
  /// 「〇〇1-2-3」→「〇〇」。沒有可去掉的回傳 null。
  static String? _dropHouseNumber(String q) {
    var s = q
        .replaceAll(RegExp(r'[0-9０-９]+([\-－之][0-9０-９]+)*\s*(號|号|番地?|번지|호|樓|楼|F|f)?(\s*[0-9０-９]+\s*(樓|楼|F|f|室))?\s*$'), '')
        .replaceAll(RegExp(r'^\s*[0-9]+[A-Za-z]?\s+'), '')
        .replaceAll(RegExp(r',\s*[0-9]+[A-Za-z]?\s*,'), ',')
        .trim();
    s = s.replaceAll(RegExp(r'[,，\s]+$'), '');
    return s.isEmpty || s == q ? null : s;
  }
}

/// 查地址並讓使用者確認位置：多筆結果先讓使用者選，有地圖時再到地圖上微調；
/// 查不到時直接開地圖點選（以 [near] 或第一筆結果為中心）。回傳 null 表示取消。
Future<Place?> findPlace(BuildContext context, String query, {(double, double)? near, bool refineOnMap = false}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final r = await AddressSearch.search(query, near: near);
  if (!context.mounted) return null;
  if (r.isEmpty) {
    if (!mapsEnabled) {
      messenger.showSnackBar(SnackBar(content: Text(l.mapNotFound)));
      return null;
    }
    messenger.showSnackBar(SnackBar(content: Text(l.addrNotFoundPick)));
    return pickOnMap(context, center: near, name: query);
  }
  Place? p = r.length == 1 ? r.first : await _choose(context, r, near);
  if (p == null || !context.mounted) return null;
  if (refineOnMap && mapsEnabled) p = await pickOnMap(context, center: (p.lat, p.lon), name: p.name, zoom: 17);
  return p;
}

Future<Place?> _choose(BuildContext context, List<Place> r, (double, double)? near) {
  final l = context.l10n;
  return showModalBottomSheet<Place>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(l.addrChoose, style: Theme.of(ctx).textTheme.titleMedium)),
        for (final p in r)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(near == null
                ? '${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}'
                : distanceText(distanceMeters(near.$1, near.$2, p.lat, p.lon))),
            onTap: () => Navigator.of(ctx).pop(p),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(AddressSearch.osmCredit, style: Theme.of(ctx).textTheme.bodySmall),
        ),
      ]),
    ),
  );
}

/// 在地圖上點選位置：拖動地圖讓中心十字對準，或直接點地圖。沒有地圖金鑰時回傳 null。
Future<Place?> pickOnMap(BuildContext context, {(double, double)? center, String? name, double zoom = 15}) {
  if (!mapsEnabled) return Future.value();
  return Navigator.of(context).push<Place>(
    MaterialPageRoute(builder: (_) => _PickOnMapPage(center: center, name: name, zoom: zoom)),
  );
}

class _PickOnMapPage extends StatefulWidget {
  const _PickOnMapPage({this.center, this.name, required this.zoom});

  final (double, double)? center;
  final String? name;
  final double zoom;

  @override
  State<_PickOnMapPage> createState() => _PickOnMapPageState();
}

class _PickOnMapPageState extends State<_PickOnMapPage> {
  GoogleMapController? _map;
  late LatLng _target = LatLng(widget.center?.$1 ?? 25.0375, widget.center?.$2 ?? 121.5637);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.addrPickOnMap)),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _target, zoom: widget.center == null ? 3 : widget.zoom),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onMapCreated: (c) => _map = c,
          onCameraMove: (p) => _target = p.target,
          onTap: (p) => _map?.animateCamera(CameraUpdate.newLatLng(p)),
        ),
        // 中心十字（圖釘尖端對準地圖中心）
        IgnorePointer(
          child: Center(
            child: Padding(padding: const EdgeInsets.only(bottom: 40), child: Icon(Icons.location_on, size: 44, color: cs.error)),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Card(
            child: Padding(padding: const EdgeInsets.all(10), child: Text(l.addrPickHint)),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(l.addrConfirm),
            onPressed: () => Navigator.of(context).pop(Place(_target.latitude, _target.longitude, widget.name ?? l.addrPinned)),
          ),
        ),
      ),
    );
  }
}
