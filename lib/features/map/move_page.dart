import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../compass/compass_math.dart';
import '../../compass/geo_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../shared/widgets/result_card.dart';
import '../travel/travel_text.dart';
import 'map_location.dart';

/// 遠行、搬家方位（HANDOFF §12 P5）：以住家為中心，新家或旅遊地的真北方位落在哪一宮，
/// 對照今年、明年的年盤與接下來 12 個月的月盤，看該方位的吉凶，挑出較好的月份。
class MovePage extends StatefulWidget {
  const MovePage({super.key});

  @override
  State<MovePage> createState() => _MovePageState();
}

class _MovePageState extends State<MovePage> {
  static const _kLat = 'qm_home_lat', _kLon = 'qm_home_lon';
  final _search = TextEditingController();
  (double, double)? _home, _dest;
  String? _destName;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final la = p.getDouble(_kLat), lo = p.getDouble(_kLon);
      if (la != null && lo != null && mounted) setState(() => _home = (la, lo));
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _setHomeHere() async {
    setState(() => _busy = true);
    final p = await currentLatLon();
    if (!mounted) return;
    setState(() => _busy = false);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.mapNoLocation.replaceAll('\n', ' '))));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, p.$1);
    await prefs.setDouble(_kLon, p.$2);
    if (mounted) setState(() => _home = p);
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    List<geo.Location> r = const [];
    try {
      r = await geo.locationFromAddress(q);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.isNotEmpty) {
        _dest = (r.first.latitude, r.first.longitude);
        _destName = q;
      }
    });
    if (r.isEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.mapNotFound)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final home = _home, dest = _dest;
    final children = <Widget>[
      Text(l.moveHint, style: text.bodySmall?.copyWith(color: qm.textMuted)),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: const Icon(Icons.home_outlined),
          title: Text(l.moveHome),
          subtitle: Text(home == null ? l.moveHomeUnset : '${home.$1.toStringAsFixed(4)}, ${home.$2.toStringAsFixed(4)}'),
          trailing: TextButton(onPressed: _busy ? null : _setHomeHere, child: Text(l.moveUseHere)),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _find(),
        decoration: InputDecoration(
          isDense: true,
          hintText: l.moveDestHint,
          prefixIcon: const Icon(Icons.place_outlined),
          suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _busy ? null : _find),
          border: const OutlineInputBorder(),
        ),
      ),
      if (_busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
    ];
    if (home != null && dest != null) {
      final s = AppSettings.instance;
      final b = bearingTo(home.$1, home.$2, dest.$1, dest.$2);
      final d = distanceMeters(home.$1, home.$2, dest.$1, dest.$2);
      final palace = palaceAtBearing(b);
      final now = DateTime.now();
      DirectionVerdict judge(DateTime t, PanUnit u) => DirectionPlanner.judge(
          const ShiJiaEngine().compute(t, settings: s.timeSettingsAt(t), method: s.juMethod, unit: u), palace);
      Widget row(String label, DirectionVerdict v) => ListTile(
            dense: true,
            title: Text(label),
            subtitle: Text([if (v.door != null) QimenTerms.door(v.door!, lang), ...v.flags.map((f) => TravelText.flag(l, f))].join(l.separator)),
            trailing: ToneBadge(tone: toneOfLevel(v.level), label: TravelText.level(l, v.level)),
          );
      final months = [
        for (var i = 0; i < 12; i++)
          () {
            final t = DateTime(now.year, now.month + i, 15);
            return (t, judge(t, PanUnit.month));
          }(),
      ];
      final good = months.where((m) => m.$2.recommended).map((m) => '${m.$1.year}-${m.$1.month.toString().padLeft(2, '0')}').toList();
      children.addAll([
        const SizedBox(height: 12),
        if (_destName != null) Text(_destName!, style: text.titleMedium),
        Text(l.mapPinInfo(TravelText.direction(l, palace), '${b.round()}', distanceText(d))),
        Text(l.movePalace(QimenTerms.palace(palace, lang)),
            style: text.bodySmall?.copyWith(color: qm.textMuted)),
        const SizedBox(height: 8),
        Text(l.moveYears, style: text.titleSmall?.copyWith(color: qm.primary)),
        row(l.fortuneYear('${now.year}'), judge(DateTime(now.year, 7, 1), PanUnit.year)),
        row(l.fortuneYear('${now.year + 1}'), judge(DateTime(now.year + 1, 7, 1), PanUnit.year)),
        const Divider(),
        Text(l.moveMonths, style: text.titleSmall?.copyWith(color: qm.primary)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(good.isEmpty ? l.moveNoGoodMonth : l.labelValue(l.moveGoodMonths, good.join(l.separator))),
        ),
        for (final m in months) row(l.fortuneMonth('${m.$1.year}-${m.$1.month.toString().padLeft(2, '0')}'), m.$2),
        const SizedBox(height: 8),
        Text(l.mapTrueNorthNote, style: text.bodySmall?.copyWith(color: qm.textMuted)),
        Text(l.homeDisclaimer, style: text.bodySmall?.copyWith(color: qm.textMuted)),
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.moveTitle)),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: children)),
    );
  }
}
