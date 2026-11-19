import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// 分享圖卡外框（HANDOFF §12 P3）：直式、固定寬度，上方 App 名稱、下方商店引導與聲明。
/// 包在 RepaintBoundary 裡，用 `shareBoundary` 擷取成 PNG（適合直接發社群短影音的封面）。
class ShareCardFrame extends StatelessWidget {
  const ShareCardFrame({super.key, required this.boundaryKey, required this.child, this.width = 360});

  final GlobalKey boundaryKey;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    return Center(
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: BoxDecoration(
            color: qm.background,
            border: Border.all(color: qm.primary.withValues(alpha: 0.6), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.appTitle, textAlign: TextAlign.center, style: serif(text.titleLarge).copyWith(color: qm.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
            const SizedBox(height: 14),
            Divider(color: qm.border.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 8),
            Text(l.shareCardFooter, textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: qm.primary)),
            Text(l.homeDisclaimer, textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          ]),
        ),
      ),
    );
  }
}
