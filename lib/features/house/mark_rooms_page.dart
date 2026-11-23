import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_theme.dart';
import '../../compass/compass_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import 'heading_tracker.dart';
import 'house_model.dart';
import 'house_widgets.dart';

/// 方式一：站在房子中心點，手機對準各房間按「標記」，依角度換算宮位（HANDOFF §6）。
class MarkRoomsPage extends StatefulWidget {
  const MarkRoomsPage({super.key, required this.house, required this.chart});

  final House house;
  final QimenChart? chart;

  @override
  State<MarkRoomsPage> createState() => _MarkRoomsPageState();
}

class _MarkRoomsPageState extends State<MarkRoomsPage> {
  final _t = HeadingTracker.instance;
  String? _name;

  /// 盤面跟著手機轉（指針固定朝上）；關掉＝北在上、指針轉。
  bool _rotate = true;
  static const _kRotate = 'qm_house_rotate_board';

  @override
  void initState() {
    super.initState();
    _t.acquire();
    SharedPreferences.getInstance().then((p) {
      final v = p.getBool(_kRotate);
      if (v != null && mounted) setState(() => _rotate = v);
    }).catchError((_) {});
  }

  void _setRotate(bool v) {
    setState(() => _rotate = v);
    SharedPreferences.getInstance().then((p) => p.setBool(_kRotate, v)).catchError((_) => false);
  }

  @override
  void dispose() {
    _t.release();
    super.dispose();
  }

  Future<void> _pickName() async {
    final n = await askRoomName(context, initial: _name ?? '');
    if (n != null && n.isNotEmpty) setState(() => _name = n);
  }

  Future<void> _mark({bool center = false}) async {
    var name = _name;
    if (name == null) {
      name = await askRoomName(context);
      if (name == null || name.isEmpty) return;
    }
    final b = center ? null : _t.heading;
    if (!center && b == null) return;
    setState(() {
      widget.house.marked.add(MarkedRoom(name!, b));
      _name = null;
    });
    await HouseStore.save(widget.house);
    if (!mounted) return;
    final l = context.l10n;
    final p = center ? 5 : palaceAtBearing(b!);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.houseMarked(name, palaceLabel(context, p))), duration: const Duration(seconds: 2)));
  }

  Future<void> _remove(int i) async {
    final r = widget.house.marked.removeAt(i);
    setState(() {});
    await HouseStore.save(widget.house);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.l10n.houseDeleted(r.name)),
        persist: false, // 有按鈕的 SnackBar 預設不會自動消失
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: context.l10n.houseUndo,
          onPressed: () async {
            setState(() => widget.house.marked.insert(i.clamp(0, widget.house.marked.length), r));
            await HouseStore.save(widget.house);
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final theme = Theme.of(context);
    final labels = sectorLabels(context, widget.chart);
    final rooms = widget.house.marked;

    final wheel = ListenableBuilder(
      listenable: _t,
      builder: (context, _) => BearingWheel(
        labels: labels,
        rooms: [for (final r in rooms) (r.name, r.bearing)],
        pointer: _t.heading,
        highlight: _t.heading == null ? null : palaceAtBearing(_t.heading!),
        upBearing: _rotate ? (_t.heading ?? 0) : 0,
      ),
    );

    // 常用操作固定在盤面正下方，不用捲到底
    final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      OutlinedButton.icon(
        icon: const Icon(Icons.edit_outlined),
        onPressed: _pickName,
        label: Text(_name == null ? l.houseChooseRoom : l.houseRoomIs(_name!)),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: ListenableBuilder(
            listenable: _t,
            builder: (context, _) => FilledButton.icon(
              icon: const Icon(Icons.my_location),
              onPressed: _t.heading == null ? null : () => _mark(),
              label: Text(l.houseMarkThis),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () => _mark(center: true), child: Text(l.houseMarkCenter))),
      ]),
    ]);

    final controls = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.houseMarkSteps, style: theme.textTheme.bodyMedium?.copyWith(color: qm.textMuted)),
        ),
      ),
      const SizedBox(height: 8),
      const HeadingPanel(),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.houseRotateBoard),
        subtitle: Text(_rotate ? l.houseRotateBoardOn : l.houseRotateBoardOff),
        value: _rotate,
        onChanged: _setRotate,
      ),
      const SizedBox(height: 4),
      if (rooms.isEmpty)
        Text(l.houseNoRooms, textAlign: TextAlign.center, style: TextStyle(color: qm.textMuted))
      else
        for (var i = 0; i < rooms.length; i++)
          Dismissible(
            key: ObjectKey(rooms[i]),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _remove(i),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: qm.bad.withValues(alpha: 0.25),
              child: const Icon(Icons.delete_outline),
            ),
            child: ListTile(
              dense: true,
              title: Text(rooms[i].name),
              subtitle: Text(rooms[i].bearing == null
                  ? palaceLabel(context, 5)
                  : '${palaceLabel(context, rooms[i].palace)}  ${rooms[i].bearing!.round()}°'),
              trailing: IconButton(icon: const Icon(Icons.close), tooltip: l.houseDelete, onPressed: () => _remove(i)),
            ),
          ),
    ]);

    return Scaffold(
      appBar: AppBar(title: Text(l.houseMarkTitle)),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 560;
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: box.maxHeight - 24, child: wheel),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(children: [
                    actions,
                    const SizedBox(height: 8),
                    Expanded(child: ListView(children: [controls])),
                  ]),
                ),
              ]),
            );
          }
          // 盤面與操作固定在上方，只有說明與已標記清單捲動
          final size = math.min(math.min(box.maxWidth - 24, 420.0), box.maxHeight * 0.42);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Center(child: SizedBox.square(dimension: size, child: wheel)),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: actions),
            const Divider(height: 1),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [controls])),
          ]);
        }),
      ),
    );
  }
}
