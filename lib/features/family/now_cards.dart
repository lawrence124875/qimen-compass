import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../personal/profile.dart';
import '../reminders/day_alert_reminder.dart';
import 'family_page.dart';
import 'family_store.dart';

/// 此刻頁「重要日」卡：今天或明天有換局、歲破、月破、四離、四絕（或沖家人生年）時才顯示。
class DayAlertCard extends StatefulWidget {
  const DayAlertCard({super.key});

  @override
  State<DayAlertCard> createState() => _DayAlertCardState();
}

class _DayAlertCardState extends State<DayAlertCard> {
  List<(String, List<String>)>? _items;
  String? _lang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).toString();
    if (lang != _lang) {
      _lang = lang;
      _load();
    }
  }

  Future<void> _load() async {
    final l = context.l10n;
    final sv = AppServices.of(context);
    final withClash = sv.isPremium || sv.limits.alertClashFree;
    final now = DateTime.now();
    final out = <(String, List<String>)>[];
    for (var i = 0; i < 2; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final a = DayAlerts.of(d, settings: AppSettings.instance.timeSettingsAt(d));
      final lines = await DayAlertReminder.lines(l, a, withClash: withClash);
      if (lines.isNotEmpty) out.add((i == 0 ? l.familyToday : l.familyTomorrow, lines));
    }
    if (mounted) setState(() => _items = out);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_note_outlined, color: qm.primary),
            const SizedBox(width: 8),
            Text(l.alertCardTitle, style: serif(text.titleMedium).copyWith(color: qm.primary)),
          ]),
          for (final (day, lines) in items) ...[
            const SizedBox(height: 8),
            Text(day, style: text.titleSmall),
            for (final s in lines) Text(s, style: text.bodyMedium),
          ],
        ]),
      ),
    );
  }
}

/// 此刻頁「家人今日」卡：有存家人時顯示「適合出門／簽約」摘要，點開家人盤。
class FamilyTodayCard extends StatefulWidget {
  const FamilyTodayCard({super.key});

  @override
  State<FamilyTodayCard> createState() => _FamilyTodayCardState();
}

class _FamilyTodayCardState extends State<FamilyTodayCard> {
  List<String>? _summary;

  @override
  void initState() {
    super.initState();
    FamilyStore.changed.addListener(_reload);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  @override
  void dispose() {
    FamilyStore.changed.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final members = await FamilyStore.load();
    if (!mounted) return;
    if (members.isEmpty) {
      setState(() => _summary = null);
      return;
    }
    final me = await Profile.load();
    if (!mounted) return;
    final l = context.l10n;
    final rows = computeFamilyDay(l.familyMe, me, members, DateTime.now());
    setState(() => _summary = familySummary(l, rows));
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    final l = context.l10n;
    final qm = context.qm;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.family_restroom_outlined, color: qm.primary),
        title: Text(l.familyTitle),
        subtitle: Text(s.join('\n')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FamilyPage()));
          _reload();
        },
      ),
    );
  }
}
