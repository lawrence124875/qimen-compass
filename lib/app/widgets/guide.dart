import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';

/// 引導的一頁。
class GuidePage {
  const GuidePage({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
}

/// 首次進功能顯示 3 頁引導；右上 ⓘ 可重看（比照謙卦）。
/// [id] 用來記錄是否看過；[force] 為 true 時不論是否看過都顯示。
Future<void> showGuide(BuildContext context, String id, List<GuidePage> pages, {bool force = false}) async {
  final s = AppSettings.instance;
  if (!force && s.guideSeen(id)) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GuideDialog(pages: pages),
  );
  s.markGuideSeen(id);
}

class _GuideDialog extends StatefulWidget {
  const _GuideDialog({required this.pages});
  final List<GuidePage> pages;

  @override
  State<_GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<_GuideDialog> {
  final _ctrl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final last = _i == widget.pages.length - 1;
    return Dialog(
      backgroundColor: qm.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.guideSkip)),
            ),
            Flexible(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _i = i),
                children: [
                  for (final p in widget.pages)
                    SingleChildScrollView(
                      child: Column(children: [
                        Icon(p.icon, size: 56, color: qm.primary),
                        const SizedBox(height: 16),
                        Text(p.title, textAlign: TextAlign.center, style: serif(text.titleLarge).copyWith(color: qm.text)),
                        const SizedBox(height: 12),
                        Text(p.body, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: qm.textMuted, height: 1.6)),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < widget.pages.length; k++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: k == _i ? qm.primary : qm.border),
                ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: last
                    ? () => Navigator.of(context).pop()
                    : () => _ctrl.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: Text(last ? l.guideStart : l.guideNext),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
