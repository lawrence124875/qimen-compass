import 'package:flutter/material.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/chart_board.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../almanac/almanac_page.dart' show levelColor;
import '../travel/travel_text.dart';
import 'profile.dart';
import '../../shared/premium/usage_gate.dart';
import '../../shared/widgets/ymd_date_picker.dart';

/// 雙人合盤（HANDOFF §12 P5）：我（個人資料生日）＋對方生日 → 合夥／婚配兩種看法。
class SynastryPage extends StatefulWidget {
  const SynastryPage({super.key, this.locked = false});

  /// 免費版體驗過後：只給等級，加減分原因與盤面要訂閱。
  final bool locked;

  @override
  State<SynastryPage> createState() => _SynastryPageState();
}

class _SynastryPageState extends State<SynastryPage> {
  Profile? _me;
  DateTime? _other;
  SynMode _mode = SynMode.partner;
  late bool _locked = widget.locked;

  @override
  void initState() {
    super.initState();
    Profile.load().then((p) {
      if (mounted) setState(() => _me = p);
    });
  }

  Future<void> _pickMe() async {
    final p = await editProfile(context, _me);
    if (p != null && mounted) setState(() => _me = p);
  }

  Future<void> _pickOther() async {
    final d = await showYmdDatePicker(
      context: context,
      helpText: context.l10n.synOtherBirth,
      initialDate: _other ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) setState(() => _other = d);
  }

  static String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _factor(AppLocalizations l, SynFactor f) => switch (f) {
        SynFactor.stemHe => l.synStemHe,
        SynFactor.stemSheng => l.synStemSheng,
        SynFactor.stemKe => l.synStemKe,
        SynFactor.branchLiuHe => l.synBranchLiuHe,
        SynFactor.branchSanHe => l.synBranchSanHe,
        SynFactor.branchChong => l.synBranchChong,
        SynFactor.samePalace => l.synSamePalace,
        SynFactor.palaceSheng => l.synPalaceSheng,
        SynFactor.palaceKe => l.synPalaceKe,
        SynFactor.doorGood => l.synDoorGood,
        SynFactor.doorBad => l.synDoorBad,
        SynFactor.modeGood => _mode == SynMode.partner ? l.synModePartnerGood : l.synModeMarriageGood,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final me = _me, other = _other;
    final s = AppSettings.instance;
    final now = DateTime.now();
    SynastryReading? r;
    if (me != null && other != null) {
      final ts = s.timeSettingsAt(now);
      r = const SynastryEngine().read(
        BirthInfo.fromInstant(me.birthInstant, settings: ts),
        BirthInfo.fromInstant(DateTime(other.year, other.month, other.day, 12), settings: ts),
        _mode,
        now,
        settings: ts,
        method: s.juMethod,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.synTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<SynMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: SynMode.partner, label: Text(l.synPartner)),
              ButtonSegment(value: SynMode.marriage, label: Text(l.synMarriage)),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(l.synMe),
                subtitle: Text(me == null ? l.profileTitle : _d(me.birthDate)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickMe,
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l.synOther),
                subtitle: Text(other == null ? l.synOtherBirth : _d(other)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickOther,
              ),
            ]),
          ),
          if (r == null)
            Padding(padding: const EdgeInsets.all(24), child: Text(l.synNeedBoth, textAlign: TextAlign.center))
          else ...[
            const SizedBox(height: 12),
            Text(TravelText.level(l, r.level),
                textAlign: TextAlign.center,
                style: serif(text.displaySmall).copyWith(color: levelColor(context, r.level), fontWeight: FontWeight.w700)),
            Text(l.synYearNote('${now.year}'), textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: qm.textMuted)),
            const SizedBox(height: 8),
            if (_locked)
              PremiumLockCard(feature: 'synastry', text: l.synLocked, onUnlocked: () => setState(() => _locked = false))
            else ...[
            for (final f in r.factors)
              ListTile(
                dense: true,
                leading: Icon(f.good ? Icons.add_circle_outline : Icons.remove_circle_outline, color: f.good ? qm.good : qm.bad),
                title: Text(_factor(l, f)),
              ),
            if (r.factors.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(l.synPlain, textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ChartBoard(
                  chart: r.chart,
                  highlight: {if (r.palaceA != null) r.palaceA!, if (r.palaceB != null) r.palaceB!},
                  onTapPalace: (p) => showPalaceSheet(context, r!.chart, p),
                ),
              ),
            ),
            ],
            const SizedBox(height: 8),
            Text(l.homeDisclaimer, textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          ],
        ]),
      ),
    );
  }
}
