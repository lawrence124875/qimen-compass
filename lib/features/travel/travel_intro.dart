import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// 首次進出行訣的 3 頁引導（比照謙卦；右上 ⓘ 可重看）。
Future<void> showTravelIntro(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _TravelIntro());
}

class _TravelIntro extends StatefulWidget {
  const _TravelIntro();

  @override
  State<_TravelIntro> createState() => _TravelIntroState();
}

class _TravelIntroState extends State<_TravelIntro> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final pages = [
      (Icons.explore_outlined, l.travelIntro1Title, l.travelIntro1Body),
      (Icons.directions_walk, l.travelIntro2Title, l.travelIntro2Body),
      (Icons.notifications_active_outlined, l.travelIntro3Title, l.travelIntro3Body),
    ];
    final last = _page == pages.length - 1;
    return AlertDialog(
      content: SizedBox(
        width: 320,
        height: 260,
        child: PageView(
          controller: _controller,
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            for (final (icon, title, body) in pages)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(body, textAlign: TextAlign.center),
                ],
              ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            for (var i = 0; i < pages.length; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
              ),
            const Spacer(),
            FilledButton(
              onPressed: last
                  ? () => Navigator.of(context).pop()
                  : () => _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              child: Text(last ? l.travelIntroDone : l.travelIntroNext),
            ),
          ],
        ),
      ],
    );
  }
}
