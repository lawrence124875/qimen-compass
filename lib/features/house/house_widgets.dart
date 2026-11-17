import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../compass/compass_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import 'heading_tracker.dart';
import 'house_geometry.dart';

/// 「坎1・北」。
String palaceLabel(BuildContext context, int p) => '${palaceNames[p]}$p・${context.l10n.palaceDirection(p)}';

/// 疊在圖上的一宮資訊。
class SectorLabel {
  const SectorLabel(this.title, this.sub, this.subColor);
  final String title, sub;
  final Color subColor;
}

/// 依盤面產生各宮標籤（宮名＋八門，門依吉平凶上色）。
Map<int, SectorLabel> sectorLabels(BuildContext context, QimenChart? chart) {
  final qm = context.qm;
  return {
    for (final p in palaceRing)
      p: SectorLabel('${palaceNames[p]}$p', chart?[p].door?.zh ?? '', chart?[p].door == null ? qm.textMuted : qm.luck(chart![p].door!.luck)),
  };
}

class PlanShape {
  const PlanShape(this.name, {this.rect, this.pin, this.selected = false});
  final String name;
  final Rect? rect;
  final Offset? pin;
  final bool selected;
}

/// 平面圖（或無圖時的方位圖）上的九宮扇區、房間、中心、北方指示。座標為平面圖單位，[scale] 換成像素。
class SectorPainter extends CustomPainter {
  SectorPainter({
    required this.bounds,
    required this.center,
    required this.centerR,
    required this.upBearing,
    required this.scale,
    required this.labels,
    required this.colors,
    this.shapes = const [],
    this.pointer,
    this.highlight,
    this.drawBounds = true,
    this.fillRooms = true,
  });

  final Rect bounds;
  final Offset center;
  final double centerR, upBearing, scale;
  final Map<int, SectorLabel> labels;
  final QmPalette colors;
  final List<PlanShape> shapes;

  /// 手機目前指向（方位角），畫一條指示線。
  final double? pointer;

  /// 要強調的宮。
  final int? highlight;
  final bool drawBounds, fillRooms;

  Offset _px(Offset p) => p * scale;

  void _text(Canvas canvas, String s, Offset at, TextStyle style, {bool box = false}) {
    if (s.isEmpty) return;
    _span(canvas, TextSpan(text: s, style: style), at, box: box);
  }

  void _span(Canvas canvas, InlineSpan span, Offset at, {bool box = false}) {
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr, textAlign: TextAlign.center)
      ..layout(maxWidth: 160);
    final o = at - Offset(tp.width / 2, tp.height / 2);
    if (box) {
      canvas.drawRRect(RRect.fromRectAndRadius((o & tp.size).inflate(3), const Radius.circular(4)),
          Paint()..color = colors.background.withValues(alpha: 0.78));
    }
    tp.paint(canvas, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final q = colors;
    final b = Rect.fromLTRB(bounds.left * scale, bounds.top * scale, bounds.right * scale, bounds.bottom * scale);
    canvas.save();
    canvas.clipRect(b);
    final c = _px(center);
    final cr = centerR * scale;

    // 強調宮
    if (highlight != null && highlight != 5) {
      final mid = palaceBearing[highlight]!;
      final path = Path()..moveTo(c.dx, c.dy);
      for (var a = mid - 22.5; a <= mid + 22.51; a += 2.5) {
        path.lineTo(c.dx + planDirection(a, upBearing).dx * 4000, c.dy + planDirection(a, upBearing).dy * 4000);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = q.primary.withValues(alpha: 0.16));
    }

    // 房間
    final roomFill = Paint()..color = q.card.withValues(alpha: fillRooms ? 0.85 : 0.0);
    final roomLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = q.border;
    final selLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = q.primary;
    final nameStyle = TextStyle(color: q.text, fontSize: 12, fontFamily: kSans, fontFamilyFallback: kFontFallback);
    for (final s in shapes) {
      if (s.rect != null) {
        final r = Rect.fromLTRB(s.rect!.left * scale, s.rect!.top * scale, s.rect!.right * scale, s.rect!.bottom * scale);
        canvas.drawRect(r, roomFill);
        canvas.drawRect(r, s.selected ? selLine : roomLine);
        if (s.selected) canvas.drawCircle(r.bottomRight, 9, Paint()..color = q.primary);
      }
    }

    // 扇區線
    final ray = Paint()
      ..color = q.primary.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    for (var k = 0; k < 8; k++) {
      final d = planDirection(22.5 + 45 * k, upBearing);
      final len = rayToBounds(center, d, bounds) * scale;
      if (len > cr) canvas.drawLine(c + d * cr, c + d * len, ray);
    }
    canvas.drawCircle(c, cr, Paint()
      ..style = PaintingStyle.stroke
      ..color = q.primary.withValues(alpha: 0.75)
      ..strokeWidth = 1.2);

    // 宮標籤
    final titleStyle = serif(TextStyle(color: q.text, fontSize: 13, fontWeight: FontWeight.w700));
    for (final e in labels.entries) {
      final d = planDirection(palaceBearing[e.key]!, upBearing);
      final len = rayToBounds(center, d, bounds) * scale;
      final at = c + d * math.max(cr + 22, len * 0.78);
      final l = e.value;
      _span(canvas, TextSpan(style: titleStyle.copyWith(height: 1.2), children: [
        TextSpan(text: l.title),
        if (l.sub.isNotEmpty) TextSpan(text: '\n${l.sub}', style: TextStyle(color: l.subColor)),
      ]), at, box: true);
    }

    // 房間名稱與標記點
    for (final s in shapes) {
      if (s.rect != null) {
        _text(canvas, s.name, _px(s.rect!.center), nameStyle, box: true);
      } else if (s.pin != null) {
        final p = _px(s.pin!);
        canvas.drawCircle(p, s.selected ? 8 : 6, Paint()..color = s.selected ? q.accent : q.primary);
        _text(canvas, s.name, p + const Offset(0, 16), nameStyle, box: true);
      }
    }

    // 中心
    final cp = Paint()
      ..color = q.bad
      ..strokeWidth = 2;
    canvas.drawLine(c - const Offset(8, 0), c + const Offset(8, 0), cp);
    canvas.drawLine(c - const Offset(0, 8), c + const Offset(0, 8), cp);

    // 手機指向
    if (pointer != null) {
      final d = planDirection(pointer!, upBearing);
      final len = rayToBounds(center, d, bounds) * scale;
      canvas.drawLine(c, c + d * len, Paint()
        ..color = q.accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round);
    }
    canvas.restore();

    if (drawBounds) {
      canvas.drawRect(b, Paint()
        ..style = PaintingStyle.stroke
        ..color = q.border
        ..strokeWidth = 1.5);
    }

    // 北方指示（右上角）
    final nc = Offset(b.right - 22, b.top + 24);
    final nd = planDirection(0, upBearing);
    final tip = nc + nd * 14, tail = nc - nd * 10;
    final side = Offset(-nd.dy, nd.dx) * 6;
    canvas.drawCircle(nc, 18, Paint()..color = q.background.withValues(alpha: 0.8));
    canvas.drawPath(Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tail + side).dx, (tail + side).dy)
      ..lineTo((tail - side).dx, (tail - side).dy)
      ..close(), Paint()..color = q.bad);
  }

  @override
  bool shouldRepaint(covariant SectorPainter old) => true;
}

/// 無平面圖時的方位圖：北在上，羅盤標記的房間依方位排在圓周上。
class BearingWheel extends StatelessWidget {
  const BearingWheel({super.key, required this.labels, this.rooms = const [], this.pointer, this.highlight});

  final Map<int, SectorLabel> labels;

  /// （名稱, 方位角；null＝中心）
  final List<(String, double?)> rooms;
  final double? pointer;
  final int? highlight;

  static const _size = 12.0;

  @override
  Widget build(BuildContext context) {
    const c = Offset(_size / 2, _size / 2);
    // 同一宮多個房間時錯開半徑
    final count = <int, int>{};
    final shapes = <PlanShape>[];
    for (final (name, b) in rooms) {
      if (b == null) {
        shapes.add(PlanShape(name, pin: c + Offset(0, 0.8 + 0.9 * (count[5] = (count[5] ?? -1) + 1))));
        continue;
      }
      final p = palaceAtBearing(b);
      final i = count[p] = (count[p] ?? -1) + 1;
      shapes.add(PlanShape(name, pin: c + planDirection(b, 0) * (3.4 - 0.9 * (i % 3))));
    }
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) => CustomPaint(
          painter: SectorPainter(
            bounds: const Rect.fromLTWH(0, 0, _size, _size),
            center: c,
            centerR: 1.5,
            upBearing: 0,
            scale: box.maxWidth / _size,
            labels: labels,
            colors: context.qm,
            shapes: shapes,
            pointer: pointer,
            highlight: highlight,
          ),
        ),
      ),
    );
  }
}

/// 方位狀態與室內鎖定：顯示目前方位、宮位、磁場提醒，提供鎖定按鈕。
class HeadingPanel extends StatelessWidget {
  const HeadingPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = HeadingTracker.instance;
    final l = context.l10n;
    final theme = Theme.of(context);
    final qm = context.qm;
    return ListenableBuilder(
      listenable: t,
      builder: (context, _) {
        final h = t.heading;
        final notes = <String>[
          if (t.noSensor) l.compassNoSensor,
          if (!t.locked && t.field.status == FieldStatus.outOfRange) l.compassInterference(t.field.strength?.round() ?? 0),
          if (!t.locked && t.field.status == FieldStatus.unstable) l.compassUnstable,
          if (t.tilt > 25) l.compassKeepFlat,
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(
            h == null ? l.compassWaiting : l.houseFacingNow('${h.round() % 360}', palaceLabel(context, palaceAtBearing(h))),
            textAlign: TextAlign.center,
            style: serif(compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge).copyWith(color: qm.primary),
          ),
          for (final n in notes)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(n, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.compassLock),
            subtitle: Text(t.locked ? l.compassLockOn : l.compassLockHint),
            value: t.locked,
            onChanged: h == null && !t.locked ? null : (on) => on ? t.lock() : t.unlock(),
          ),
        ]);
      },
    );
  }
}

/// 量一個方位：顯示即時方位，按「記錄」回傳方位角。
Future<double?> measureBearing(BuildContext context, {required String title, required String hint}) {
  return showDialog<double>(
    context: context,
    builder: (context) => _MeasureDialog(title: title, hint: hint),
  );
}

class _MeasureDialog extends StatefulWidget {
  const _MeasureDialog({required this.title, required this.hint});
  final String title, hint;

  @override
  State<_MeasureDialog> createState() => _MeasureDialogState();
}

class _MeasureDialogState extends State<_MeasureDialog> {
  final _t = HeadingTracker.instance;

  @override
  void initState() {
    super.initState();
    _t.acquire();
  }

  @override
  void dispose() {
    _t.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.hint, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const HeadingPanel(compact: true),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.houseCancel)),
        ListenableBuilder(
          listenable: _t,
          builder: (context, _) => FilledButton(
            onPressed: _t.heading == null ? null : () => Navigator.pop(context, _t.heading),
            child: Text(l.houseRecord),
          ),
        ),
      ],
    );
  }
}

/// 房間名稱：常用名稱一鍵選，或自己輸入。
Future<String?> askRoomName(BuildContext context, {String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  final l = context.l10n;
  final presets = l.houseRoomPresets.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.houseRoomName),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in presets) ActionChip(label: Text(p), onPressed: () => Navigator.pop(context, p)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: initial.isNotEmpty,
            decoration: InputDecoration(hintText: l.houseRoomCustom),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.houseCancel)),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text(l.houseOk)),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}
