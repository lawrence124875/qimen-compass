import 'package:flutter/material.dart';

import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../settings/app_settings.dart';
import '../settings/cities.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = AppSettings.instance;
    final lang = L10n.language.code;
    Widget header(String t) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.qm.primary)),
        );
    Widget sub(String t) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(t, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
        );
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t, style: Theme.of(context).textTheme.bodyMedium),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            header(l.settingsAppearance),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(l.appearanceSystem)),
                ButtonSegment(value: ThemeMode.light, label: Text(l.appearanceLight)),
                ButtonSegment(value: ThemeMode.dark, label: Text(l.appearanceDark)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.themeMode = v.first,
            ),
            header(l.settingsChart),
            label(l.settingsJuMethod),
            SegmentedButton<JuMethod>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: JuMethod.chaiBu, label: Text(l.juChaiBu)),
                ButtonSegment(value: JuMethod.zhiRun, label: Text(l.juZhiRun)),
              ],
              selected: {s.juMethod},
              onSelectionChanged: (v) => s.juMethod = v.first,
            ),
            sub(s.juMethod == JuMethod.chaiBu ? l.juChaiBuHint : l.juZhiRunHint),
            label(l.settingsZiHour),
            SegmentedButton<ZiHourMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ZiHourMode.nextDay, label: Text(l.ziNextDay)),
                ButtonSegment(value: ZiHourMode.lateZi, label: Text(l.ziLate)),
              ],
              selected: {s.ziHour},
              onSelectionChanged: (v) => s.ziHour = v.first,
            ),
            sub(s.ziHour == ZiHourMode.nextDay ? l.ziNextDayHint : l.ziLateHint),
            label(l.settingsSolarTime),
            DropdownButtonFormField<int>(
              initialValue: s.solarCityIndex,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: [
                DropdownMenuItem(value: -1, child: Text(l.solarTimeOff)),
                for (var i = 0; i < kCities.length; i++)
                  DropdownMenuItem(value: i, child: Text('${kCities[i].name(lang)}（${kCities[i].longitude.toStringAsFixed(1)}°）')),
              ],
              onChanged: (v) => s.solarCityIndex = v ?? -1,
            ),
            sub(l.solarTimeHint),
          ],
        ),
      ),
    );
  }
}
