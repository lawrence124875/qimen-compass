import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/chart_board.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../travel/travel_text.dart';
import 'zeshi_text.dart';

/// 擇時擇日（HANDOFF §7）：掃描未來 N 天的時盤，依情境打分，列出前 5 名，可加入行事曆。
class ZeShiPage extends StatefulWidget {
  const ZeShiPage({super.key});

  @override
  State<ZeShiPage> createState() => _ZeShiPageState();
}

class _ZeShiPageState extends State<ZeShiPage> {
  static const _planner = ZeShiPlanner();
  static const _kEvent = 'qm_zeshi_event';
  static const _kDays = 'qm_zeshi_days';
  static const _kBirth = 'qm_birth_date';
  static const _kIntro = 'qm_zeshi_intro_seen';

  SharedPreferences? _prefs;
  ZeShiEvent _event = ZeShiEvent.contract;
  int _days = 7;
  DateTime? _birth;
  bool _useBirth = false;
  List<ZeShiSlot>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final birth = DateTime.tryParse(p.getString(_kBirth) ?? '');
    setState(() {
      _prefs = p;
      _event = ZeShiEvent.values.asNameMap()[p.getString(_kEvent)] ?? ZeShiEvent.contract;
      _days = p.getInt(_kDays) ?? 7;
      _birth = birth;
      _useBirth = birth != null;
    });
    _run();
    // 首次進入顯示說明（比照謙卦：右上 ⓘ 可重看）。
    if (!(p.getBool(_kIntro) ?? false)) {
      await p.setBool(_kIntro, true);
      if (mounted) _showIntro();
    }
  }

  void _showIntro() {
    final l = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.zeshiTitle),
        content: SingleChildScrollView(child: Text(l.zeshiIntro)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.zeshiIntroOk))],
      ),
    );
  }

  TimeSettings get _settings => AppSettings.instance.timeSettingsAt(DateTime.now());

  void _run() {
    setState(() => _result = null);
    // 讓轉圈先畫出來再計算（30 天約 210 張盤）。
    Future<void>.delayed(const Duration(milliseconds: 16), () {
      if (!mounted) return;
      final birth = _useBirth && _birth != null
          ? BirthInfo.fromInstant(DateTime.utc(_birth!.year, _birth!.month, _birth!.day, 4), settings: const TimeSettings())
          : null;
      final r = _planner.best(DateTime.now(), _event, days: _days, birth: birth, settings: _settings, method: AppSettings.instance.juMethod);
      setState(() => _result = r);
    });
  }

  void _setEvent(ZeShiEvent e) {
    _event = e;
    _prefs?.setString(_kEvent, e.name);
    _run();
  }

  void _setDays(int d) {
    _days = d;
    _prefs?.setInt(_kDays, d);
    _run();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (d == null) return;
    _birth = d;
    _useBirth = true;
    await _prefs?.setString(_kBirth, '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    _run();
  }

  Future<void> _addToCalendar(ZeShiSlot s) async {
    final l = context.l10n;
    final title = l.zeshiCalendarTitle(ZeShiText.event(l, _event));
    final desc = l.zeshiCalendarBody(
      TravelText.direction(l, s.palace),
      QimenTerms.door(s.door, L10n.language),
      TravelText.level(l, s.level),
    );
    final ok = await cal.Add2Calendar.addEvent2Cal(cal.Event(
      title: title,
      description: desc,
      startDate: s.startUtc.toLocal(),
      endDate: s.endUtc.toLocal(),
    ));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.zeshiCalendarFailed)));
    }
  }

  void _showChart(ZeShiSlot s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ZeShiText.when(context.l10n, s), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.sizeOf(context).height * 0.6),
              child: ChartBoard(chart: s.chart, highlight: {s.palace}),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text(l.zeshiTitle), actions: [
        IconButton(tooltip: l.zeshiIntroTip, icon: const Icon(Icons.info_outline), onPressed: _showIntro),
      ]),
      body: _prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in ZeShiEvent.values)
                    ChoiceChip(label: Text(ZeShiText.event(l, e)), selected: e == _event, onSelected: (_) => _setEvent(e)),
                ]),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: [for (final d in const [7, 14, 30]) ButtonSegment(value: d, label: Text(l.zeshiDays(d)))],
                  selected: {_days},
                  onSelectionChanged: (s) => _setDays(s.first),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.zeshiUseBirth),
                  subtitle: Text(_birth == null
                      ? l.zeshiBirthHint
                      : l.zeshiBirthSet('${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}')),
                  value: _useBirth && _birth != null,
                  onChanged: (v) {
                    if (v && _birth == null) {
                      _pickBirth();
                    } else {
                      _useBirth = v;
                      _run();
                    }
                  },
                  secondary: IconButton(
                    tooltip: l.zeshiBirthEdit,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: _pickBirth,
                  ),
                ),
                const Divider(height: 24),
                Text(l.zeshiTop, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (result == null)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else if (result.isEmpty)
                  Padding(padding: const EdgeInsets.all(24), child: Text(l.zeshiNone, textAlign: TextAlign.center))
                else
                  for (var i = 0; i < result.length; i++)
                    _SlotCard(
                      rank: i + 1,
                      slot: result[i],
                      onChart: () => _showChart(result[i]),
                      onCalendar: () => _addToCalendar(result[i]),
                    ),
                const SizedBox(height: 12),
                Text(l.zeshiFootnote, style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
                const SizedBox(height: 4),
                Text(l.homeDisclaimer, style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
              ],
            ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.rank, required this.slot, required this.onChart, required this.onCalendar});

  final int rank;
  final ZeShiSlot slot;
  final VoidCallback onChart, onCalendar;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final theme = Theme.of(context);
    final s = slot;
    final good = s.flags.where(ZeShiText.isPlus).map((f) => ZeShiText.flag(l, f)).join('、');
    final bad = s.flags.where((f) => !ZeShiText.isPlus(f)).map((f) => ZeShiText.flag(l, f)).join('、');
    final levelColor = switch (s.level) {
      TravelLevel.great || TravelLevel.good => qm.good,
      TravelLevel.neutral => qm.neutral,
      _ => qm.bad,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChart,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$rank', style: serif(theme.textTheme.headlineSmall).copyWith(color: qm.primary, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ZeShiText.when(l, s), style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(l.travelDirDoor(TravelText.direction(l, s.palace), QimenTerms.door(s.door, L10n.language)),
                    style: serif(theme.textTheme.titleMedium).copyWith(color: qm.text)),
                if (good.isNotEmpty) Text('＋ $good', style: theme.textTheme.bodySmall?.copyWith(color: qm.good)),
                if (bad.isNotEmpty) Text('－ $bad', style: theme.textTheme.bodySmall?.copyWith(color: qm.bad)),
              ]),
            ),
            Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(border: Border.all(color: levelColor), borderRadius: BorderRadius.circular(12)),
                child: Text(TravelText.level(l, s.level), style: TextStyle(color: levelColor)),
              ),
              IconButton(tooltip: l.zeshiAddCalendar, icon: const Icon(Icons.event_available_outlined), onPressed: onCalendar),
            ]),
          ]),
        ),
      ),
    );
  }
}
