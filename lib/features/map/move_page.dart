import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'map_page.dart' show mapsEnabled;
import 'map_location.dart';

/// 遠行、搬家方位（HANDOFF §12 P5）：以住家為中心，新家或旅遊地的真北方位落在哪一宮，
/// 對照今年、明年的年盤與接下來 12 個月的月盤，看該方位的吉凶，挑出較好的月份。
class MovePage extends StatefulWidget {
  const MovePage({super.key, this.locked = false});

  /// 免費版體驗過後：只給今年、明年等級與吉月數，哪幾個月與每月詳情要訂閱。
  final bool locked;

  @override
  State<MovePage> createState() => _MovePageState();
}

class _MovePageState extends State<MovePage> {
  static const _kLat = 'qm_home_lat', _kLon = 'qm_home_lon', _kName = 'qm_home_name';
  final _search = TextEditingController();
  (double, double)? _home, _dest;
  String? _destName, _homeName;
  bool _busy = false;
  late bool _locked = widget.locked;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final la = p.getDouble(_kLat), lo = p.getDouble(_kLon);
      if (la != null && lo != null && mounted) {
        setState(() {
          _home = (la, lo);
          _homeName = p.getString(_kName);
        });
      }
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
    await _saveHome(p, null);
  }

  Future<void> _saveHome((double, double) p, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, p.$1);
    await prefs.setDouble(_kLon, p.$2);
    name == null ? await prefs.remove(_kName) : await prefs.setString(_kName, name);
    if (mounted) {
      setState(() {
        _home = p;
        _homeName = name;
      });
    }
  }

  /// 住家用輸入地址設定（geocoding），不必人在家。
  Future<void> _setHomeByAddress() async {
    final l = context.l10n;
    final ctrl = TextEditingController(text: _homeName ?? '');
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.moveHome),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
          decoration: InputDecoration(hintText: l.moveHomeAddrHint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text(l.moveHomeSet)),
        ],
      ),
    );
    ctrl.dispose();
    final addr = q?.trim() ?? '';
    if (addr.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final p = await findPlace(context, addr, near: _home, refineOnMap: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (p != null) await _saveHome((p.lat, p.lon), addr);
  }

  /// 住家直接在地圖上點選。
  Future<void> _setHomeOnMap() async {
    final center = _home ?? await currentLatLon();
    if (!mounted) return;
    final p = await pickOnMap(context, center: center, zoom: 17);
    if (p != null && mounted) await _saveHome((p.lat, p.lon), null);
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final p = await findPlace(context, q, near: _home);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (p != null) {
        _dest = (p.lat, p.lon);
        _destName = q;
      }
    });
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
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(l.moveHome),
            subtitle: Text(home == null
                ? l.moveHomeUnset
                : _homeName ?? '${home.$1.toStringAsFixed(4)}, ${home.$2.toStringAsFixed(4)}'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: _busy ? null : _setHomeByAddress, icon: const Icon(Icons.edit_location_alt_outlined), label: Text(l.moveHomeAddr)),
              OutlinedButton.icon(onPressed: _busy ? null : _setHomeHere, icon: const Icon(Icons.my_location), label: Text(l.moveUseHere)),
              if (mapsEnabled)
                OutlinedButton.icon(onPressed: _busy ? null : _setHomeOnMap, icon: const Icon(Icons.map_outlined), label: Text(l.addrPickOnMap)),
            ]),
          ),
        ]),
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
      final locked = _locked;
      Widget row(String label, DirectionVerdict v) => ListTile(
            dense: true,
            title: Text(label),
            subtitle: locked ? null : Text([if (v.door != null) QimenTerms.door(v.door!, lang), ...v.flags.map((f) => TravelText.flag(l, f))].join(l.separator)),
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
        if (locked) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(good.isEmpty ? l.moveNoGoodMonth : l.moveGoodCount(good.length)),
          ),
          PremiumLockCard(feature: 'move', text: l.moveLocked, onUnlocked: () => setState(() => _locked = false)),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(good.isEmpty ? l.moveNoGoodMonth : l.labelValue(l.moveGoodMonths, good.join(l.separator))),
          ),
          for (final m in months) row(l.fortuneMonth('${m.$1.year}-${m.$1.month.toString().padLeft(2, '0')}'), m.$2),
        ],
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
