import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/links.dart';
import '../../l10n/l10n.dart';

/// 分享面板在 iPad 上要知道從哪裡彈出；手機上不影響。
Rect? _origin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

void _failed(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.shareFailed)));

/// 推薦給朋友：一段文字＋商店連結。
Future<void> shareApp(BuildContext context) async {
  final l = context.l10n;
  try {
    await SharePlus.instance.share(ShareParams(text: l.shareAppText(storeUrl), sharePositionOrigin: _origin(context)));
  } catch (_) {
    if (context.mounted) _failed(context);
  }
}
