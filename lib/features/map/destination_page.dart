import 'package:flutter/material.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../compass/compass_math.dart';
import '../../compass/geo_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../travel/travel_text.dart';
import 'map_location.dart';

/// 目的地吉凶（HANDOFF §12 P2）：起點→目的地的真北方位角落在哪一宮，
/// 列出現在與接下來 12 個時辰往該方位的吉凶，挑出較好的出發時段。
class DestinationPage extends StatelessWidget {
  const DestinationPage({super.key, required this.from, required this.to, this.name});

  final (double, double) from, to;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final settings = AppSettings.instance;
    final now = DateTime.now();
    final bearing = bearingTo(from.$1, from.$2, to.$1, to.$2);
    final dist = distanceMeters(from.$1, from.$2, to.$1, to.$2);
    final palace = palaceAtBearing(bearing);
    final slots = const DirectionPlanner().plan(now, palace, settings: settings.timeSettingsAt(now), method: settings.juMethod);
    final cur = slots.first;
    final best = (slots.skip(1).where((s) => s.recommended).toList()..sort((a, b) => b.score.compareTo(a.score))).take(3).toList()
      ..sort((a, b) => a.startUtc!.compareTo(b.startUtc!));
    String range(DirectionVerdict v) {
      String hm(DateTime t) => '${t.toLocal().hour.toString().padLeft(2, '0')}:${t.toLocal().minute.toString().padLeft(2, '0')}';
      return '${hm(v.startUtc!)}–${hm(v.endUtc!)}';
    }

    Color levelColor(TravelLevel v) => switch (v) {
          TravelLevel.great || TravelLevel.good => qm.good,
          TravelLevel.neutral => qm.neutral,
          _ => qm.bad,
        };
    Widget verdictRow(DirectionVerdict v, {bool bold = false}) => ListTile(
          dense: true,
          title: Text(range(v), style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          subtitle: Text([
            if (v.door != null) QimenTerms.door(v.door!, lang),
            ...v.flags.map((f) => TravelText.flag(l, f)),
          ].join(l.separator)),
          trailing: Text(TravelText.level(l, v.level), style: TextStyle(color: levelColor(v.level), fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.destTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (name != null && name!.isNotEmpty) Text(name!, style: text.titleMedium),
          Text(l.mapPinInfo(TravelText.direction(l, palace), '${bearing.round()}', distanceText(dist)),
              style: text.bodyMedium?.copyWith(color: qm.textMuted)),
          Text(l.destPalace(QimenTerms.palace(palace, lang)), style: text.bodySmall?.copyWith(color: qm.textMuted)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(l.destNow, style: text.bodyMedium?.copyWith(color: qm.textMuted)),
                const SizedBox(height: 4),
                Text(TravelText.level(l, cur.level),
                    style: serif(text.headlineMedium).copyWith(color: levelColor(cur.level), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text([
                  if (cur.door != null) '${QimenTerms.door(cur.door!, lang)} ${l.luck(cur.door!.luck)}',
                  ...cur.flags.map((f) => TravelText.flag(l, f)),
                ].join(l.separator), textAlign: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text(l.destBest, style: text.titleSmall?.copyWith(color: qm.primary)),
          if (best.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(l.destNoneGood))
          else
            for (final v in best) verdictRow(v, bold: true),
          const Divider(),
          Text(l.destNext, style: text.titleSmall?.copyWith(color: qm.primary)),
          for (final v in slots.skip(1)) verdictRow(v),
          const SizedBox(height: 12),
          Text(l.mapTrueNorthNote, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          Text(l.homeDisclaimer, style: text.bodySmall?.copyWith(color: qm.textMuted)),
        ]),
      ),
    );
  }
}
