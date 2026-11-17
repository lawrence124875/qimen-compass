import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// 把 [key] 所在的 RepaintBoundary 存成 PNG 並開系統分享（分享卡片）。
Future<void> shareBoundary(GlobalKey key, {required String text, String fileName = 'qimen.png'}) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) return;
  final file = XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: fileName);
  await SharePlus.instance.share(ShareParams(files: [file], text: text, fileNameOverrides: [fileName]));
}
