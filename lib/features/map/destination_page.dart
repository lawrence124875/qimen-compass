import 'package:flutter/material.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/share_capture.dart';
import '../../app/widgets/share_card.dart';
import '../../compass/compass_math.dart';
import '../../compass/geo_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../core/records/record_store.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/usage_gate.dart';
import '../../shared/widgets/result_card.dart';
import '../records/record_actions.dart';
import '../travel/travel_text.dart';
import 'map_location.dart';

/// 目的地吉凶（HANDOFF §12 P2）：起點→目的地的真北方位角落在哪一宮，
/// 列出現在與接下來 12 個時辰往該方位的吉凶，挑出較好的出發時段。
class DestinationPage extends StatefulWidget {
  const DestinationPage({super.key, required this.from, required this.to, this.name, this.locked = false});

  /// 免費版體驗過後：只給現在往該方位的吉凶，較好時段與接下來 12 個時辰要訂閱。
  final bool locked;

  final (double, double) from, to;
  final String? name;

  @override
  State<DestinationPage> createState() => _DestinationPageState();
}

class _DestinationPageState extends State<DestinationPage> {
  final _shareKey = GlobalKey();
  late bool _locked = widget.locked;

  @override
  Widget build(BuildContext context) {
    final from = widget.from, to = widget.to, name = widget.name;
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
    final chart = const ShiJiaEngine().compute(now, settings: settings.timeSettingsAt(now), method: settings.juMethod);
    final goodDirs = [
      for (final d in const [Door.kai, Door.xiu, Door.sheng])
        if (chart.palaceOfDoor(d) != 5) '${QimenTerms.door(d, lang)} ${TravelText.direction(l, chart.palaceOfDoor(d))}',
    ].join(l.separator);
    String range(DirectionVerdict v) {
      String hm(DateTime t) => '${t.toLocal().hour.toString().padLeft(2, '0')}:${t.toLocal().minute.toString().padLeft(2, '0')}';
      return '${hm(v.startUtc!)}–${hm(v.endUtc!)}';
    }

    Widget verdictRow(DirectionVerdict v, {bool bold = false}) => ListTile(
          dense: true,
          title: Text(range(v), style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          subtitle: Text([
            if (v.door != null) QimenTerms.door(v.door!, lang),
            ...v.flags.map((f) => TravelText.flag(l, f)),
          ].join(l.separator)),
          trailing: ToneBadge(tone: toneOfLevel(v.level), label: TravelText.level(l, v.level)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.destTitle), actions: [
        IconButton(
          icon: const Icon(Icons.bookmark_add_outlined),
          tooltip: l.recordSaveTitle,
          onPressed: () => saveRecord(context,
              kind: RecordKind.travel,
              chartAt: now,
              summary: [
                if (name != null && name.isNotEmpty) name,
                TravelText.direction(l, palace),
                TravelText.level(l, cur.level),
              ].join(l.separator)),
        ),
        IconButton(
          icon: const Icon(Icons.ios_share),
          tooltip: l.homeShare,
          onPressed: () => shareBoundary(_shareKey, text: '${l.appTitle}・${l.destTitle}', fileName: 'qimen_destination.png'),
        ),
      ]),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          ShareCardFrame(
            boundaryKey: _shareKey,
            child: Column(children: [
                if (name != null && name.isNotEmpty) Text(name, style: text.titleMedium, textAlign: TextAlign.center),
                Text(l.mapPinInfo(TravelText.direction(l, palace), '${bearing.round()}', distanceText(dist)),
                    style: text.bodyMedium?.copyWith(color: qm.textMuted)),
                Text(l.destPalace(QimenTerms.palace(palace, lang)), style: text.bodySmall?.copyWith(color: qm.textMuted), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ResultCard(
                  margin: EdgeInsets.zero,
                  tone: toneOfLevel(cur.level),
                  grade: TravelText.level(l, cur.level),
                  kicker: l.destNow,
                  headline: cur.recommended
                      ? l.resultGoNow(TravelText.direction(l, palace))
                      : _locked
                          ? (best.isNotEmpty ? l.destLockedLater : l.destNoneGood)
                          : best.isNotEmpty
                          ? l.resultGoAt(range(best.first).split('–').first, TravelText.direction(l, palace))
                          : l.destNoneGood,
                  meta: [
                    [
                      if (cur.door != null) '${QimenTerms.door(cur.door!, lang)} ${l.luck(cur.door!.luck)}',
                      ...cur.flags.map((f) => TravelText.flag(l, f)),
                    ].join(l.separator),
                    if (best.isNotEmpty && !_locked) l.labelValue(l.destBest, best.map(range).join(l.separator)),
                  ],
                ),
              ]),
          ),
          const SizedBox(height: 12),
          if (!cur.recommended) ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.destRemedyTitle, style: text.titleSmall?.copyWith(color: qm.primary)),
                  const SizedBox(height: 6),
                  Text(l.destRemedyBody(goodDirs), style: text.bodyMedium),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_locked)
            PremiumLockCard(feature: 'destination', text: l.destLocked, onUnlocked: () => setState(() => _locked = false))
          else
            DetailsFold(children: [
            Text(l.destBest, style: text.titleSmall?.copyWith(color: qm.primary)),
            if (best.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(l.destNoneGood))
            else
              for (final v in best) verdictRow(v, bold: true),
            const Divider(),
            Text(l.destNext, style: text.titleSmall?.copyWith(color: qm.primary)),
            for (final v in slots.skip(1)) verdictRow(v),
          ]),
          const SizedBox(height: 12),
          Text(l.mapTrueNorthNote, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          Text(l.homeDisclaimer, style: text.bodySmall?.copyWith(color: qm.textMuted)),
        ]),
      ),
    );
  }
}
