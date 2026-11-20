import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../compass/compass_math.dart';
import '../../compass/geo_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../shared/premium/usage_gate.dart';
import '../../shared/widgets/result_card.dart';
import '../travel/travel_text.dart';
import 'address_search.dart';
import 'destination_page.dart';
import 'map_location.dart';

/// 地圖八門（HANDOFF §12 P2）：以目前位置為中心畫 8 個 45° 扇區，依此刻時盤各宮的門吉凶上色。
/// 地圖是真北，扇區直接用真北方位角（不經磁偏角）；點地圖或長按放圖釘看落在哪個門；
/// 搜尋地址用手機內建 geocoder（不用付費 Places API）。
/// Maps API key 由 CI 注入（Secret `MAPS_API_KEY`）；沒設時 [mapsEnabled] 為 false，不建立地圖（否則 SDK 會當），只保留搜尋。
const mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.modeSwitch});

  /// 羅盤分頁的「羅盤⇄地圖」切換鈕（放在標題列）。
  final Widget? modeSwitch;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _radii = [1000.0, 3000.0, 5000.0];
  final _settings = AppSettings.instance;
  final _search = TextEditingController();
  GoogleMapController? _map;
  (double, double)? _me;
  bool _locating = true;
  double _radius = 3000;
  late QimenChart _chart = _compute();
  (double, double)? _pin;
  String? _pinName;
  Timer? _timer;
  bool _searching = false;

  QimenChart _compute() {
    final now = DateTime.now();
    return const ShiJiaEngine().compute(now, settings: _settings.timeSettingsAt(now), method: _settings.juMethod);
  }

  @override
  void initState() {
    super.initState();
    _locate();
    // 換時辰就重算扇區顏色
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final c = _compute();
      if (chartKey(c) != chartKey(_chart) && mounted) setState(() => _chart = c);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final p = await currentLatLon();
    if (!mounted) return;
    setState(() {
      _me = p;
      _locating = false;
    });
    if (p != null) _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.$1, p.$2), _zoom));
  }

  double get _zoom => switch (_radius) { <= 1000 => 14.0, <= 3000 => 12.5, _ => 11.7 };

  void _setPin(LatLng p, [String? name]) => setState(() {
        _pin = (p.latitude, p.longitude);
        _pinName = name;
      });

  Future<void> _doSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final f = await findPlace(context, q, near: _me);
    if (!mounted) return;
    setState(() => _searching = false);
    if (f == null) return;
    final p = LatLng(f.lat, f.lon);
    _setPin(p, q);
    final me = _me;
    if (me != null && _map != null) {
      final sw = LatLng(me.$1 < p.latitude ? me.$1 : p.latitude, me.$2 < p.longitude ? me.$2 : p.longitude);
      final ne = LatLng(me.$1 > p.latitude ? me.$1 : p.latitude, me.$2 > p.longitude ? me.$2 : p.longitude);
      _map!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 64));
    }
  }

  Future<void> _openDestination() async {
    final me = _me, pin = _pin;
    if (me == null || pin == null) return;
    // 目的地吉凶：免費版第一次完整體驗，之後只給現在的吉凶，較好時段要訂閱
    final access = await peekPremium(context, feature: 'destination');
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DestinationPage(from: me, to: pin, name: _pinName, locked: access == PremiumAccess.titleOnly)));
  }

  Set<Polygon> _sectors(BuildContext context) {
    final me = _me;
    if (me == null) return const {};
    final qm = context.qm;
    return {
      for (final e in palaceBearing.entries)
        Polygon(
          polygonId: PolygonId('p${e.key}'),
          points: [for (final (la, lo) in sectorPoints(me.$1, me.$2, e.value, _radius)) LatLng(la, lo)],
          fillColor: qm.luck(_chart[e.key].door!.luck).withValues(alpha: 0.22),
          strokeColor: qm.luck(_chart[e.key].door!.luck).withValues(alpha: 0.8),
          strokeWidth: 2,
        ),
    };
  }

  /// 8 個扇區的門名標籤（地圖上用 Marker 的資訊視窗太亂，改在下方列出）。
  Widget _legend(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final p in const [9, 4, 2, 3, 7, 8, 6, 1])
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: qm.luck(_chart[p].door!.luck).withValues(alpha: 0.15),
            border: Border.all(color: qm.luck(_chart[p].door!.luck)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(toneOfLuck(_chart[p].door!.luck).icon, size: 13, color: qm.luck(_chart[p].door!.luck)),
            const SizedBox(width: 3),
            Text('${TravelText.direction(l, p)} ${QimenTerms.doorName(_chart[p].door!, lang)}',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
    ]);
  }

  Widget _pinCard(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final me = _me, pin = _pin;
    if (pin == null) {
      return Text(me == null ? l.mapNoLocation : l.mapTapHint,
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: qm.textMuted));
    }
    if (me == null) return Text(l.mapNoLocation);
    final b = bearingTo(me.$1, me.$2, pin.$1, pin.$2);
    final d = distanceMeters(me.$1, me.$2, pin.$1, pin.$2);
    final palace = palaceAtBearing(b);
    final door = _chart[palace].door!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_pinName != null) Text(_pinName!, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(l.mapPinInfo(TravelText.direction(l, palace), '${b.round()}', distanceText(d))),
              ToneLabel(
                  tone: toneOfLuck(door.luck),
                  text: l.mapPinDoor(QimenTerms.palace(palace, lang), QimenTerms.door(door, lang), l.luck(door.luck))),
            ]),
          ),
          FilledButton(onPressed: _openDestination, child: Text(l.destCheck)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = _me;
    final searchBar = TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _doSearch(),
      decoration: InputDecoration(
        isDense: true,
        hintText: l.mapSearchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searching
            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _doSearch),
        border: const OutlineInputBorder(),
      ),
    );
    final radius = SegmentedButton<double>(
      showSelectedIcon: false,
      segments: [for (final r in _radii) ButtonSegment(value: r, label: Text(l.mapKm((r / 1000).round())))],
      selected: {_radius},
      onSelectionChanged: (v) {
        setState(() => _radius = v.first);
        if (me != null) _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(me.$1, me.$2), _zoom));
      },
    );
    Widget mapArea;
    if (!mapsEnabled) {
      mapArea = Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.mapDisabled, textAlign: TextAlign.center)));
    } else if (_locating) {
      mapArea = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(l.mapLocating)]));
    } else if (me == null) {
      mapArea = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(24), child: Text(l.mapNoLocation, textAlign: TextAlign.center)),
          OutlinedButton(onPressed: _locate, child: Text(l.mapRetry)),
        ]),
      );
    } else {
      mapArea = GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(me.$1, me.$2), zoom: _zoom),
        onMapCreated: (c) => _map = c,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        polygons: _sectors(context),
        markers: {if (_pin != null) Marker(markerId: const MarkerId('pin'), position: LatLng(_pin!.$1, _pin!.$2))},
        onTap: _setPin,
        onLongPress: _setPin,
      );
    }
    return Scaffold(
      appBar: AppBar(title: widget.modeSwitch ?? Text(l.mapTitle)),
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), child: searchBar),
          Expanded(child: mapArea),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (mapsEnabled) ...[radius, const SizedBox(height: 8), _legend(context), const SizedBox(height: 8)],
              _pinCard(context),
            ]),
          ),
        ]),
      ),
    );
  }
}
