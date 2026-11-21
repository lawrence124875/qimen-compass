import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../app/settings/app_settings.dart';
import '../app/settings/cities.dart';
import '../features/map/address_search.dart';
import '../l10n/l10n.dart';

/// 手機地區代碼 → 城市表的國家名（[City.country]）。
const _region = {
  'TW': 'Taiwan', 'CN': 'China', 'HK': 'China', 'MO': 'China', 'US': 'USA', 'JP': 'Japan', 'AU': 'Australia',
  'CA': 'Canada', 'MY': 'Malaysia', 'IN': 'India', 'DE': 'Germany', 'VN': 'Vietnam', 'GB': 'UK', 'TH': 'Thailand',
  'SA': 'Saudi Arabia', 'RU': 'Russia', 'NZ': 'New Zealand', 'KR': 'Korea', 'ID': 'Indonesia', 'BR': 'Brazil',
  'AE': 'UAE', 'CH': 'Switzerland', 'ES': 'Spain', 'ZA': 'South Africa', 'PH': 'Philippines', 'MX': 'Mexico',
  'IT': 'Italy', 'SG': 'Singapore', 'FR': 'France', 'NL': 'Netherlands', 'PT': 'Portugal', 'TR': 'Turkey',
  'SE': 'Sweden', 'NO': 'Norway', 'DK': 'Denmark', 'FI': 'Finland', 'PL': 'Poland', 'AT': 'Austria',
  'BE': 'Belgium', 'IE': 'Ireland', 'GR': 'Greece', 'EG': 'Egypt', 'IL': 'Israel', 'AR': 'Argentina',
  'CL': 'Chile', 'CO': 'Colombia', 'PE': 'Peru', 'KH': 'Cambodia', 'MM': 'Myanmar', 'LA': 'Laos',
  'BD': 'Bangladesh', 'PK': 'Pakistan', 'LK': 'Sri Lanka', 'NP': 'Nepal', 'MN': 'Mongolia', 'KZ': 'Kazakhstan',
  'QA': 'Qatar', 'KW': 'Kuwait', 'JO': 'Jordan', 'LB': 'Lebanon', 'IR': 'Iran', 'KE': 'Kenya', 'NG': 'Nigeria',
  'MA': 'Morocco', 'BN': 'Brunei', 'MU': 'Mauritius', 'HU': 'Hungary', 'CZ': 'Czechia', 'UA': 'Ukraine',
};

/// 附近城市（不需定位）：真太陽時設定的城市優先，再依手機地區、時區（經度約＝時差×15°）排序。
List<City> nearbyCities({int max = 8}) {
  final tzLon = DateTime.now().timeZoneOffset.inMinutes / 60 * 15;
  final country = _region[PlatformDispatcher.instance.locale.countryCode?.toUpperCase()];
  double dist(City c) => ((c.longitude - tzLon + 540) % 360 - 180).abs();
  final pool = kCities.where((c) => country != null ? c.country == country : dist(c) <= 12).toList()
    ..sort((a, b) => dist(a).compareTo(dist(b)));
  if (pool.isEmpty) pool.addAll([...kCities]..sort((a, b) => dist(a).compareTo(dist(b))));
  final solar = AppSettings.instance.solarCity;
  return [if (solar != null) solar, ...pool.where((c) => c != solar)].take(max).toList();
}

/// 選城市（附近城市一點即可，或輸入名稱搜尋），回傳座標；取消或查不到回傳 null。
Future<Place?> pickCity(BuildContext context) => showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CitySheet(),
    );

class _CitySheet extends StatefulWidget {
  const _CitySheet();

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  final _ctl = TextEditingController();
  final _near = nearbyCities();
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _city(City c) async {
    setState(() => _busy = true);
    final r = await AddressSearch.search('${c.en}, ${c.country}');
    if (!mounted) return;
    setState(() => _busy = false);
    // 取經度和城市表相符的結果（避免同名城市）
    final hit = r.where((p) => ((p.lon - c.longitude + 540) % 360 - 180).abs() < 2).firstOrNull;
    if (hit == null) return _failed();
    Navigator.of(context).pop(Place(hit.lat, hit.lon, c.name(L10n.language.code)));
  }

  Future<void> _search() async {
    final q = _ctl.text.trim();
    if (q.isEmpty) return;
    final p = await findPlace(context, q);
    if (!mounted) return;
    if (p == null) return;
    Navigator.of(context).pop(p);
  }

  void _failed() =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.compassCityFailed)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language.code;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.compassPickCity, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l.compassNearbyCities, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final c in _near)
                ActionChip(label: Text(c.name(lang)), onPressed: _busy ? null : () => _city(c)),
            ]),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            const SizedBox(height: 12),
            TextField(
              controller: _ctl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.compassCityHint,
                isDense: true,
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _busy ? null : _search),
              ),
              onSubmitted: (_) => _search(),
            ),
          ]),
        ),
      ),
    );
  }
}
