import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'app_settings.dart';
import 'cities.dart';

/// 真太陽時目前選擇的顯示文字，例如「台北（121.6°）」「目前位置（121.5°）」。
String solarLabel(AppLocalizations l, AppSettings s, String lang) {
  String deg(double v) => '${v.toStringAsFixed(1)}°';
  if (s.solarCityIndex == AppSettings.solarGps) {
    final lon = s.gpsLongitude;
    return lon == null ? l.solarTimeGpsName : '${l.solarTimeGpsName}（${deg(lon)}）';
  }
  final c = s.solarCity;
  return c == null ? l.solarTimeOff : '${c.name(lang)}（${deg(c.longitude)}）';
}

/// 真太陽時：不使用／目前位置（GPS 概略位置）／搜尋全球城市（中英文、國家）。
Future<void> showSolarCityPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SolarCitySheet(),
    );

class _SolarCitySheet extends StatefulWidget {
  const _SolarCitySheet();

  @override
  State<_SolarCitySheet> createState() => _SolarCitySheetState();
}

class _SolarCitySheetState extends State<_SolarCitySheet> {
  String _q = '';
  bool _locating = false;

  Future<void> _gps() async {
    setState(() => _locating = true);
    final err = await AppSettings.instance.useGpsLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.solarTimeLocFailed)));
    }
  }

  void _pick(int i) {
    AppSettings.instance.solarCityIndex = i;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = AppSettings.instance;
    final lang = L10n.language.code;
    final idx = [
      for (var i = 0; i < kCities.length; i++)
        if (kCities[i].matches(_q)) i,
    ];
    final sel = s.solarCityIndex;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(l.solarTimeOff),
            trailing: sel == -1 ? const Icon(Icons.check) : null,
            onTap: () => _pick(-1),
          ),
          ListTile(
            leading: _locating
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            title: Text(l.solarTimeGps),
            subtitle: sel == AppSettings.solarGps && s.gpsLongitude != null
                ? Text('${s.gpsLongitude!.toStringAsFixed(1)}°')
                : null,
            trailing: sel == AppSettings.solarGps ? const Icon(Icons.check) : null,
            onTap: _locating ? null : _gps,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.solarTimeSearch,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: idx.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Text(l.solarTimeNoMatch, textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: idx.length,
                    itemBuilder: (context, k) {
                      final c = kCities[idx[k]];
                      return ListTile(
                        dense: true,
                        title: Text(c.name(lang)),
                        subtitle: Text(lang.startsWith('zh') ? '${c.en}・${c.country}' : c.country),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${c.longitude.toStringAsFixed(1)}°'),
                          if (sel == idx[k]) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check)),
                        ]),
                        onTap: () => _pick(idx[k]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
