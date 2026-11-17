import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../compass/compass_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import 'house_geometry.dart';
import 'house_model.dart';
import 'house_widgets.dart';
import 'plan_corners_page.dart';

/// 平面圖畫布：照片經四角透視校正後鋪滿，或手繪格線；上面疊九宮扇區與房間。
class PlanCanvas extends StatelessWidget {
  const PlanCanvas({super.key, required this.plan, required this.labels, this.selected, this.gestures});

  final FloorPlan plan;
  final Map<int, SectorLabel> labels;
  final PlanRoom? selected;

  /// 由編輯頁包上手勢（參數為每單位像素）。
  final Widget Function(double scale, Widget child)? gestures;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final maxH = box.maxHeight.isFinite ? box.maxHeight : box.maxWidth * 1.4;
      final s = math.min(box.maxWidth / plan.width, maxH / plan.height);
      final w = plan.width * s, h = plan.height * s;
      final qm = context.qm;
      final stack = SizedBox(
        width: w,
        height: h,
        child: ClipRect(
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: qm.card)),
            if (plan.isPhoto && plan.imageW > 0) _rectified(w, h) else Positioned.fill(child: CustomPaint(painter: _GridPainter(s, qm.border))),
            Positioned.fill(
              child: CustomPaint(
                painter: SectorPainter(
                  bounds: plan.bounds,
                  center: plan.center,
                  centerR: plan.centerR,
                  upBearing: plan.upBearing,
                  scale: s,
                  labels: labels,
                  colors: qm,
                  fillRooms: !plan.isPhoto,
                  shapes: [for (final r in plan.rooms) PlanShape(r.name, rect: r.rect, pin: r.pin, selected: identical(r, selected))],
                ),
              ),
            ),
          ]),
        ),
      );
      return Center(child: gestures == null ? stack : gestures!(s, stack));
    });
  }

  Widget _rectified(double w, double h) {
    final iw = plan.imageW, ih = plan.imageH;
    final src = [for (final c in plan.corners) Offset(c.dx * iw, c.dy * ih)];
    final hm = homography(src, [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)]);
    if (hm == null) return const SizedBox.shrink();
    final m = Matrix4.zero()
      ..setEntry(0, 0, hm[0])
      ..setEntry(0, 1, hm[1])
      ..setEntry(0, 3, hm[2])
      ..setEntry(1, 0, hm[3])
      ..setEntry(1, 1, hm[4])
      ..setEntry(1, 3, hm[5])
      ..setEntry(2, 2, 1)
      ..setEntry(3, 0, hm[6])
      ..setEntry(3, 1, hm[7])
      ..setEntry(3, 3, hm[8]);
    return Positioned(
      left: 0,
      top: 0,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: iw,
        maxWidth: iw,
        minHeight: ih,
        maxHeight: ih,
        child: Transform(
          transform: m,
          child: SizedBox(width: iw, height: ih, child: Image.file(File(plan.imagePath!), fit: BoxFit.fill, gaplessPlayback: true)),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.scale, this.color);
  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 0.6;
    for (var x = 0.0; x <= size.width; x += scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y <= size.height; y += scale) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.scale != scale || old.color != color;
}

enum _Tool { rooms, layout, center, north }

/// 方式二、三：平面圖編輯（照片或手繪）。改動即時存檔（[onChanged]）。
class PlanEditorPage extends StatefulWidget {
  const PlanEditorPage({super.key, required this.plan, required this.chart, required this.onChanged});

  final FloorPlan plan;
  final QimenChart? chart;
  final Future<void> Function() onChanged;

  @override
  State<PlanEditorPage> createState() => _PlanEditorPageState();
}

class _PlanEditorPageState extends State<PlanEditorPage> {
  late _Tool _tool = widget.plan.northSet ? (widget.plan.isPhoto ? _Tool.rooms : _Tool.layout) : _Tool.north;
  PlanRoom? _sel;

  // 拖曳狀態
  PlanRoom? _dragRoom;
  bool _resizing = false;
  Offset? _dragStart;
  Rect? _rectStart;
  Offset? _pinStart;

  FloorPlan get _p => widget.plan;

  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  static double _snap(double v) => (v * 2).roundToDouble() / 2;

  Rect _clampRect(Rect r) {
    final w = r.width.clamp(1.0, _p.width), h = r.height.clamp(1.0, _p.height);
    final l = r.left.clamp(0.0, _p.width - w), t = r.top.clamp(0.0, _p.height - h);
    return Rect.fromLTWH(l, t, w, h);
  }

  Offset _clampPt(Offset o) => Offset(o.dx.clamp(0.0, _p.width), o.dy.clamp(0.0, _p.height));

  PlanRoom? _pinAt(Offset px, double s) {
    for (final r in _p.rooms.reversed) {
      if (r.pin != null && (r.pin! * s - px).distance < 24) return r;
    }
    return null;
  }

  PlanRoom? _rectAt(Offset u) {
    for (final r in _p.rooms.reversed) {
      if (r.rect != null && r.rect!.contains(u)) return r;
    }
    return null;
  }

  Future<void> _editRoom(PlanRoom r) async {
    setState(() => _sel = r);
    final l = context.l10n;
    final act = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(r.name.isEmpty ? l.houseUnnamed : r.name), subtitle: Text(palaceLabel(context, _p.palaceOf(r)))),
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.houseRename), onTap: () => Navigator.pop(context, 'rename')),
          ListTile(leading: const Icon(Icons.delete_outline), title: Text(l.houseDelete), onTap: () => Navigator.pop(context, 'delete')),
        ]),
      ),
    );
    if (!mounted) return;
    if (act == 'rename') {
      final n = await askRoomName(context, initial: r.name);
      if (n != null) {
        r.name = n;
        _changed();
      }
    } else if (act == 'delete') {
      _delete(r);
    }
  }

  void _delete(PlanRoom r) {
    final i = _p.rooms.indexOf(r);
    if (i < 0) return;
    _p.rooms.removeAt(i);
    _sel = null;
    _changed();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.l10n.houseDeleted(r.name)),
        action: SnackBarAction(
          label: context.l10n.houseUndo,
          onPressed: () {
            _p.rooms.insert(i.clamp(0, _p.rooms.length), r);
            _changed();
          },
        ),
      ));
  }

  Future<void> _addRect() async {
    final n = await askRoomName(context);
    if (n == null || !mounted) return;
    final c = _p.bounds.center;
    final r = PlanRoom(n, rect: _clampRect(Rect.fromLTWH(_snap(c.dx - 1.5), _snap(c.dy - 1.5), 3, 3)));
    _p.rooms.add(r);
    _sel = r;
    _changed();
  }

  Future<void> _addPin(Offset u) async {
    final n = await askRoomName(context);
    if (n == null || n.isEmpty || !mounted) return;
    final r = PlanRoom(n, pin: _clampPt(u));
    _p.rooms.add(r);
    _changed();
  }

  void _onTap(Offset px, double s) {
    final u = px / s;
    switch (_tool) {
      case _Tool.rooms:
        final hit = _pinAt(px, s) ?? _rectAt(u);
        if (hit != null) {
          _editRoom(hit);
        } else {
          _addPin(u);
        }
      case _Tool.layout:
        setState(() => _sel = _rectAt(u));
      case _Tool.center:
        _p.manualCenter = _clampPt(u);
        _changed();
      case _Tool.north:
        break;
    }
  }

  void _onPanStart(Offset px, double s) {
    final u = px / s;
    _dragStart = u;
    _dragRoom = null;
    _resizing = false;
    switch (_tool) {
      case _Tool.rooms:
        final r = _pinAt(px, s);
        if (r != null) {
          _dragRoom = r;
          _pinStart = r.pin;
          setState(() => _sel = r);
        }
      case _Tool.layout:
        final sel = _sel;
        if (sel?.rect != null && (sel!.rect!.bottomRight * s - px).distance < 28) {
          _dragRoom = sel;
          _resizing = true;
        } else {
          _dragRoom = _rectAt(u);
          setState(() => _sel = _dragRoom);
        }
        _rectStart = _dragRoom?.rect;
      case _Tool.center:
        _p.manualCenter = _clampPt(u);
        setState(() {});
      case _Tool.north:
        break;
    }
  }

  void _onPanUpdate(Offset px, double s) {
    final u = px / s;
    final d = u - (_dragStart ?? u);
    switch (_tool) {
      case _Tool.rooms:
        if (_dragRoom != null && _pinStart != null) setState(() => _dragRoom!.pin = _clampPt(_pinStart! + d));
      case _Tool.layout:
        final r0 = _rectStart;
        if (_dragRoom == null || r0 == null) return;
        setState(() {
          _dragRoom!.rect = _resizing
              ? _clampRect(Rect.fromLTRB(r0.left, r0.top, math.max(r0.left + 1, r0.right + d.dx), math.max(r0.top + 1, r0.bottom + d.dy)))
              : _clampRect(r0.shift(d));
        });
      case _Tool.center:
        setState(() => _p.manualCenter = _clampPt(u));
      case _Tool.north:
        break;
    }
  }

  void _onPanEnd() {
    final r = _dragRoom;
    if (_tool == _Tool.layout && r?.rect != null) {
      final x = r!.rect!;
      r.rect = _clampRect(Rect.fromLTRB(_snap(x.left), _snap(x.top), _snap(x.right), _snap(x.bottom)));
    }
    _dragRoom = null;
    _changed();
  }

  Future<void> _recorner() async {
    final c = await Navigator.of(context).push<List<Offset>>(MaterialPageRoute(
      builder: (_) => PlanCornersPage(imagePath: _p.imagePath!, corners: _p.corners, imageSize: Size(_p.imageW, _p.imageH)),
    ));
    if (c == null) return;
    _p.corners = c;
    _p.aspect = estimateAspect([for (final o in c) Offset(o.dx * _p.imageW, o.dy * _p.imageH)]);
    _changed();
  }

  Future<void> _measureNorth() async {
    final l = context.l10n;
    final b = await measureBearing(context, title: l.houseNorthMeasure, hint: l.houseNorthMeasureHint);
    if (b == null) return;
    _p.upBearing = b.roundToDouble() % 360;
    _p.northSet = true;
    _changed();
  }

  Widget _toolPanel(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    Text hint(String s) => Text(s, textAlign: TextAlign.center, style: TextStyle(color: qm.textMuted));
    switch (_tool) {
      case _Tool.rooms:
        return hint(l.houseToolRoomsHint);
      case _Tool.layout:
        final sel = _sel?.rect != null ? _sel : null;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          hint(l.houseToolLayoutHint),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(icon: const Icon(Icons.add), onPressed: _addRect, label: Text(l.houseAddRoom)),
            if (sel != null) OutlinedButton(onPressed: () => _editRoom(sel), child: Text(l.houseRename)),
            if (sel != null) OutlinedButton(onPressed: () => _delete(sel), child: Text(l.houseDelete)),
          ]),
          if (_p.isPhoto) ...[
            const SizedBox(height: 8),
            Text(l.houseAspect(_p.aspect.toStringAsFixed(2)), textAlign: TextAlign.center),
            Slider(
              min: 0.3,
              max: 3,
              value: _p.aspect.clamp(0.3, 3),
              onChanged: (v) => setState(() => _p.aspect = v),
              onChangeEnd: (_) => _changed(),
            ),
            TextButton.icon(icon: const Icon(Icons.crop_free), onPressed: _recorner, label: Text(l.houseRecorner)),
          ],
        ]);
      case _Tool.center:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          hint(l.houseToolCenterHint),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton(
              onPressed: _p.manualCenter == null
                  ? null
                  : () {
                      _p.manualCenter = null;
                      _changed();
                    },
              child: Text(l.houseAutoCenter),
            ),
          ),
        ]);
      case _Tool.north:
        final up = _p.upBearing.round() % 360;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          hint(l.houseToolNorthHint),
          const SizedBox(height: 6),
          Text(l.houseUpIs('$up', palaceLabel(context, palaceAtBearing(up.toDouble()))), textAlign: TextAlign.center),
          Slider(
            min: 0,
            max: 359,
            divisions: 359,
            value: up.toDouble(),
            onChanged: (v) => setState(() {
              _p.upBearing = v;
              _p.northSet = true;
            }),
            onChangeEnd: (_) => _changed(),
          ),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(icon: const Icon(Icons.explore_outlined), onPressed: _measureNorth, label: Text(l.houseNorthMeasure)),
            OutlinedButton(
              onPressed: () {
                _p.upBearing = 0;
                _p.northSet = true;
                _changed();
              },
              child: Text(l.houseNorthUp),
            ),
          ]),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = sectorLabels(context, widget.chart);
    final canvas = PlanCanvas(
      plan: _p,
      labels: labels,
      selected: _sel,
      gestures: (s, child) => GestureDetector(
        onTapUp: (d) => _onTap(d.localPosition, s),
        onPanStart: (d) => _onPanStart(d.localPosition, s),
        onPanUpdate: (d) => _onPanUpdate(d.localPosition, s),
        onPanEnd: (_) => _onPanEnd(),
        child: child,
      ),
    );
    final tools = SegmentedButton<_Tool>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: _Tool.rooms, label: Text(l.houseToolRooms)),
        ButtonSegment(value: _Tool.layout, label: Text(l.houseToolLayout)),
        ButtonSegment(value: _Tool.center, label: Text(l.houseToolCenter)),
        ButtonSegment(value: _Tool.north, label: Text(l.houseToolNorth)),
      ],
      selected: {_tool},
      onSelectionChanged: (s) => setState(() {
        _tool = s.first;
        _sel = null;
      }),
    );
    final rooms = [
      for (final r in _p.rooms)
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('${r.name.isEmpty ? l.houseUnnamed : r.name}・${palaceNames[_p.palaceOf(r)]}${_p.palaceOf(r)}'),
        ),
    ];
    final panel = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      tools,
      const SizedBox(height: 10),
      _toolPanel(context),
      if (!_p.northSet) ...[
        const SizedBox(height: 8),
        Text(l.houseNorthNotSet, textAlign: TextAlign.center, style: TextStyle(color: context.qm.bad)),
      ],
      if (rooms.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: rooms),
      ],
    ]);

    return Scaffold(
      appBar: AppBar(title: Text(_p.isPhoto ? l.housePlanPhotoTitle : l.houseSketchTitle)),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 560;
          if (wide) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(12), child: canvas)),
              Expanded(flex: 2, child: ListView(padding: const EdgeInsets.all(12), children: [panel])),
            ]);
          }
          // 直式：畫布固定在上方（不隨捲動，拖曳時不會誤捲），工具在下方可捲動。
          return Column(children: [
            SizedBox(height: math.min(box.maxWidth * 1.1, box.maxHeight * 0.58), child: Padding(padding: const EdgeInsets.all(8), child: canvas)),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 16), children: [panel])),
          ]);
        }),
      ),
    );
  }
}
