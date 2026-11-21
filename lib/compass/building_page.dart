import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../features/map/map_location.dart';
import '../features/map/map_page.dart' show mapsEnabled;
import '../l10n/l10n.dart';
import 'building_facing.dart';

/// 設定一個地點的建築座向：在衛星地圖上沿一面外牆，在牆的兩端各點一下（可拖曳）。
/// 沒有地圖金鑰時改成直接輸入牆向角度。回傳儲存後的 [BuildingFacing]，取消回傳 null。
class BuildingFacingPage extends StatefulWidget {
  const BuildingFacingPage({super.key, this.existing});

  final BuildingFacing? existing;

  @override
  State<BuildingFacingPage> createState() => _BuildingFacingPageState();
}

class _BuildingFacingPageState extends State<BuildingFacingPage> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _manual = TextEditingController(text: widget.existing?.wall.round().toString() ?? '');
  LatLng? _a, _b;
  LatLng? _center;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e?.lat != null && e?.lon != null) {
      _center = LatLng(e!.lat!, e.lon!);
      _locating = false;
    } else if (mapsEnabled) {
      currentLatLon().then((p) {
        if (!mounted) return;
        setState(() {
          _locating = false;
          if (p != null) _center = LatLng(p.$1, p.$2);
        });
      });
    } else {
      _locating = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _manual.dispose();
    super.dispose();
  }

  double? get _wall {
    final a = _a, b = _b;
    if (a != null && b != null) {
      if (a == b) return null;
      return wallBearingOf(a.latitude, a.longitude, b.latitude, b.longitude);
    }
    if (!mapsEnabled) {
      final v = double.tryParse(_manual.text.trim());
      return v == null ? null : wallAxis(v);
    }
    return a == null ? widget.existing?.wall : null; // 編輯時沒重畫就沿用原牆向
  }

  void _tap(LatLng p) => setState(() {
        if (_a == null || _b != null) {
          _a = p;
          _b = null;
        } else {
          _b = p;
        }
      });

  void _save() {
    final wall = _wall;
    final name = _name.text.trim();
    if (wall == null || name.isEmpty) return;
    final a = _a, b = _b;
    final lat = a != null && b != null ? (a.latitude + b.latitude) / 2 : widget.existing?.lat ?? _center?.latitude;
    final lon = a != null && b != null ? (a.longitude + b.longitude) / 2 : widget.existing?.lon ?? _center?.longitude;
    final e = widget.existing;
    Navigator.of(context).pop(e != null
        ? e.copyWith(name: name, wall: wall, lat: lat, lon: lon)
        : BuildingFacing(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, wall: wall, lat: lat, lon: lon));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final wall = _wall;
    final canSave = wall != null && _name.text.trim().isNotEmpty;

    Widget map;
    if (!mapsEnabled) {
      map = ListView(padding: const EdgeInsets.all(16), children: [
        Text(l.buildingManual),
        const SizedBox(height: 8),
        TextField(
          controller: _manual,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: '°'),
          onChanged: (_) => setState(() {}),
        ),
      ]);
    } else if (_locating) {
      map = const Center(child: CircularProgressIndicator());
    } else {
      final a = _a, b = _b;
      map = GoogleMap(
        initialCameraPosition: CameraPosition(target: _center ?? const LatLng(25.0330, 121.5654), zoom: _center == null ? 12 : 19),
        mapType: MapType.hybrid,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: false,
        onTap: _tap,
        markers: {
          if (a != null)
            Marker(
              markerId: const MarkerId('a'),
              position: a,
              draggable: true,
              onDragEnd: (p) => setState(() => _a = p),
            ),
          if (b != null)
            Marker(
              markerId: const MarkerId('b'),
              position: b,
              draggable: true,
              onDragEnd: (p) => setState(() => _b = p),
            ),
        },
        polylines: {
          if (a != null && b != null)
            Polyline(polylineId: const PolylineId('wall'), points: [a, b], color: theme.colorScheme.primary, width: 5),
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.buildingTitle)),
      body: SafeArea(
        child: Column(children: [
          if (mapsEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l.buildingGuide, style: theme.textTheme.bodyMedium),
            ),
          Expanded(child: map),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Text(wall == null ? l.buildingNeedLine : l.buildingWall(wall.round()),
                      style: theme.textTheme.titleMedium),
                ),
                if (mapsEnabled && _a != null)
                  TextButton(onPressed: () => setState(() => _a = _b = null), child: Text(l.buildingRedraw)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: l.buildingName, isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              Wrap(spacing: 6, children: [
                for (final n in [l.buildingHome, l.buildingOffice])
                  ActionChip(label: Text(n), onPressed: () => setState(() => _name.text = n)),
              ]),
              const SizedBox(height: 8),
              FilledButton(onPressed: canSave ? _save : null, child: Text(l.buildingSave)),
            ]),
          ),
        ]),
      ),
    );
  }
}
