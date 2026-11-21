import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../l10n/l10n.dart';
import 'building_facing.dart';
import 'north_mode_sheet.dart';

/// 各功能共用的北方基準選擇：三個按鈕（目前選用的會反白）、這個功能的建議說明、目前模式的一行說明；
/// 「?」開完整說明與地點管理。
/// [onChanged] 的第二個參數為 true 表示使用者剛選了或新增了建築座向地點（[BuildingStore.selected]）。
class NorthModeSelector extends StatelessWidget {
  const NorthModeSelector({super.key, required this.feature, required this.mode, required this.onChanged, this.busy = false});

  final NorthFeature feature;
  final NorthMode mode;
  final Future<void> Function(NorthMode mode, bool placeChosen) onChanged;
  final bool busy;

  Future<void> _tap(BuildContext context, NorthMode m) async {
    if (m == NorthMode.building && (await BuildingStore.load()).isEmpty) {
      if (!context.mounted) return;
      final b = await addBuilding(context);
      if (b == null) return;
      return onChanged(m, true);
    }
    await onChanged(m, false);
  }

  Future<void> _sheet(BuildContext context) async {
    final m = await showNorthModeSheet(context, mode);
    // 關閉時也通知，地點可能被編輯或刪除
    await onChanged(m ?? mode, m == NorthMode.building);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted);
    final rec = switch (feature) {
      NorthFeature.compass => l.northRecCompass,
      NorthFeature.map => l.northRecMap,
      NorthFeature.travel => l.northRecTravel,
      NorthFeature.house => l.northRecHouse,
    };
    String name(NorthMode m) => switch (m) {
          NorthMode.trueNorth => l.compassTrueNorth,
          NorthMode.magnetic => l.compassMagneticNorth,
          NorthMode.building => l.compassBuilding,
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      SegmentedButton<NorthMode>(
        showSelectedIcon: false,
        segments: [
          for (final m in NorthMode.values)
            ButtonSegment(
              value: m,
              label: Text(m == feature.recommended ? '${name(m)}★' : name(m)),
              icon: busy && m == mode ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            ),
        ],
        selected: {mode},
        onSelectionChanged: busy ? null : (v) => _tap(context, v.first),
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                switch (mode) {
                  NorthMode.trueNorth => l.compassNorthTrueDesc,
                  NorthMode.magnetic => l.compassNorthMagDesc,
                  NorthMode.building => l.compassNorthBuildingDesc,
                },
                style: muted,
              ),
              const SizedBox(height: 2),
              Text('★ $rec', style: muted?.copyWith(color: mode == feature.recommended ? null : context.qm.primary)),
            ]),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: l.compassNorthBase,
          onPressed: busy ? null : () => _sheet(context),
        ),
      ]),
    ]);
  }
}
