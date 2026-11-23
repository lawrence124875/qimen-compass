import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../compass/building_facing.dart';
import '../../compass/compass_math.dart';
import '../../compass/compass_page.dart' show CompassDial;
import '../../compass/geo_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../shared/premium/usage_gate.dart';
import '../../shared/widgets/result_card.dart';
import '../house/heading_tracker.dart';
import '../house/house_widgets.dart' show HeadingPanel;
import '../travel/travel_text.dart';
import 'address_search.dart';
import 'destination_page.dart';
import 'map_location.dart';
import 'maps_link.dart';

/// 地圖八門（HANDOFF §12 P2）：以目前位置為中心畫 8 個 45° 扇區，依此刻時盤各宮的門吉凶上色。
/// 地圖是真北，扇區直接用真北方位角（不經磁偏角）；點地圖或長按放圖釘看落在哪個門；
/// 搜尋地址用手機內建 geocoder（不用付費 Places API）。
/// Maps API key 由 CI 注入（Secret `MAPS_API_KEY`）；沒設時 [mapsEnabled] 為 false，不建立地圖（否則 SDK 會當），只保留搜尋。
const mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.modeSwitch, this.sharedText});

  /// 從 Google 地圖分享進來的文字（含連結），開頁後直接標出該地點。
  final String? sharedText;

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

  /// 手機朝向（指針）；方位依地圖頁自己的北方基準，畫在地圖上一律換算成真北。
  final _heading = HeadingTracker.of(NorthFeature.map);
  double? _drawn;
  (NorthMode, bool)? _drawnBasis;

  /// 羅盤疊圖：盤面疊在地圖中央，地圖跟著手機方向轉（朝前方向朝上），鏡頭鎖定目前位置。
  bool _overlay = true;
  PanUnit _unit = PanUnit.hour;
  double _zoomNow = 17;

  void _onHeading() {
    final h = _heading.trueHeading;
    final basis = (_heading.mode, _heading.showsMagnetic);
    // 疊圖時每 1° 更新，否則指針每 2° 才重畫，避免一直更新地圖
    final step = _overlay ? 1.0 : 2.0;
    if (basis != _drawnBasis || (h == null) != (_drawn == null) || (h != null && turnDelta(_drawn!, h).abs() >= step)) {
      setState(() {
        _drawn = h;
        _drawnBasis = basis;
      });
      if (_overlay) _follow();
    }
  }

  /// 疊圖模式：鏡頭以目前位置為中心，方位跟手機一樣（地圖上方＝手機前方）。
  void _follow() {
    final me = _me, h = _drawn;
    if (me == null || _map == null) return;
    _map!.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(me.$1, me.$2), zoom: _zoomNow, bearing: h ?? 0)));
  }

  void _toggleOverlay() {
    setState(() => _overlay = !_overlay);
    if (_overlay) {
      _follow();
    } else {
      final me = _me;
      if (me != null) {
        _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(me.$1, me.$2), zoom: _zoom, bearing: 0)));
      }
    }
  }

  QimenChart _compute() {
    final now = DateTime.now();
    return const ShiJiaEngine().compute(now, settings: _settings.timeSettingsAt(now), method: _settings.juMethod, unit: _unit);
  }

  @override
  void initState() {
    super.initState();
    _heading.acquire();
    _heading.addListener(_onHeading);
    _locate();
    final shared = widget.sharedText;
    if (shared != null) WidgetsBinding.instance.addPostFrameCallback((_) => _useLink(shared));
    // 換時辰就重算扇區顏色
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final c = _compute();
      if (chartKey(c) != chartKey(_chart) && mounted) setState(() => _chart = c);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heading.removeListener(_onHeading);
    _heading.release();
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
    if (p != null) _heading.setLocation(p.$1, p.$2);
    if (p != null) _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.$1, p.$2), _zoom));
  }

  double get _zoom => switch (_radius) { <= 1000 => 14.0, <= 3000 => 12.5, _ => 11.7 };

  void _setPin(LatLng p, [String? name]) => setState(() {
        _pin = (p.latitude, p.longitude);
        _pinName = name;
      });

  void _clearPin() => setState(() {
        _pin = null;
        _pinName = null;
        _search.clear();
      });

  Future<void> _doSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    if (MapsLink.looksLikeLink(q)) return _useLink(q);
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final f = await findPlace(context, q, near: _me);
    if (!mounted) return;
    setState(() => _searching = false);
    if (f == null) return;
    _showPlace(f, q);
  }

  /// Google 地圖分享的連結或文字 → 標出地點。
  Future<void> _useLink(String text) async {
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final f = await MapsLink.resolve(text);
    if (!mounted) return;
    setState(() => _searching = false);
    if (f == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.mapLinkFailed)));
      return;
    }
    _search.text = f.name;
    _showPlace(f, f.name);
  }

  Future<void> _pasteLink() async {
    final t = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!mounted) return;
    if (t.isEmpty || !MapsLink.looksLikeLink(t)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.mapLinkFailed)));
      return;
    }
    await _useLink(t);
  }

  /// 「從 Google 地圖找」：說明＋開 Google 地圖＋貼上連結。
  Future<void> _googleSheet() async {
    final l = context.l10n;
    final q = _search.text.trim();
    final act = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.mapGoogleTitle, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(Platform.isAndroid ? l.mapGoogleHelpAndroid : l.mapGoogleHelpIos),
            const SizedBox(height: 8),
            Text(l.mapSearchHelp, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: ctx.qm.textMuted)),
            const SizedBox(height: 12),
            FilledButton.icon(icon: const Icon(Icons.map_outlined), label: Text(l.mapOpenGoogle), onPressed: () => Navigator.of(ctx).pop(1)),
            const SizedBox(height: 8),
            OutlinedButton.icon(icon: const Icon(Icons.content_paste), label: Text(l.mapPasteLink), onPressed: () => Navigator.of(ctx).pop(2)),
          ]),
        ),
      ),
    );
    if (act == 1) {
      final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': q.isEmpty ? ' ' : q});
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (act == 2) {
      await _pasteLink();
    }
  }

  void _showPlace(Place f, String q) {
    final p = LatLng(f.lat, f.lon);
    _setPin(p, q);
    if (_overlay) setState(() => _overlay = false); // 要看搜尋結果，先離開疊圖（鏡頭不再鎖定目前位置）
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

  static LatLng _ll((double, double) p) => LatLng(p.$1, p.$2);

  /// 地圖上方的方向讀數：面向哪一宮、幾度、哪一種北。
  Widget _headingChip(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: _headingText(context)),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: IconButton(
            visualDensity: VisualDensity.compact,
            isSelected: _overlay,
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            tooltip: context.l10n.mapCompassOverlay,
            onPressed: _toggleOverlay,
          ),
        ),
      ]);

  Widget _headingText(BuildContext context) {
    final l = context.l10n;
    final t = _heading;
    final h = t.heading;
    final palace = h == null ? null : palaceAtBearing(t.trueHeading!);
    final basis = t.mode == NorthMode.building
        ? '${l.compassBuilding} · ${t.showsMagnetic ? l.compassMagneticNorth : l.compassTrueNorth}'
        : (t.showsMagnetic ? l.compassMagneticNorth : l.compassTrueNorth);
    final text = h == null || palace == null
        ? (t.noSensor ? l.compassNoSensor : l.compassWaiting)
        : '${TravelText.direction(l, palace)} ${QimenTerms.doorName(_chart[palace].door!, L10n.language)} · ${h.round() % 360}° · $basis';
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.navigation, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ),
    );
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
          // 清除地點，回到沒選地點的狀態
          IconButton(icon: const Icon(Icons.close), tooltip: l.mapClearPin, onPressed: _clearPin),
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
    final searchRow = Row(children: [
      Expanded(child: searchRow),
      const SizedBox(width: 4),
      IconButton.filledTonal(icon: const Icon(Icons.travel_explore), tooltip: l.mapGoogleTitle, onPressed: _searching ? null : _googleSheet),
    ]);
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
        initialCameraPosition: CameraPosition(target: LatLng(me.$1, me.$2), zoom: _overlay ? _zoomNow : _zoom),
        onMapCreated: (c) {
          _map = c;
          if (_overlay) _follow();
        },
        onCameraMove: (p) => _zoomNow = p.zoom,
        rotateGesturesEnabled: !_overlay,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        polygons: _overlay ? const {} : _sectors(context),
        markers: {if (_pin != null) Marker(markerId: const MarkerId('pin'), position: LatLng(_pin!.$1, _pin!.$2))},
        polylines: {
          if (_drawn != null && !_overlay)
            Polyline(
              polylineId: const PolylineId('heading'),
              points: [LatLng(me.$1, me.$2), _ll(destinationPoint(me.$1, me.$2, _drawn!, _radius * 1.1))],
              color: Theme.of(context).colorScheme.primary,
              width: 5,
              endCap: Cap.roundCap,
            ),
        },
        onTap: _setPin,
        onLongPress: _setPin,
      );
    }
    return Scaffold(
      appBar: AppBar(title: widget.modeSwitch ?? Text(l.mapTitle)),
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), child: searchBar),
          Expanded(
            child: me == null || !mapsEnabled
                ? mapArea
                : Stack(children: [
                    mapArea,
                    if (_overlay)
                      // 盤面疊在地圖中央；地圖已轉成手機方向，盤面也轉同樣角度，扇形就對準真實方位
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                            child: Center(
                              child: CompassDial(
                                chart: _chart,
                                heading: _drawn ?? 0,
                                live: _drawn != null,
                                backdrop: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(top: 0, left: 0, right: 56, child: Align(alignment: Alignment.topLeft, child: _headingChip(context))),
                  ]),
          ),
          // 下方設定限制高度（可捲動），地圖保持佔大部分畫面
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.3),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _pinCard(context),
                const SizedBox(height: 6),
                SegmentedButton<PanUnit>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(value: PanUnit.hour, label: Text(l.unitHour)),
                    ButtonSegment(value: PanUnit.day, label: Text(l.unitDay)),
                    ButtonSegment(value: PanUnit.month, label: Text(l.unitMonth)),
                    ButtonSegment(value: PanUnit.year, label: Text(l.unitYear)),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (v) => setState(() {
                    _unit = v.first;
                    _chart = _compute();
                  }),
                ),
                if (mapsEnabled) ...[
                  const SizedBox(height: 6),
                  // 疊圖時扇區不畫，範圍與圖例只在一般地圖顯示
                  if (!_overlay) ...[radius, const SizedBox(height: 6), _legend(context), const SizedBox(height: 6)],
                  const HeadingPanel(compact: true, feature: NorthFeature.map, showHeading: false, showLock: false),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
