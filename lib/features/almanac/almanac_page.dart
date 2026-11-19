import 'package:flutter/material.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/share_capture.dart';
import '../../app/widgets/share_card.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../shared/widgets/result_card.dart';
import '../travel/travel_text.dart';

DailyAlmanac todayAlmanac([DateTime? date]) {
  final s = AppSettings.instance;
  final now = date ?? DateTime.now();
  return DailyAlmanac.of(now, settings: s.timeSettingsAt(now), method: s.juMethod);
}

Color levelColor(BuildContext context, TravelLevel v) => switch (v) {
      TravelLevel.great || TravelLevel.good => context.qm.good,
      TravelLevel.neutral => context.qm.neutral,
      _ => context.qm.bad,
    };

String fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 此刻頁的小卡：今日吉方＋吉時，點開看全日。
class AlmanacTile extends StatelessWidget {
  const AlmanacTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final a = todayAlmanac();
    final bp = a.bestPalace;
    final best = a.best();
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlmanacPage())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            Icon(Icons.wb_sunny_outlined, color: qm.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.almanacTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: qm.primary)),
                Text(
                  bp == null
                      ? l.almanacNone
                      : l.labelValue(l.almanacBestDir, [TravelText.direction(l, bp), ...best.map(TravelText.timeRange)].join(l.separator)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

/// 今日奇門黃曆：吉方、吉時、全日 12 時辰；可分享成直式圖卡。
class AlmanacPage extends StatefulWidget {
  const AlmanacPage({super.key});

  @override
  State<AlmanacPage> createState() => _AlmanacPageState();
}

class _AlmanacPageState extends State<AlmanacPage> {
  final _key = GlobalKey();
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final a = todayAlmanac(_date);
    final bp = a.bestPalace;
    final best = a.best();
    final now = DateTime.now().toUtc();
    final card = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.almanacTitle, textAlign: TextAlign.center, style: text.titleMedium),
      Text(l.almanacDate(fmtDate(a.date), '${a.day}'), textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: qm.textMuted)),
      const SizedBox(height: 14),
      Text(l.almanacBestDir, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: qm.textMuted)),
      Text(bp == null ? '—' : TravelText.direction(l, bp),
          textAlign: TextAlign.center, style: serif(text.displaySmall).copyWith(color: qm.primary, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Text(l.almanacBestHours, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: qm.textMuted)),
      const SizedBox(height: 4),
      if (best.isEmpty)
        Text(l.almanacNone, textAlign: TextAlign.center)
      else
        for (final s in best)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Center(
              child: ToneLabel(
                tone: toneOfLevel(s.level),
                text: '${TravelText.hourName(l, s)} ${TravelText.timeRange(s)}  ${TravelText.direction(l, s.palace)}・${QimenTerms.doorName(s.door, lang)}  ${TravelText.level(l, s.level)}',
                style: text.bodyLarge,
              ),
            ),
          ),
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(l.almanacTitle), actions: [
        IconButton(
          icon: const Icon(Icons.ios_share),
          tooltip: l.homeShare,
          onPressed: () => shareBoundary(_key, text: '${l.appTitle}・${l.almanacTitle}', fileName: 'qimen_almanac.png'),
        ),
      ]),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _date = _date.subtract(const Duration(days: 1)))),
            TextButton(onPressed: () => setState(() => _date = DateTime.now()), child: Text(fmtDate(_date))),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _date = _date.add(const Duration(days: 1)))),
          ]),
          const SizedBox(height: 8),
          ShareCardFrame(boundaryKey: _key, child: card),
          const SizedBox(height: 16),
          Text(l.almanacAllHours, style: text.titleSmall?.copyWith(color: qm.primary)),
          for (final s in a.slots)
            ListTile(
              dense: true,
              selected: s.contains(now),
              title: Text('${TravelText.hourName(l, s)}  ${TravelText.timeRange(s)}'),
              subtitle: Text('${TravelText.direction(l, s.palace)}・${QimenTerms.door(s.door, lang)}'),
              trailing: ToneBadge(tone: toneOfLevel(s.level), label: TravelText.level(l, s.level)),
            ),
        ]),
      ),
    );
  }
}
