import 'package:flutter/material.dart';

import '../compass/compass_page.dart';
import '../features/map/map_page.dart';
import '../l10n/l10n.dart';
import 'services.dart';

/// 羅盤分頁：羅盤⇄地圖用標題列的切換鈕放在同一頁（地圖內可搜尋目的地、查吉凶）。
/// 切到地圖時拆掉羅盤（停感測器），反之亦然。
class CompassTab extends StatefulWidget {
  const CompassTab({super.key});

  @override
  State<CompassTab> createState() => _CompassTabState();
}

class _CompassTabState extends State<CompassTab> {
  bool _map = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!AppServices.of(context).featureEnabled('map')) return const CompassPage();
    final toggle = SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(value: false, icon: const Icon(Icons.explore_outlined, size: 18), label: Text(l.tabCompass)),
        ButtonSegment(value: true, icon: const Icon(Icons.map_outlined, size: 18), label: Text(l.modeMap)),
      ],
      selected: {_map},
      onSelectionChanged: (v) => setState(() => _map = v.first),
    );
    return _map ? MapPage(modeSwitch: toggle) : CompassPage(modeSwitch: toggle);
  }
}
