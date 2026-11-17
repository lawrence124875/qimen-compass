import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../l10n/l10n.dart';

/// 平面圖照片：拖曳四角對準房子外框（左上、右上、右下、左下），回傳正規化四角。
class PlanCornersPage extends StatefulWidget {
  const PlanCornersPage({super.key, required this.imagePath, required this.corners, required this.imageSize});

  final String imagePath;
  final List<Offset> corners;
  final Size imageSize;

  @override
  State<PlanCornersPage> createState() => _PlanCornersPageState();
}

class _PlanCornersPageState extends State<PlanCornersPage> {
  late List<Offset> _c = [...widget.corners];
  int? _drag;

  /// 讀取照片尺寸（像素）。
  static Future<Size> imageSizeOf(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final img = (await codec.getNextFrame()).image;
    final s = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final iw = widget.imageSize.width, ih = widget.imageSize.height;
    return Scaffold(
      appBar: AppBar(title: Text(l.houseCornersTitle), actions: [
        TextButton(
          onPressed: () => setState(() => _c = const [Offset(0.08, 0.08), Offset(0.92, 0.08), Offset(0.92, 0.92), Offset(0.08, 0.92)]),
          child: Text(l.houseReset),
        ),
      ]),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(l.houseCornersHint, textAlign: TextAlign.center, style: TextStyle(color: qm.textMuted)),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              // BoxFit.contain 的顯示區域
              final s = (box.maxWidth / iw) < (box.maxHeight / ih) ? box.maxWidth / iw : box.maxHeight / ih;
              final dw = iw * s, dh = ih * s;
              final o = Offset((box.maxWidth - dw) / 2, (box.maxHeight - dh) / 2);
              Offset toPx(Offset n) => o + Offset(n.dx * dw, n.dy * dh);
              Offset toN(Offset px) => Offset(((px.dx - o.dx) / dw).clamp(0.0, 1.0), ((px.dy - o.dy) / dh).clamp(0.0, 1.0));
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  var best = 0;
                  for (var i = 1; i < 4; i++) {
                    if ((toPx(_c[i]) - d.localPosition).distance < (toPx(_c[best]) - d.localPosition).distance) best = i;
                  }
                  _drag = (toPx(_c[best]) - d.localPosition).distance < 60 ? best : null;
                },
                onPanUpdate: (d) {
                  final i = _drag;
                  if (i == null) return;
                  setState(() => _c[i] = toN(d.localPosition));
                },
                onPanEnd: (_) => _drag = null,
                child: Stack(children: [
                  Positioned(left: o.dx, top: o.dy, width: dw, height: dh, child: Image.file(File(widget.imagePath), fit: BoxFit.fill)),
                  Positioned.fill(child: CustomPaint(painter: _QuadPainter([for (final c in _c) toPx(c)], qm.primary, _drag))),
                ]),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context, _c), child: Text(l.houseNext)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 照片尺寸（給呼叫端用）。
Future<Size> imageSizeOf(String path) => _PlanCornersPageState.imageSizeOf(path);

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.p, this.color, this.active);
  final List<Offset> p;
  final Color color;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addPolygon(p, true);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(p[i], active == i ? 16 : 12, Paint()..color = color.withValues(alpha: 0.35));
      canvas.drawCircle(p[i], 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _QuadPainter old) => true;
}
