import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../compass/compass_math.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../travel/travel_text.dart';
import 'heading_tracker.dart';

/// 床位、書桌、座位朝向（HANDOFF §12 P6）：手機平放、頂端指向床頭（或人面向）的方向，
/// 看今年年盤上該方位的門。家具擺放屬長期，所以用年盤判斷。
enum FacingTarget {
  bed({Door.xiu, Door.sheng, Door.kai}),
  desk({Door.jingScene, Door.kai, Door.sheng}),
  seat({Door.kai, Door.sheng, Door.xiu}),
  sofa({Door.xiu, Door.sheng, Door.jingScene}),
  stove({Door.sheng, Door.jingScene, Door.xiu}),
  altar({Door.kai, Door.xiu, Door.sheng}),
  cashier({Door.sheng, Door.kai, Door.jingScene});

  const FacingTarget(this.preferred);
  final Set<Door> preferred;
}

class FacingPage extends StatefulWidget {
  const FacingPage({super.key});

  @override
  State<FacingPage> createState() => _FacingPageState();
}

class _FacingPageState extends State<FacingPage> {
  final _tracker = HeadingTracker.instance;
  FacingTarget _target = FacingTarget.bed;
  late final QimenChart _year = () {
    final s = AppSettings.instance;
    final now = DateTime.now();
    return const ShiJiaEngine().compute(now, settings: s.timeSettingsAt(now), method: s.juMethod, unit: PanUnit.year);
  }();

  static const _kGuide = 'qm_facing_guide_seen';

  @override
  void initState() {
    super.initState();
    _tracker.acquire();
    SharedPreferences.getInstance().then((p) async {
      if (p.getBool(_kGuide) == true) return;
      await p.setBool(_kGuide, true);
      if (mounted) _showGuide();
    }).catchError((_) {});
  }

  void _showGuide() {
    final l = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.facingGuideTitle),
        content: SingleChildScrollView(child: Text(l.facingGuide)),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.guideStart))],
      ),
    );
  }

  @override
  void dispose() {
    _tracker.release();
    super.dispose();
  }

  String _targetName(AppLocalizations l, FacingTarget t) => switch (t) {
        FacingTarget.bed => l.facingBed,
        FacingTarget.desk => l.facingDesk,
        FacingTarget.seat => l.facingSeat,
        FacingTarget.sofa => l.facingSofa,
        FacingTarget.stove => l.facingStove,
        FacingTarget.altar => l.facingAltar,
        FacingTarget.cashier => l.facingCashier,
      };

  String _how(AppLocalizations l, FacingTarget t) => switch (t) {
        FacingTarget.bed => l.facingHowBed,
        FacingTarget.desk => l.facingHowDesk,
        FacingTarget.seat => l.facingHowSeat,
        FacingTarget.sofa => l.facingHowSofa,
        FacingTarget.stove => l.facingHowStove,
        FacingTarget.altar => l.facingHowAltar,
        FacingTarget.cashier => l.facingHowCashier,
      };

  /// 八門白話（吉門在前）。
  static String doorPlain(AppLocalizations l, Door d) => switch (d) {
        Door.kai => l.facingDoorKai,
        Door.xiu => l.facingDoorXiu,
        Door.sheng => l.facingDoorSheng,
        Door.jingScene => l.facingDoorJing,
        Door.du => l.facingDoorDu,
        Door.shang => l.facingDoorShang,
        Door.jing => l.facingDoorJingFear,
        Door.si => l.facingDoorSi,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final suggest = [
      for (final p in const [1, 8, 3, 4, 9, 2, 7, 6])
        if (_target.preferred.contains(_year[p].door)) p,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.facingTitle), actions: [
        IconButton(icon: const Icon(Icons.help_outline), tooltip: l.facingGuideTitle, onPressed: _showGuide),
      ]),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final t in FacingTarget.values)
              ChoiceChip(
                label: Text(_targetName(l, t)),
                selected: t == _target,
                onSelected: (_) => setState(() => _target = t),
              ),
          ]),
          const SizedBox(height: 8),
          Text(_how(l, _target), style: text.bodyMedium?.copyWith(color: qm.textMuted)),
          const SizedBox(height: 4),
          Text(l.facingPrefer([for (final d in Door.values) if (_target.preferred.contains(d)) QimenTerms.doorName(d, lang)].join(l.separator)),
              style: text.bodySmall),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: _tracker,
            builder: (context, _) {
              final h = _tracker.heading;
              if (h == null) return Text(l.compassWaiting, textAlign: TextAlign.center);
              final p = palaceAtBearing(h);
              final door = _year[p].door!;
              final (label, color) = _target.preferred.contains(door)
                  ? (l.facingFit, qm.good)
                  : door.luck == Luck.bad
                      ? (l.facingAvoid, qm.bad)
                      : (l.facingOk, qm.neutral);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text('${h.round()}°', style: text.bodyMedium?.copyWith(color: qm.textMuted)),
                    Text(l.facingNow(TravelText.direction(l, p), QimenTerms.door(door, lang)), textAlign: TextAlign.center, style: text.titleMedium),
                    const SizedBox(height: 6),
                    Text(label, style: serif(text.headlineSmall).copyWith(color: color, fontWeight: FontWeight.w700)),
                    if (_tracker.disturbed) Text(l.compassUnstable, style: text.bodySmall?.copyWith(color: qm.bad), textAlign: TextAlign.center),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(l.facingSuggest, style: text.titleSmall?.copyWith(color: qm.primary)),
          const SizedBox(height: 4),
          if (suggest.isEmpty)
            Text(l.facingSuggestNone, style: text.bodySmall?.copyWith(color: qm.textMuted))
          else
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final p in suggest) Chip(label: Text('${TravelText.direction(l, p)}・${QimenTerms.doorName(_year[p].door!, lang)}')),
            ]),
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l.facingDoorsTitle, style: text.titleSmall?.copyWith(color: qm.primary)),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in const [Door.kai, Door.xiu, Door.sheng, Door.jingScene, Door.du, Door.shang, Door.jing, Door.si])
                Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(doorPlain(l, d), style: text.bodySmall)),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.homeDisclaimer, style: text.bodySmall?.copyWith(color: qm.textMuted)),
        ]),
      ),
    );
  }
}
