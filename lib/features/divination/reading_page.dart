import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../app/services.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/chart_board.dart';
import '../../core/records/record_store.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../shared/widgets/result_card.dart';
import 'divination_content.dart';
import 'divination_journal.dart';
import 'divination_page.dart';

/// 從紀錄重看問事解讀（依起局時間重算）。內容或事類找不到時回傳 false。
Future<bool> openSavedReading(BuildContext context, QimenRecord r) async {
  if (!JournalEntry.isDivination(r)) return false;
  final store = AppServices.of(context).records;
  final content = await DivinationContent.load(L10n.language);
  final entry = JournalEntry(r);
  if (content == null || !content.rules.topics.contains(entry.topic) || !context.mounted) return false;
  final reading = const DivinationEngine().read(
    content.rules,
    entry.topic,
    entry.askedAt,
    school: entry.school,
    settings: TimeSettings(utcOffset: entry.askedAt.timeZoneOffset),
  );
  await Navigator.of(context).push(MaterialPageRoute<void>(
    // 免費版重看紀錄只給等級（避免先存再看完整解讀）
    builder: (_) => ReadingPage(
        content: content, reading: reading, entry: entry, journal: DivinationJournal(store), locked: !AppServices.of(context).isPremium),
  ));
  return true;
}

/// 解讀結果：總評、建議、失物方位（羅盤）、判斷依據、其他用神、時盤、聲明、事後回饋。
class ReadingPage extends StatefulWidget {
  const ReadingPage(
      {super.key, required this.content, required this.reading, required this.entry, required this.journal, this.locked = false});

  final DivinationContent content;
  final Reading reading;
  final JournalEntry entry;
  final DivinationJournal journal;

  /// 免費版體驗過後：只顯示決斷與等級，詳解上鎖。
  final bool locked;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  late bool _locked = widget.locked;

  Future<void> _feedback(bool v) async {
    final next = widget.entry.feedback == v ? null : v;
    await widget.journal.setFeedback(widget.entry, next);
    if (mounted) setState(() {});
  }

  late final Timing? _timing =
      widget.reading.timing(widget.entry.askedAt.toUtc(), TimeSettings(utcOffset: widget.entry.askedAt.toLocal().timeZoneOffset));
  List<String> _dos = const [], _donts = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = context.l10n;
    final t = widget.content.text;
    final r = widget.reading;
    final dos = <String>{}, donts = <String>{};
    for (final k in r.tipKeys) {
      final a = t.tip(k, good: true), b = t.tip(k, good: false);
      if (a != null && dos.length < 3) dos.add(a);
      if (b != null && donts.length < 3) donts.add(b);
    }
    final g = r.goodDirection, a = r.avoidDirection;
    if (g != null) dos.add(l.divGoDir(l.palaceDirection(g)));
    if (a != null && a != g) donts.add(l.divAvoidDir(l.palaceDirection(a)));
    _dos = dos.toList();
    _donts = donts.toList();
  }

  Widget _bullet(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text)),
        ]),
      );

  String _timingText(AppLocalizations l, Timing tm) {
    final d = tm.date;
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final br = tm.branches.map((b) => branchNames[b]).join(l.separator);
    final base = switch (tm.pace) {
      Pace.fast => l.divTimingFast(date, br),
      Pace.medium => l.divTimingMedium(date, br),
      Pace.slow => l.divTimingSlow(date, br),
    };
    return tm.afterEmpty ? '$base${l.divTimingEmpty}' : base;
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
      '${l.divDecision}：${_decisionText(l, r.decision)}（${_confidenceText(l, r.confidence)}）',
      if (_timing != null) '${l.divTimingTitle}：${_timingText(l, _timing!)}',
      for (final s in _dos) '＋ $s',
      for (final s in _donts) '－ $s',
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
    final details = <Widget>[
          if (r.rule.direction && !_locked) section(l.divLostTitle, [_LostDirection(reading: r, text: t)]),
          if (_timing != null) section(l.divTimingTitle, [Text(_timingText(l, _timing!)), const SizedBox(height: 4), Text(l.divTimingNote, style: muted)]),
          if (_dos.isNotEmpty || _donts.isNotEmpty)
            section(l.divDoDont, [
              for (final s in _dos) _bullet(Icons.check_circle_outline, qm.good, s),
              for (final s in _donts) _bullet(Icons.block, qm.bad, s),
            ]),
          if (r.standing != null)
            section(l.divStandingTitle, [
              Text(switch (r.standing!) {
                Standing.selfStronger => l.divStandingSelf,
                Standing.balanced => l.divStandingEven,
                Standing.otherStronger => l.divStandingOther,
              }),
              const SizedBox(height: 4),
              Text(l.divStandingDetail(t.yongShen(r.main.spec)), style: muted),
            ]),
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
            const SizedBox(height: 6),
            Text(
              [
                if (mainPalace != null) l.divMarkYongShen(t.yongShen(r.main.spec), QimenTerms.palace(mainPalace, L10n.language)),
                if (r.self.palace != null) l.divMarkSelf(QimenTerms.palace(r.self.palace!, L10n.language)),
              ].join(l.separator),
              style: muted,
            ),
          ]),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(t.topicName(r.topic)),
        actions: [
          if (!_locked)
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
          ResultCard(
            tone: verdictTone(r.verdict),
            grade: verdictLabel(l, r.verdict),
            kicker: '${l.divDecision}・${l.divConfidence} ${_confidenceText(l, r.confidence)}',
            headline: _decisionText(l, r.decision),
            meta: [
              t.verdict(r),
              if (!_locked) '${l.divAdvice}：${t.advice(r)}',
              if (widget.entry.question.isNotEmpty) widget.entry.question,
              '${l.divAskedAt(formatAskedAt(widget.entry.askedAt))}・${t.schoolName(r.school)}・${t.yongShen(r.main.spec)}',
            ],
          ),
          if (_locked)
            LockedPreview(
              feature: 'divination',
              text: l.divLockedDetail,
              onUnlocked: () => setState(() => _locked = false),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ...details,
              ]),
            )
          else
            DetailsFold(children: [
              ...details,
            ]),
          if (r.standing != null)
            section(l.divStandingTitle, [
              Text(switch (r.standing!) {
                Standing.selfStronger => l.divStandingSelf,
                Standing.balanced => l.divStandingEven,
                Standing.otherStronger => l.divStandingOther,
              }),
              const SizedBox(height: 4),
              Text(l.divStandingDetail(t.yongShen(r.main.spec)), style: muted),
            ]),
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
            const SizedBox(height: 6),
            Text(
              [
                if (mainPalace != null) l.divMarkYongShen(t.yongShen(r.main.spec), QimenTerms.palace(mainPalace, L10n.language)),
                if (r.self.palace != null) l.divMarkSelf(QimenTerms.palace(r.self.palace!, L10n.language)),
              ].join(l.separator),
              style: muted,
            ),
          ]),
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

String _decisionText(AppLocalizations l, Decision d) => switch (d) {
      Decision.go => l.divDecisionGo,
      Decision.goWithCare => l.divDecisionCare,
      Decision.wait => l.divDecisionWait,
      Decision.avoid => l.divDecisionAvoid,
    };

String _confidenceText(AppLocalizations l, Confidence c) => switch (c) {
      Confidence.high => l.divConfidenceHigh,
      Confidence.medium => l.divConfidenceMedium,
      Confidence.mixed => l.divConfidenceMixed,
    };
