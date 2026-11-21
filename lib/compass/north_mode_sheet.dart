import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'building_facing.dart';
import 'building_page.dart';

/// 羅盤北方基準的三選項：每項一行說明，旁邊「?」展開詳細；建築座向下方管理地點。
/// 回傳選定的模式（選建築座向時保證已有選定地點），關閉回傳 null。
Future<NorthMode?> showNorthModeSheet(BuildContext context, NorthMode current) => showModalBottomSheet<NorthMode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NorthModeSheet(current: current),
    );

/// 新增一個地點並設為選定；取消回傳 null。
Future<BuildingFacing?> addBuilding(BuildContext context) async {
  final b = await Navigator.of(context).push(MaterialPageRoute<BuildingFacing>(builder: (_) => const BuildingFacingPage()));
  if (b == null) return null;
  final list = await BuildingStore.load();
  await BuildingStore.save([...list, b]);
  await BuildingStore.select(b.id);
  return b;
}

class _NorthModeSheet extends StatefulWidget {
  const _NorthModeSheet({required this.current});

  final NorthMode current;

  @override
  State<_NorthModeSheet> createState() => _NorthModeSheetState();
}

class _NorthModeSheetState extends State<_NorthModeSheet> {
  final _open = <NorthMode>{};
  List<BuildingFacing> _list = const [];
  String? _sel;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await BuildingStore.load();
    var sel = await BuildingStore.selected();
    if (list.isNotEmpty && !list.any((b) => b.id == sel)) {
      sel = list.first.id;
      await BuildingStore.select(sel);
    }
    if (mounted) setState(() {
      _list = list;
      _sel = sel;
    });
  }

  Future<void> _pick(NorthMode m) async {
    if (m == NorthMode.building && _list.isEmpty) {
      final b = await addBuilding(context);
      if (b == null || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop(m);
  }

  Future<void> _edit(BuildingFacing b) async {
    final e = await Navigator.of(context).push(MaterialPageRoute<BuildingFacing>(builder: (_) => BuildingFacingPage(existing: b)));
    if (e == null) return;
    await BuildingStore.save([for (final x in _list) x.id == e.id ? e : x]);
    await _reload();
  }

  Future<void> _delete(BuildingFacing b) async {
    await BuildingStore.save([for (final x in _list) if (x.id != b.id) x]);
    if (_sel == b.id) await BuildingStore.select(null);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final items = [
      (NorthMode.trueNorth, l.compassTrueNorthRecommended, l.compassNorthTrueDesc, l.compassNorthTrueMore),
      (NorthMode.magnetic, l.compassMagneticNorth, l.compassNorthMagDesc, l.compassNorthMagMore),
      (NorthMode.building, l.compassBuilding, l.compassNorthBuildingDesc, l.compassNorthBuildingMore),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.compassNorthBase, style: theme.textTheme.titleMedium),
          ),
          RadioGroup<NorthMode>(
            groupValue: widget.current,
            onChanged: (m) => m == null ? null : _pick(m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (mode, title, desc, more) in items) ...[
            RadioListTile<NorthMode>(
              value: mode,
              title: Text(title),
              subtitle: Text(desc),
              secondary: IconButton(
                icon: Icon(_open.contains(mode) ? Icons.expand_less : Icons.help_outline),
                tooltip: '?',
                onPressed: () => setState(() => _open.contains(mode) ? _open.remove(mode) : _open.add(mode)),
              ),
            ),
            if (_open.contains(mode))
              Padding(
                padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                child: Text(more, style: theme.textTheme.bodySmall),
              ),
          ],
            ]),
          ),
          // 建築座向的地點
          if (_list.isNotEmpty) ...[
            const Divider(),
            for (final b in _list)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 56, right: 8),
                leading: Icon(b.id == _sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: b.id == _sel ? theme.colorScheme.primary : null),
                title: Text(b.name),
                subtitle: Text(l.buildingWall(b.wall.round())),
                onTap: () async {
                  await BuildingStore.select(b.id);
                  if (context.mounted) Navigator.of(context).pop(NorthMode.building);
                },
                trailing: PopupMenuButton<int>(
                  onSelected: (v) => v == 0 ? _edit(b) : _delete(b),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(l.buildingEdit)),
                    PopupMenuItem(value: 1, child: Text(l.buildingDelete)),
                  ],
                ),
              ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 56),
              child: TextButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(l.buildingAdd),
                onPressed: () async {
                  final b = await addBuilding(context);
                  if (b != null && context.mounted) Navigator.of(context).pop(NorthMode.building);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
