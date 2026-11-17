import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/chart_board.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import 'divination_content.dart';
import 'divination_journal.dart';
import 'divination_page.dart';

/// 解讀結果：總評、建議、失物方位（羅盤）、判斷依據、其他用神、時盤、聲明、事後回饋。
class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key, required this.content, required this.reading, required this.entry, required this.journal});

  final DivinationContent content;
  final Reading reading;
  final JournalEntry entry;
  final DivinationJournal journal;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  Future<void> _feedback(bool v) async {
    final next = widget.entry.feedback == v ? null : v;
    await widget.journal.setFeedback(widget.entry.id, next);
    if (mounted) setState(() => widget.entry.feedback = next);
  }

  String _plainText(AppLocalizations l) {
    final t = widget.content.text;
    final r = widget.reading;
    final lines = <String>[
      '${l.divTitle}・${t.topicName(r.topic)}',
      if (widget.entry.question.isNotEmpty) widget.entry.question,
      l.divAskedAt(formatAskedAt(widget.entry.askedAt)),
      '${l.divVerdict}：${_levelText(l, r.verdict)}　${t.verdict(r)}',
      '${l.divAdvice}：${t.advice(r)}',
      if (r.rule.direction && r.main.palace != null && r.main.palace != 5) t.lostWhere(r, l.palaceDirection(r.main.palace!)),
      for (final f in r.factors) '・${t.factor(r, f)}',
      if (r.rule.disclaimer) t.disclaimer else l.homeDisclaimer,
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final qm = context.qm;
    final t = widget.content.text;
    final r = widget.reading;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: qm.textMuted);
    final mainPalace = r.main.palace;
    Widget section(String title, List<Widget> children) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(color: qm.primary)),
              const SizedBox(height: 8),
              ...children,
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(t.topicName(r.topic)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: l.divCopy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _plainText(l)));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.divCopied)));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r.rule.disclaimer)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: qm.bad), borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: qm.bad, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(t.disclaimer, style: theme.textTheme.bodySmall)),
              ]),
            ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                VerdictBadge(verdict: r.verdict, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (widget.entry.question.isNotEmpty) Text(widget.entry.question, style: theme.textTheme.titleMedium),
                    Text(l.divAskedAt(formatAskedAt(widget.entry.askedAt)), style: muted),
                    Text('${t.schoolName(r.school)}・${t.yongShen(r.main.spec)}', style: muted),
                    const SizedBox(height: 8),
                    Text(t.verdict(r), style: serif(theme.textTheme.titleMedium).copyWith(color: qm.text)),
                    const SizedBox(height: 6),
                    Text('${l.divAdvice}：${t.advice(r)}'),
                  ]),
                ),
              ]),
            ),
          ),
          if (r.rule.direction) section(l.divLostTitle, [_LostDirection(reading: r, text: t)]),
          section(l.divFactors, [
            for (final f in r.factors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    factorWeight[f]! > 0 ? Icons.add_circle_outline : (factorWeight[f]! < 0 ? Icons.remove_circle_outline : Icons.circle_outlined),
                    size: 16,
                    color: factorWeight[f]! > 0 ? qm.good : (factorWeight[f]! < 0 ? qm.bad : qm.textMuted),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t.factor(r, f))),
                ]),
              ),
          ]),
          if (r.hits.length > 1)
            section(l.divOthers, [
              for (final h in r.hits.skip(1)) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(t.secondary(h))),
              Text(t.secondary(r.self), style: muted),
            ]),
          section(l.divChart, [
            Text('${r.chart.dun.zh}${r.chart.ju}局・${r.chart.yuan.zh}　${r.chart.day}日 ${r.chart.hour}時', style: muted),
            const SizedBox(height: 8),
            ChartBoard(chart: r.chart, highlight: {if (mainPalace != null) mainPalace, if (r.self.palace != null) r.self.palace!}),
          ]),
          section(l.divFeedback, [
            Text(l.divFeedbackHint, style: muted),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: Text(l.divFeedbackHit),
                selected: widget.entry.feedback == true,
                onSelected: (_) => _feedback(true),
              ),
              ChoiceChip(
                label: Text(l.divFeedbackMiss),
                selected: widget.entry.feedback == false,
                onSelected: (_) => _feedback(false),
              ),
            ]),
          ]),
          if (!r.rule.disclaimer)
            Text(l.homeDisclaimer, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: qm.textMuted)),
        ],
      ),
    );
  }
}

String _levelText(AppLocalizations l, Verdict v) => switch (v) {
      Verdict.great => l.levelGreat,
      Verdict.good => l.levelGood,
      Verdict.neutral => l.levelNeutral,
      Verdict.minor => l.levelMinor,
      Verdict.blocked => l.levelBlocked,
    };

/// 失物方位：用神落宮的方向＋指南針箭頭＋可能地點。
class _LostDirection extends StatelessWidget {
  const _LostDirection({required this.reading, required this.text});

  final Reading reading;
  final DivinationText text;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = reading;
    final p = r.main.palace;
    if (p == null) return Text(text.secondary(r.main));
    final cell = r.chart[p];
    final near = r.factors.contains(Factor.sameAsSelf) || r.factors.contains(Factor.fuYin);
    final far = r.factors.contains(Factor.horse) || r.factors.contains(Factor.fanYin);
    final godHint = cell.god == null ? null : text.lostGod(cell.god!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (p == 5)
        Text(l.divLostCenter, textAlign: TextAlign.center, style: theme.textTheme.titleMedium)
      else ...[
        Text(text.lostWhere(r, l.palaceDirection(p)), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        if (near || far)
          Text(near ? text.lostNear : text.lostFar, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Center(child: _CompassArrow(bearing: r.bearing!)),
      ],
      const SizedBox(height: 12),
      if (text.lostPlace(p) != null) Text('・${text.lostPlace(p)}'),
      if (godHint != null) Text('・$godHint'),
    ]);
  }
}

/// 指向失物方位的箭頭（依指南針即時旋轉；沒有磁力計時只顯示方位角）。
class _CompassArrow extends StatelessWidget {
  const _CompassArrow({required this.bearing});

  final double bearing;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snap) {
        final heading = snap.data?.heading;
        final angle = heading == null ? bearing * math.pi / 180 : (bearing - heading) * math.pi / 180;
        return Column(children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: qm.border, width: 2)),
            child: Transform.rotate(
              angle: angle,
              child: Icon(Icons.navigation, size: 88, color: heading == null ? qm.textMuted : qm.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            heading == null ? context.l10n.travelNoCompass(bearing.round()) : context.l10n.travelHeading(heading.round() % 360),
            textAlign: TextAlign.center,
          ),
        ]);
      },
    );
  }
}
