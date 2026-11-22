import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../l10n/l10n.dart';

/// 宅盤使用說明：各盤用途、住很久或忘了入住日怎麼看、靜盤定硬體動盤定行為、凶位化解、時盤在家的用法。
class HouseGuidePage extends StatelessWidget {
  const HouseGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final sections = [
      (Icons.layers_outlined, l.houseGuide1T, l.houseGuide1B),
      (Icons.history, l.houseGuide2T, l.houseGuide2B),
      (Icons.home_outlined, l.houseGuide3T, l.houseGuide3B),
      (Icons.healing_outlined, l.houseGuide4T, l.houseGuide4B),
      (Icons.schedule, l.houseGuide5T, l.houseGuide5B),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.houseGuideTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final (icon, title, body) in sections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(icon, color: context.qm.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: serif(theme.textTheme.titleMedium))),
                  ]),
                  const SizedBox(height: 8),
                  Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
