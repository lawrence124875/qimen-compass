import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/widgets/result_card.dart';
import '../personal/profile.dart';
import '../travel/travel_text.dart';
import 'family_store.dart';

/// 一位成員當天的結果（自己 [member] 為 null）。
class FamilyRow {
  const FamilyRow({required this.name, required this.day, this.member});

  final String name;
  final MemberDay day;
  final FamilyMember? member;
}

/// 算出自己＋家人在 [date] 的出門、簽約最佳時辰（今天只看還沒結束的時辰）。
List<FamilyRow> computeFamilyDay(String meName, Profile? me, List<FamilyMember> members, DateTime date) {
  final s = AppSettings.instance;
  final now = DateTime.now();
  final ts = s.timeSettingsAt(date);
  final alerts = DayAlerts.of(date, settings: ts);
  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
  MemberDay eval(DateTime birth) => const FamilyDayPlanner().evaluate(
        BirthInfo.fromInstant(birth, settings: s.timeSettingsAt(birth)),
        date,
        notBefore: isToday ? now : null,
        alerts: alerts,
        settings: ts,
        method: s.juMethod,
      );
  return [
    if (me != null) FamilyRow(name: meName, day: eval(me.birthInstant)),
    for (final m in members) FamilyRow(name: m.name, day: eval(m.birthInstant), member: m),
  ];
}

String _hm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String familySlotText(AppLocalizations l, ZeShiSlot s) =>
    '${_hm(s.startUtc)}–${_hm(s.endUtc)}${l.separator}${TravelText.direction(l, s.palace)}';

/// 「適合出門：A、B」「適合簽約：C」兩行摘要（此刻頁卡片共用）。
List<String> familySummary(AppLocalizations l, List<FamilyRow> rows) {
  final go = [for (final r in rows) if (r.day.suits(r.day.travel)) r.name];
  final sign = [for (final r in rows) if (r.day.suits(r.day.contract)) r.name];
  if (go.isEmpty && sign.isEmpty) return [l.familySuitNobody];
  return [
    if (go.isNotEmpty) l.familySuitGo(go.join(l.listJoiner)),
    if (sign.isNotEmpty) l.familySuitSign(sign.join(l.listJoiner)),
  ];
}

/// 家人盤（HANDOFF §12 1.3.0）：存多位家人的生日，一鍵看今天（或明天）誰適合出門、簽約。
/// 免費版可存 `qm_free_family_max` 位（預設 1），訂閱無限。
class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  Profile? _me;
  List<FamilyMember> _members = [];
  bool _loaded = false;
  int _offset = 0; // 0 今天、1 明天

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await Profile.load();
    final list = await FamilyStore.load();
    if (!mounted) return;
    setState(() {
      _me = me;
      _members = list;
      _loaded = true;
    });
  }

  Future<void> _editMe() async {
    final p = await editProfile(context, _me);
    if (p != null && mounted) setState(() => _me = p);
  }

  Future<void> _edit([FamilyMember? old]) async {
    final l = context.l10n;
    final sv = AppServices.of(context);
    if (old == null && !sv.isPremium && _members.length >= sv.limits.familyMax) {
      sv.analytics.log('qm_hit_free_limit', {'type': 'family'});
      final ok = await openPaywall(context, source: 'family_limit', note: l.familyLimitNote(sv.limits.familyMax));
      if (!ok || !mounted) return;
    }
    final m = await showDialog<FamilyMember>(context: context, builder: (_) => _MemberDialog(old: old));
    if (m == null) return;
    final list = [..._members];
    final i = list.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      list[i] = m;
    } else {
      list.add(m);
    }
    await FamilyStore.save(list);
    if (mounted) setState(() => _members = list);
  }

  Future<void> _delete(FamilyMember m) async {
    final list = _members.where((x) => x.id != m.id).toList();
    await FamilyStore.save(list);
    if (mounted) setState(() => _members = list);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day + _offset);
    final rows = _loaded ? computeFamilyDay(l.familyMe, _me, _members, date) : const <FamilyRow>[];

    Widget line(String label, ZeShiSlot? slot) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            SizedBox(width: 56, child: Text(label, style: text.bodyMedium?.copyWith(color: qm.textMuted))),
            Expanded(child: Text(slot == null ? l.familyNone : familySlotText(l, slot))),
            if (slot != null) ToneBadge(tone: toneOfLevel(slot.level), label: TravelText.level(l, slot.level)),
          ]),
        );

    Widget card(FamilyRow r) => Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.name, style: serif(text.titleMedium).copyWith(color: qm.primary))),
                if (r.member == null)
                  IconButton(icon: const Icon(Icons.edit_outlined), tooltip: l.familyEdit, onPressed: _editMe)
                else
                  PopupMenuButton<int>(
                    onSelected: (v) => v == 0 ? _edit(r.member) : _delete(r.member!),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 0, child: Text(l.familyEdit)),
                      PopupMenuItem(value: 1, child: Text(l.familyDelete)),
                    ],
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(children: [
                  line(l.familyGoOut, r.day.travel),
                  line(l.familySign, r.day.contract),
                ]),
              ),
              if (r.day.clash)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: Text(l.familyClash, style: text.bodySmall?.copyWith(color: qm.bad)),
                ),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.familyTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l.familyAdd),
        onPressed: () => _edit(),
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
                Center(
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(l.familyToday)),
                      ButtonSegment(value: 1, label: Text(l.familyTomorrow)),
                    ],
                    selected: {_offset},
                    onSelectionChanged: (v) => setState(() => _offset = v.first),
                  ),
                ),
                const SizedBox(height: 10),
                if (rows.isNotEmpty)
                  Card(
                    color: qm.primary.withValues(alpha: 0.10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (final s in familySummary(l, rows)) Text(s, style: text.titleSmall),
                      ]),
                    ),
                  ),
                if (_me == null)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.cake_outlined, color: qm.primary),
                      title: Text(l.profileTitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _editMe,
                    ),
                  ),
                for (final r in rows) card(r),
                if (_members.isEmpty)
                  EmptyState(icon: Icons.family_restroom_outlined, text: l.familyEmpty, action: l.familyAdd, onAction: () => _edit()),
                const SizedBox(height: 8),
                Text(l.familyHint, style: text.bodySmall?.copyWith(color: qm.textMuted)),
              ]),
      ),
    );
  }
}

class _MemberDialog extends StatefulWidget {
  const _MemberDialog({this.old});

  final FamilyMember? old;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late final _name = TextEditingController(text: widget.old?.name ?? '');
  late DateTime? _date = widget.old?.birthDate;
  late int? _min = widget.old?.birthMinutes;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = _min;
    final ok = _name.text.trim().isNotEmpty && _date != null;
    return AlertDialog(
      title: Text(widget.old == null ? l.familyAdd : l.familyEdit),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _name,
          autofocus: widget.old == null,
          maxLength: 20,
          decoration: InputDecoration(labelText: l.familyName),
          onChanged: (_) => setState(() {}),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.profileBirthDate),
          trailing: Text(_date == null ? '—' : _d(_date!)),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              helpText: l.profileBirthDate,
              initialDate: _date ?? DateTime(1990, 1, 1),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              initialEntryMode: DatePickerEntryMode.input,
            );
            if (d != null) setState(() => _date = d);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.profileBirthTime),
          trailing: Text(m == null ? l.profileTimeUnknown : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}'),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              helpText: l.profileBirthTime,
              cancelText: l.profileTimeUnknown,
              initialTime: m == null ? const TimeOfDay(hour: 12, minute: 0) : TimeOfDay(hour: m ~/ 60, minute: m % 60),
              initialEntryMode: TimePickerEntryMode.input,
            );
            setState(() => _min = t == null ? null : t.hour * 60 + t.minute);
          },
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: ok
              ? () => Navigator.pop(
                    context,
                    FamilyMember(
                      id: widget.old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                      name: _name.text.trim(),
                      birthDate: _date!,
                      birthMinutes: _min,
                    ),
                  )
              : null,
          child: Text(l.ok),
        ),
      ],
    );
  }
}
