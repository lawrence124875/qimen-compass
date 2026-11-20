import 'package:flutter/material.dart';

import '../../app/main_shell.dart';
import '../../app/services.dart';
import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../shared/premium/usage_gate.dart';
import '../../shared/widgets/result_card.dart';
import '../travel/travel_text.dart';
import 'profile.dart';

/// 今日個人運（此刻頁，HANDOFF §10 B）：本命 × 大運 × 流日。
/// 免費版只看今天的等級，個人吉時、方位、大運宮要訂閱；每天可看廣告解鎖 1 次（當天有效）。
class PersonalDayCard extends StatefulWidget {
  const PersonalDayCard({super.key, required this.now});

  final DateTime now;

  @override
  State<PersonalDayCard> createState() => _PersonalDayCardState();
}

class _PersonalDayCardState extends State<PersonalDayCard> {
  Profile? _profile;
  bool _loaded = false;
  bool _adToday = false;
  PersonalDay? _day;
  String? _dayKey;

  @override
  void initState() {
    super.initState();
    Profile.load().then((p) async {
      final used = await AdUnlock.usedToday('personal_day');
      if (!mounted) return;
      setState(() {
        _profile = p;
        _adToday = used > 0;
        _loaded = true;
      });
    });
  }

  /// 同一天、同一時辰內不重算。
  PersonalDay _compute(Profile p) {
    final n = widget.now;
    final key = '${n.year}${n.month}${n.day}${n.hour ~/ 2}${p.birthInstant.millisecondsSinceEpoch}${p.male}';
    if (_day != null && _dayKey == key) return _day!;
    final s = AppSettings.instance;
    _dayKey = key;
    return _day = PersonalDay.of(p.birthInstant,
        male: p.male,
        now: n,
        birthSettings: s.timeSettingsAt(p.birthInstant),
        settings: s.timeSettingsAt(n),
        method: s.juMethod);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final sv = AppServices.of(context);
    final p = _profile;
    if (!_loaded) return const SizedBox.shrink();

    Widget header({Widget? trailing}) => Row(children: [
          Icon(Icons.person_pin_circle_outlined, color: qm.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(l.pdayTitle, style: serif(text.titleMedium).copyWith(color: qm.text, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing,
        ]);

    final List<Widget> body;
    Widget? badge;
    if (p == null) {
      body = [
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          icon: const Icon(Icons.cake_outlined, size: 18),
          label: Text(l.luckyNeedBirth),
          onPressed: () => MainShell.select(MainTab.me),
        ),
      ];
    } else {
      final d = _compute(p);
      final lv = d.level;
      if (lv != null) badge = ToneBadge(tone: toneOfLevel(lv), label: TravelText.level(l, lv));
      final open = sv.isPremium || _adToday;
      if (!open) {
        body = [
          const SizedBox(height: 8),
          PremiumLockCard(
            feature: 'personal_day',
            text: l.pdayLocked,
            margin: EdgeInsets.zero,
            onUnlocked: () => setState(() => _adToday = true),
          ),
        ];
      } else {
        String hm(DateTime t) {
          final x = t.toLocal();
          return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
        }

        Widget line(String label, String value, {Widget? trailing}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 76, child: Text(label, style: text.bodyMedium?.copyWith(color: qm.textMuted))),
                Expanded(child: Text(value, style: text.bodyMedium?.copyWith(color: qm.text))),
                if (trailing != null) trailing,
              ]),
            );
        final f = d.fortune;
        body = [
          const SizedBox(height: 4),
          if (f != null)
            line(l.pdayFate, [
              TravelText.direction(l, f.palace),
              if (f.door != null) QimenTerms.door(f.door!, L10n.language),
              ...f.flags.take(2).map((x) => TravelText.flag(l, x)),
            ].join(l.separator)),
          line(
              l.pdayHours,
              d.hours.isEmpty
                  ? l.pdayNoHour
                  : d.hours.map((v) => '${hm(v.startUtc!)}–${hm(v.endUtc!)} ${TravelText.direction(l, v.palace)}').join('\n')),
          if (d.daYun != null && d.daYunToday != null)
            line(l.pdayDaYun, '${d.daYun}・${TravelText.direction(l, d.daYunToday!.palace)}',
                trailing: ToneBadge(tone: toneOfLevel(d.daYunToday!.level), label: TravelText.level(l, d.daYunToday!.level)))
          else if (p.male == null)
            Text(l.pdayNeedGender, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          const SizedBox(height: 4),
          Text(l.pdayBasis, style: text.bodySmall?.copyWith(color: qm.textMuted)),
        ];
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header(trailing: badge), ...body]),
      ),
    );
  }
}
