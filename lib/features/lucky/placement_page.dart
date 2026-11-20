import 'package:flutter/material.dart' hide Element;

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/result_card.dart';
import '../house/house_widgets.dart' show palaceLabel;
import '../meaning/meaning_content.dart';
import '../travel/travel_text.dart';

/// 化解建議文字：依門與宮的五行取化解五行，再加平／凶通則與凶星提醒。不需化解時回傳空清單。
List<String> cureLines(AppLocalizations l, MeaningContent? m, Door door, int palace, Tone tone, List<Star> stars) {
  if (m == null) return const [];
  final e = cureElement(door, palace);
  final out = <String?>[
    if (tone == Tone.neutral) m.lookup('curetone', '平'),
    if (tone == Tone.bad) m.lookup('curetone', '凶'),
    if (e != null && tone != Tone.good)
      if (m.lookup('cure', e.zh) case final items?) l.placeCureItems(items),
    for (final s in stars)
      if (cureStars.contains(s)) m.lookup('curestar', s.zh),
  ].whereType<String>().toList();
  return out;
}

/// 化解區塊（結果卡詳解用）。
class CureBlock extends StatelessWidget {
  const CureBlock({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: qm.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.placeCure, style: text.labelLarge?.copyWith(color: qm.primary)),
        for (final s in lines) Text('• $s', style: text.bodySmall?.copyWith(color: qm.text)),
      ]),
    );
  }
}

/// 開運擺件與化解（宅盤內）：年盤九宮為主、本月看月盤；任何空間（辦公室、房間）都能用。
class PlacementPage extends StatefulWidget {
  const PlacementPage({super.key, this.rooms = const {}});

  /// 各宮已標記的房間名稱。
  final Map<int, List<String>> rooms;

  @override
  State<PlacementPage> createState() => _PlacementPageState();
}

class _PlacementPageState extends State<PlacementPage> {
  MeaningContent? _m = MeaningContent.cached;
  late final QimenChart _year, _month;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.instance;
    final now = DateTime.now();
    const e = ShiJiaEngine();
    _year = e.compute(now, settings: s.timeSettingsAt(now), method: s.juMethod, unit: PanUnit.year);
    _month = e.compute(now, settings: s.timeSettingsAt(now), method: s.juMethod, unit: PanUnit.month);
    MeaningContent.load(L10n.language).then((m) {
      if (mounted && m != null) setState(() => _m = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final lang = L10n.language;
    return Scaffold(
      appBar: AppBar(title: Text(l.placeButton)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
          Text(l.placeIntro, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l.cureLevelsTitle, style: text.titleSmall?.copyWith(color: qm.primary)),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(l.cureLevels, style: text.bodySmall)],
          ),
          for (final p in palaceRing) _tile(context, p, l, qm, text, lang),
          const SizedBox(height: 8),
          Text(l.homeDisclaimer, textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: qm.textMuted)),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext context, int p, AppLocalizations l, QmPalette qm, TextTheme text, AppLanguage lang) {
    final pc = _year[p];
    final door = pc.door!;
    final v = DirectionPlanner.judge(_year, p);
    final tone = toneOfLevel(v.level);
    final mv = DirectionPlanner.judge(_month, p);
    final mTone = toneOfLevel(mv.level);
    final mDoor = _month[p].door!;
    final cures = cureLines(l, _m, door, p, tone, pc.stars);
    // 本月轉弱：年盤吉、月盤阻凶時，補上月盤的化解
    final monthCures = tone == Tone.good && mTone == Tone.bad ? cureLines(l, _m, mDoor, p, mTone, const []) : const <String>[];
    final rooms = widget.rooms[p] ?? const [];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(palaceLabel(context, p), style: serif(text.titleMedium).copyWith(color: qm.primary))),
            ToneBadge(tone: tone, label: TravelText.level(l, v.level)),
          ]),
          Text('${QimenTerms.door(door, lang)}${rooms.isEmpty ? '' : l.separator + rooms.join(l.separator)}',
              style: text.bodyMedium?.copyWith(color: tone.color(context), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (_m?.lookup('place', door.zh) case final t?) Text(t, style: text.bodyMedium),
          if (cures.isEmpty && tone == Tone.good)
            Text(l.placeNoCure, style: text.bodySmall?.copyWith(color: qm.textMuted))
          else
            CureBlock(lines: cures),
          const SizedBox(height: 6),
          Text(l.placeMonth(QimenTerms.doorName(mDoor, lang), TravelText.level(l, mv.level)),
              style: text.bodySmall?.copyWith(color: mTone.color(context))),
          if (monthCures.isNotEmpty) CureBlock(lines: monthCures),
        ]),
      ),
    );
  }
}
