import 'package:flutter/material.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../shared/premium/usage_gate.dart';
import '../../shared/widgets/result_card.dart';
import '../meaning/meaning_content.dart';
import '../travel/travel_text.dart';
import 'profile.dart';

/// 本命報告（終身局）：性格（免費）＋今年一句（免費）；事業、財運、感情、六親、大運、關鍵年份（訂閱）。
/// 入口用 [peekPremium]（feature `natal_report`）：免費版第一次完整體驗，之後詳解模糊上鎖。
class NatalReportPage extends StatefulWidget {
  const NatalReportPage({super.key, this.locked = false});

  final bool locked;

  /// 從盤面分頁開啟。
  static Future<void> open(BuildContext context) async {
    final access = await peekPremium(context, feature: 'natal_report');
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NatalReportPage(locked: access == PremiumAccess.titleOnly),
    ));
  }

  @override
  State<NatalReportPage> createState() => _NatalReportPageState();
}

class _NatalReportPageState extends State<NatalReportPage> {
  static const _engine = ShiJiaEngine();
  Profile? _profile;
  bool _loading = true;
  late bool _locked = widget.locked;
  MeaningContent? _meaning = MeaningContent.cached;

  @override
  void initState() {
    super.initState();
    Profile.load().then((p) {
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    });
    MeaningContent.load(L10n.language).then((m) {
      if (mounted) setState(() => _meaning = m);
    });
  }

  Future<void> _edit() async {
    final p = await editProfile(context, _profile);
    if (p != null && mounted) setState(() => _profile = p);
  }

  Future<void> _gender() async {
    final g = await pickGender(context, _profile?.male);
    if (g == null || _profile == null) return;
    final p = _profile!.withGender(g);
    await p.save();
    if (mounted) setState(() => _profile = p);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _profile;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.reportTitle),
        actions: [IconButton(icon: const Icon(Icons.edit_calendar_outlined), tooltip: l.profileTitle, onPressed: _edit)],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : p == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(l.profileNeedBirth, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _edit, child: Text(l.profileTitle)),
                      ]),
                    ),
                  )
                : _body(context, p),
      ),
    );
  }

  Widget _body(BuildContext context, Profile p) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: qm.textMuted);
    final s = AppSettings.instance;
    final at = p.birthInstant;
    final now = DateTime.now();
    final r = const NatalReportEngine().build(at,
        male: p.male, knowTime: p.birthMinutes != null, now: now, settings: s.timeSettingsAt(at), method: s.juMethod);
    final chart = r.natal.chart;
    String? m(String k) => _meaning?.lookup('np', k);

    Widget section(String title, List<Widget> children, {String? hint}) => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: serif(text.titleMedium).copyWith(color: qm.primary)),
              if (hint != null) Text(hint, style: muted),
              const SizedBox(height: 6),
              ...children,
            ]),
          ),
        );

    String palaceLine(DirectionVerdict v) => [
          QimenTerms.palace(v.palace, lang),
          TravelText.direction(l, v.palace),
          if (v.door != null) QimenTerms.door(v.door!, lang),
          ...chart[v.palace].stars.map((x) => QimenTerms.star(x, lang)),
          if (chart[v.palace].god != null) QimenTerms.god(chart[v.palace].god!, lang),
        ].join(l.separator);

    String rel(Relation? x) => switch (x) {
          null => l.reportRelSame,
          Relation.shengWo => l.reportRelShengWo,
          Relation.woSheng => l.reportRelWoSheng,
          Relation.keWo => l.reportRelKeWo,
          Relation.woKe => l.reportRelWoKe,
          Relation.biHe => l.reportRelBiHe,
        };

    String advice(TravelLevel v) => switch (v) {
          TravelLevel.great => l.reportAdviceGreat,
          TravelLevel.good => l.reportAdviceGood,
          TravelLevel.neutral => l.reportAdviceNeutral,
          TravelLevel.minor => l.reportAdviceMinor,
          TravelLevel.blocked => l.reportAdviceBlocked,
        };

    Widget topic(String title, String hint, TopicReading? t) {
      if (t == null) return const SizedBox.shrink();
      final v = t.verdict;
      return section(title, hint: hint, [
        Row(children: [
          Expanded(child: Text(palaceLine(v), style: text.bodyMedium)),
          ToneBadge(tone: toneOfLevel(v.level), label: TravelText.level(l, v.level)),
        ]),
        const SizedBox(height: 4),
        Text('${advice(v.level)}${l.reportJoin}${rel(t.relation)}'),
        for (final x in chart[v.palace].stars)
          if (_meaning?.lookup('star', x.zh) case final note?) Text('${QimenTerms.star(x, lang)}：$note', style: muted),
        if (v.flags.isNotEmpty) Text(v.flags.map((f) => TravelText.flag(l, f)).join(l.separator), style: muted),
      ]);
    }

    // ── 免費：性格＋今年 ──
    final self = r.natal.self;
    final selfCell = self == null ? null : chart[self.palace];
    final personality = <String?>[
      if (selfCell != null) ...[
        for (final x in selfCell.stars) m(x.zh),
        if (selfCell.door != null) m(selfCell.door!.zh),
        if (selfCell.god != null) m(selfCell.god!.zh),
      ],
    ].whereType<String>().toList();
    final thisYear = const PersonalEngine()
        .fortune(r.natal.birth, DateTime(now.year, 7, 1), PanUnit.year, settings: s.timeSettingsAt(now), method: s.juMethod)
        .verdict;

    final free = <Widget>[
      section(l.reportPersonality, hint: self == null ? null : l.natalSelf(stemNames[r.natal.birth.dayStem], QimenTerms.palace(self.palace, lang)), [
        if (self != null)
          Row(children: [
            Expanded(child: Text(palaceLine(self), style: text.bodyMedium)),
            ToneBadge(tone: toneOfLevel(self.level), label: TravelText.level(l, self.level)),
          ]),
        for (final x in personality) Padding(padding: const EdgeInsets.only(top: 6), child: Text(x)),
      ]),
      if (thisYear != null)
        section(l.reportThisYear('${now.year}'), [
          Row(children: [
            Expanded(child: Text(palaceLine(thisYear), style: text.bodyMedium)),
            ToneBadge(tone: toneOfLevel(thisYear.level), label: TravelText.level(l, thisYear.level)),
          ]),
          const SizedBox(height: 4),
          Text(advice(thisYear.level)),
        ]),
    ];

    // ── 訂閱：事業、財運、感情、六親、大運、關鍵年 ──
    final loveHint = switch (p.male) { true => l.reportLoveMale, false => l.reportLoveFemale, null => l.reportLoveNone };
    final kin = [
      (NatalTopic.parents, l.reportParents),
      (NatalTopic.siblings, l.reportSiblings),
      (NatalTopic.children, l.reportChildren),
    ];
    final details = <Widget>[
      topic(l.reportCareer, l.reportCareerHint, r.topics[NatalTopic.career]),
      topic(l.reportWealth, l.reportWealthHint, r.topics[NatalTopic.wealth]),
      topic(l.reportLove, loveHint, r.topics[NatalTopic.love]),
      section(l.reportKin, [
        for (final (k, label) in kin)
          if (r.topics[k] case final t?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(label, style: text.bodyLarge)),
                  ToneBadge(tone: toneOfLevel(t.verdict.level), label: TravelText.level(l, t.verdict.level)),
                ]),
                Text(palaceLine(t.verdict), style: muted),
                Text(rel(t.relation)),
              ]),
            ),
        if (p.birthMinutes == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.reportNoTimeChildren, style: muted)),
      ]),
      section(l.reportDaYun, hint: l.reportDaYunHint, [
        if (r.forward == null) ...[
          Text(l.reportNeedGender),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _gender, child: Text(l.profileGender)),
        ] else ...[
          Text(l.reportStartAge(r.daYun.first.startAge.toStringAsFixed(1), r.forward! ? l.reportForward : l.reportBackward),
              style: muted),
          for (var i = 0; i < r.daYun.length; i++)
            () {
              final d = r.daYun[i];
              final t = d.reading;
              final current = now.year >= d.startYear && (i + 1 >= r.daYun.length || now.year < r.daYun[i + 1].startYear);
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: current ? qm.primary : qm.textMuted.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('${d.pillar}・${l.reportDaYunRow(d.startAge.round().toString(), '${d.startYear}')}',
                          style: text.bodyLarge?.copyWith(fontWeight: current ? FontWeight.bold : null)),
                    ),
                    if (t != null) ToneBadge(tone: toneOfLevel(t.verdict.level), label: TravelText.level(l, t.verdict.level)),
                  ]),
                  if (t != null) ...[
                    Text(palaceLine(t.verdict), style: muted),
                    Text('${advice(t.verdict.level)}${l.reportJoin}${rel(t.relation)}'),
                  ],
                ]),
              );
            }(),
        ],
      ]),
      section(l.reportKeyYears, hint: l.reportKeyYearsHint, [
        if (r.keyYears.isEmpty) Text(l.reportNoKeyYears),
        for (final k in r.keyYears)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text([
              '${k.year}',
              if (k.daYunChange) l.reportDaYunChange,
            ].join(l.separator)),
            subtitle: k.verdict == null ? null : Text(palaceLine(k.verdict!)),
            trailing: k.verdict == null
                ? null
                : ToneBadge(tone: toneOfLevel(k.verdict!.level), label: TravelText.level(l, k.verdict!.level)),
          ),
      ]),
      // 流月（HANDOFF §10 C）：接下來 12 個「節」起的月盤上年命宮吉凶，每月更新。
      section(l.reportMonths, hint: l.reportMonthsHint, [
        for (final t in _engine.calendar
            .termsBetween(now.toUtc(), now.toUtc().add(const Duration(days: 370)))
            .where((t) => t.index.isOdd)
            .take(12))
          () {
            final at = t.startUtc.add(const Duration(days: 1));
            final v = const PersonalEngine()
                .fortune(r.natal.birth, at, PanUnit.month, settings: s.timeSettingsAt(at.toLocal()), method: s.juMethod)
                .verdict;
            final local = t.startUtc.toLocal();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}'
                  '${l.separator}${QimenTerms.solarTerm(t.index, lang)}'),
              subtitle: v == null ? null : Text(palaceLine(v)),
              trailing: v == null ? null : ToneBadge(tone: toneOfLevel(v.level), label: TravelText.level(l, v.level)),
            );
          }(),
      ]),
    ];

    final d = p.birthDate;
    final mm = p.birthMinutes;
    String two(int n) => n.toString().padLeft(2, '0');
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('${d.year}/${two(d.month)}/${two(d.day)}${mm == null ? '' : ' ${two(mm ~/ 60)}:${two(mm % 60)}'}',
          textAlign: TextAlign.center, style: text.titleSmall),
      Text(l.homeJu(QimenTerms.dun(chart.dun, lang), chart.ju, QimenTerms.yuan(chart.yuan, lang)),
          textAlign: TextAlign.center, style: TextStyle(color: qm.textMuted)),
      if (mm == null) Text(l.natalNoTime, textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: qm.bad)),
      const SizedBox(height: 8),
      ...free,
      if (_locked)
        LockedPreview(
          feature: 'natal_report',
          text: l.reportLocked,
          onUnlocked: () => setState(() => _locked = false),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: details),
        )
      else
        ...details,
      Padding(padding: const EdgeInsets.all(8), child: Text(l.reportBasis, style: muted)),
      Text(l.homeDisclaimer, textAlign: TextAlign.center, style: muted),
    ]);
  }
}
