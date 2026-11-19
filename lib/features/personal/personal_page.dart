import 'package:flutter/material.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/chart_board.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../meaning/meaning_content.dart';
import '../../shared/widgets/result_card.dart';
import '../travel/travel_text.dart';
import 'profile.dart';

/// 我的奇門（HANDOFF §12 P4）：本命盤、流年流月、個人吉方。
class PersonalPage extends StatefulWidget {
  const PersonalPage({super.key});

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  Profile? _profile;
  bool _loading = true;
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _profile;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.personalTitle),
          actions: [IconButton(icon: const Icon(Icons.edit_calendar_outlined), tooltip: l.profileTitle, onPressed: _edit)],
          bottom: p == null ? null : TabBar(tabs: [Tab(text: l.natalTab), Tab(text: l.fortuneTab), Tab(text: l.luckyTab)]),
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
                  : TabBarView(children: [
                      _NatalView(profile: p, meaning: _meaning),
                      _FortuneView(profile: p),
                      _LuckyView(profile: p),
                    ]),
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 一宮的解讀卡：標題、門星神（附一句意義）、吉凶等級。
class _PalaceCard extends StatelessWidget {
  const _PalaceCard({required this.title, required this.hint, required this.chart, required this.verdict, this.meaning});

  final String title, hint;
  final QimenChart chart;
  final DirectionVerdict? verdict;
  final MeaningContent? meaning;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final v = verdict;
    if (v == null) return const SizedBox.shrink();
    final c = chart[v.palace];
    String? m(String k, String zh) => meaning?.lookup(k, zh);
    Widget line(String term, String? note) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(term, style: text.bodyLarge),
            if (note != null) Text(note, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: serif(text.titleMedium).copyWith(color: qm.primary))),
            ToneBadge(tone: toneOfLevel(v.level), label: TravelText.level(l, v.level)),
          ]),
          Text(hint, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          if (c.door != null) line(QimenTerms.door(c.door!, lang), m('door', c.door!.zh)),
          for (final s in c.stars) line(QimenTerms.star(s, lang), m('star', s.zh)),
          if (c.god != null) line(QimenTerms.god(c.god!, lang), m('god', c.god!.zh)),
          if (v.flags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(v.flags.map((f) => TravelText.flag(l, f)).join(l.separator), style: text.bodySmall),
            ),
        ]),
      ),
    );
  }
}

class _NatalView extends StatelessWidget {
  const _NatalView({required this.profile, this.meaning});

  final Profile profile;
  final MeaningContent? meaning;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final s = AppSettings.instance;
    final at = profile.birthInstant;
    final r = const PersonalEngine().natal(at, settings: s.timeSettingsAt(at), method: s.juMethod);
    final d = profile.birthDate;
    final m = profile.birthMinutes;
    final birthText = '${d.year}-${_two(d.month)}-${_two(d.day)}${m == null ? '' : ' ${_two(m ~/ 60)}:${_two(m % 60)}'}';
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(birthText, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
      Text(l.homeJu(QimenTerms.dun(r.chart.dun, lang), r.chart.ju, QimenTerms.yuan(r.chart.yuan, lang)),
          textAlign: TextAlign.center, style: TextStyle(color: qm.textMuted)),
      if (m == null) Text(l.natalNoTime, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: qm.bad)),
      const SizedBox(height: 8),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ChartBoard(
            chart: r.chart,
            highlight: {if (r.ming != null) r.ming!.palace, if (r.self != null) r.self!.palace},
            onTapPalace: (p) => showPalaceSheet(context, r.chart, p),
          ),
        ),
      ),
      const SizedBox(height: 8),
      _PalaceCard(
        title: l.natalMing(stemNames[r.birth.yearStem], r.ming == null ? '' : QimenTerms.palace(r.ming!.palace, lang)),
        hint: l.natalMingHint,
        chart: r.chart,
        verdict: r.ming,
        meaning: meaning,
      ),
      _PalaceCard(
        title: l.natalSelf(stemNames[r.birth.dayStem], r.self == null ? '' : QimenTerms.palace(r.self!.palace, lang)),
        hint: l.natalSelfHint,
        chart: r.chart,
        verdict: r.self,
        meaning: meaning,
      ),
      Text(l.homeDisclaimer, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: qm.textMuted)),
    ]);
  }
}

class _FortuneView extends StatelessWidget {
  const _FortuneView({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final s = AppSettings.instance;
    final birth = BirthInfo.fromInstant(profile.birthInstant, settings: s.timeSettingsAt(profile.birthInstant));
    const engine = PersonalEngine();
    final now = DateTime.now();
    FortuneReading f(DateTime t, PanUnit u) => engine.fortune(birth, t, u, settings: s.timeSettingsAt(t), method: s.juMethod);
    Widget row(String label, FortuneReading r) {
      final v = r.verdict;
      return ListTile(
        title: Text(label),
        subtitle: v == null
            ? null
            : Text([
                QimenTerms.palace(v.palace, lang),
                if (v.door != null) QimenTerms.door(v.door!, lang),
                ...v.flags.map((x) => TravelText.flag(l, x)),
              ].join(l.separator)),
        trailing: v == null
            ? null
            : ToneBadge(tone: toneOfLevel(v.level), label: TravelText.level(l, v.level)),
      );
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(l.fortuneHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: qm.textMuted)),
      for (var y = 0; y < 3; y++) row(l.fortuneYear('${now.year + y}'), f(DateTime(now.year + y, 7, 1), PanUnit.year)),
      const Divider(),
      for (var i = 0; i < 12; i++)
        () {
          final t = DateTime(now.year, now.month + i, 15);
          return row(l.fortuneMonth('${t.year}-${_two(t.month)}'), f(t, PanUnit.month));
        }(),
      Text(l.homeDisclaimer, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: qm.textMuted)),
    ]);
  }
}

class _LuckyView extends StatelessWidget {
  const _LuckyView({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final s = AppSettings.instance;
    final now = DateTime.now();
    final birth = BirthInfo.fromInstant(profile.birthInstant, settings: s.timeSettingsAt(profile.birthInstant));
    final hits = const PersonalEngine().luckyHours(birth, now, settings: s.timeSettingsAt(now), method: s.juMethod);
    String when(DirectionVerdict v) {
      final a = v.startUtc!.toLocal(), b = v.endUtc!.toLocal();
      return '${_two(a.month)}-${_two(a.day)} ${_two(a.hour)}:${_two(a.minute)}–${_two(b.hour)}:${_two(b.minute)}';
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(l.luckyHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: qm.textMuted)),
      const SizedBox(height: 8),
      if (hits.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.luckyNone, textAlign: TextAlign.center)),
      for (final v in hits)
        Card(
          child: ListTile(
            title: Text(when(v)),
            subtitle: Text([TravelText.direction(l, v.palace), if (v.door != null) QimenTerms.door(v.door!, lang)].join(l.separator)),
            trailing: ToneBadge(tone: toneOfLevel(v.level), label: TravelText.level(l, v.level)),
          ),
        ),
    ]);
  }
}
