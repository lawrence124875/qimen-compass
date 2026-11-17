import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.settingsAppearance, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.qm.textMuted)),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(l.appearanceSystem)),
                ButtonSegment(value: ThemeMode.light, label: Text(l.appearanceLight)),
                ButtonSegment(value: ThemeMode.dark, label: Text(l.appearanceDark)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.themeMode = v.first,
            ),
          ],
        ),
      ),
    );
  }
}
