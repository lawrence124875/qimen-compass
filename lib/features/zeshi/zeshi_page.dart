import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/services.dart';
import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/chart_board.dart';
import '../../app/widgets/hour_window.dart';
import '../../engine/engine.dart' hide Element;
import '../../core/records/record_store.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/usage_gate.dart';
import '../../shared/widgets/result_card.dart';
import '../records/record_actions.dart';
import '../travel/travel_text.dart';
import 'zeshi_text.dart';

/// 擇時擇日（HANDOFF §7）：掃描未來 N 天（最長 1 年）的時盤，依情境打分，列出前 N 名，可加入行事曆。
/// 範圍、筆數、同一天上限、時段可調；長範圍分段計算並顯示進度。
class ZeShiPage extends StatefulWidget {
  const ZeShiPage({super.key, this.locked = false});

  /// 免費版體驗過後：只顯示時間與等級，方位、理由、盤面、行事曆、紀錄需訂閱。
  final bool locked;

  @override
  State<ZeShiPage> createState() => _ZeShiPageState();
}

class _ZeShiPageState extends State<ZeShiPage> {
  static const _planner = ZeShiPlanner();
  static const _kEvent = 'qm_zeshi_event';
  static const _kCustomDoor = 'qm_zeshi_custom_door';
  static const _kCustomGod = 'qm_zeshi_custom_god';
  static const _kDays = 'qm_zeshi_days';
  static const _kBirth = 'qm_birth_date';
  static const _kIntro = 'qm_zeshi_intro_seen';
  static const _kTop = 'qm_zeshi_top';
  static const _kPerDay = 'qm_zeshi_per_day';
  static const _kFrom = 'qm_zeshi_from', _kTo = 'qm_zeshi_to';
  static const dayOptions = [7, 14, 30, 90, 180, 365];
  static const topOptions = [5, 10, 20, 30];

  /// 同一天最多幾筆；0＝不限（一天最多 12 個時辰）。
  static const perDayOptions = [1, 2, 3, 5, 0];

  SharedPreferences? _prefs;
  ZeShiEvent _event = ZeShiEvent.contract;
  Door _customDoor = Door.kai;
  God _customGod = God.zhiFu;
  int _days = 7;
  DateTime? _birth;
  bool _useBirth = false;
  int _top = 5;
  int _perDay = 2;
  HourWindow _window = HourWindow.day;
  List<ZeShiSlot>? _result;
  double? _progress;
  int _runId = 0;

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
      _customDoor = Door.values.asNameMap()[p.getString(_kCustomDoor)] ?? Door.kai;
      _customGod = God.values.asNameMap()[p.getString(_kCustomGod)] ?? God.zhiFu;
      final d = p.getInt(_kDays) ?? 7;
      _days = dayOptions.contains(d) ? d : 7;
      final t = p.getInt(_kTop) ?? 5;
      _top = topOptions.contains(t) ? t : 5;
      final pd = p.getInt(_kPerDay) ?? 2;
      _perDay = perDayOptions.contains(pd) ? pd : 2;
      _window = HourWindow.read(p.getInt(_kFrom), p.getInt(_kTo));
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

  /// 分段計算（每段 7 天），每段之間讓出畫面更新進度；設定改變時舊的計算作廢。
  Future<void> _run() async {
    final id = ++_runId;
    setState(() {
      _result = null;
      _progress = 0;
    });
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final birth = _useBirth && _birth != null
        ? BirthInfo.fromInstant(DateTime.utc(_birth!.year, _birth!.month, _birth!.day, 4), settings: const TimeSettings())
        : null;
    final settings = _settings;
    final method = AppSettings.instance.juMethod;
    final base = DateTime.now().toUtc();
    final all = <int, ZeShiSlot>{};
    const chunk = 7;
    for (var done = 0; done < _days; done += chunk) {
      if (!mounted || id != _runId) return;
      final from = base.add(Duration(days: done));
      final days = (_days - done).clamp(1, chunk);
      for (final s in _planner.scan(done == 0 ? from : from.subtract(const Duration(milliseconds: 1)), _event,
          days: days, fromHour: _window.from, toHour: _window.to, birth: birth, spec: _spec, settings: settings, method: method)) {
        all[s.startUtc.millisecondsSinceEpoch] = s;
      }
      if (_days > chunk) {
        setState(() => _progress = (done + days) / _days);
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (!mounted || id != _runId) return;
    final r = _planner.pick(all.values.toList(), top: _top, perDay: _perDay == 0 ? 12 : _perDay, settings: settings);
    setState(() {
      _result = r;
      _progress = null;
    });
  }

  /// 自訂情境用使用者選的門與神；其他情境用預設。
  ZeShiSpec? get _spec =>
      _event == ZeShiEvent.custom ? ZeShiSpec(doors: [_customDoor], favoredGod: _customGod) : null;

  void _setCustom({Door? door, God? god}) {
    setState(() {
      _customDoor = door ?? _customDoor;
      _customGod = god ?? _customGod;
    });
    _prefs?.setString(_kCustomDoor, _customDoor.name);
    _prefs?.setString(_kCustomGod, _customGod.name);
    _run();
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

  void _setTop(int v) {
    _top = v;
    _prefs?.setInt(_kTop, v);
    _run();
  }

  void _setPerDay(int v) {
    _perDay = v;
    _prefs?.setInt(_kPerDay, v);
    _run();
  }

  void _setWindow(HourWindow w) {
    setState(() => _window = w);
    _prefs?.setInt(_kFrom, w.from);
    _prefs?.setInt(_kTo, w.to);
    _run();
  }

  String _perDayLabel(AppLocalizations l) => _perDay == 0 ? l.zeshiPerDayNoLimit : l.zeshiPerDayLimit(_perDay);

  String _daysLabel(AppLocalizations l, int d) => d == 365 ? l.zeshiOneYear : l.zeshiDays(d);

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

  /// 擇時紀錄（HANDOFF §12 P6）：記下這個時段，事後回來填應驗。
  Future<void> _saveSlot(ZeShiSlot s) {
    final l = context.l10n;
    return saveRecord(context,
        kind: RecordKind.zeshi,
        chartAt: s.startUtc.add(s.endUtc.difference(s.startUtc) ~/ 2),
        summary: [
          ZeShiText.when(l, s),
          l.travelDirDoor(TravelText.direction(l, s.palace), QimenTerms.door(s.door, L10n.language)),
          TravelText.level(l, s.level),
        ].join(l.separator));
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
    final s = AppServices.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: s.premium.isPremium,
      builder: (context, premium, _) => _build(context, widget.locked && !premium),
    );
  }

  Widget _build(BuildContext context, bool locked) {
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
                if (_event == ZeShiEvent.custom) ...[
                  const SizedBox(height: 12),
                  Text(l.zeshiCustomDoor, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final d in Door.values)
                      ChoiceChip(
                          label: Text(QimenTerms.doorName(d, L10n.language)),
                          selected: d == _customDoor,
                          onSelected: (_) => _setCustom(door: d)),
                  ]),
                  const SizedBox(height: 8),
                  Text(l.zeshiCustomGod, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final g in God.values)
                      ChoiceChip(
                          label: Text(QimenTerms.godName(g, L10n.language)),
                          selected: g == _customGod,
                          onSelected: (_) => _setCustom(god: g)),
                  ]),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final d in dayOptions)
                    ChoiceChip(label: Text(_daysLabel(l, d)), selected: d == _days, onSelected: (_) => _setDays(d)),
                ]),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(l.zeshiMoreOptions),
                  subtitle: Text(l.zeshiOptionsSummary(_top, _perDayLabel(l), _window.label(l)),
                      style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.zeshiTopCount),
                    Wrap(spacing: 8, children: [
                      for (final t in topOptions)
                        ChoiceChip(label: Text('$t'), selected: t == _top, onSelected: (_) => _setTop(t)),
                    ]),
                    const SizedBox(height: 8),
                    Text(l.zeshiPerDayMax),
                    Wrap(spacing: 8, children: [
                      for (final n in perDayOptions)
                        ChoiceChip(
                            label: Text(n == 0 ? l.zeshiNoLimit : '$n'), selected: n == _perDay, onSelected: (_) => _setPerDay(n)),
                    ]),
                    Text(l.zeshiPerDayWhy, style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
                    const SizedBox(height: 8),
                    HourWindowPicker(value: _window, onChanged: _setWindow),
                  ],
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
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: (_progress ?? 0) > 0
                        ? Column(children: [
                            LinearProgressIndicator(value: _progress),
                            const SizedBox(height: 8),
                            Text(l.zeshiProgress(((_progress ?? 0) * 100).round())),
                          ])
                        : const Center(child: CircularProgressIndicator()),
                  )
                else if (result.isEmpty)
                  Padding(padding: const EdgeInsets.all(24), child: Text(l.zeshiNone, textAlign: TextAlign.center))
                else ...[
                  ResultCard(
                    tone: toneOfLevel(result.first.level),
                    grade: TravelText.level(l, result.first.level),
                    kicker: l.zeshiTop,
                    headline: locked
                        ? l.resultBestTime(ZeShiText.when(l, result.first))
                        : l.resultBestAt(ZeShiText.when(l, result.first), TravelText.direction(l, result.first.palace)),
                    meta: [
                      if (!locked) l.travelDirDoor(TravelText.direction(l, result.first.palace), QimenTerms.door(result.first.door, L10n.language)),
                    ],
                  ),
                  if (locked) PremiumLockCard(feature: 'zeshi', text: l.zeshiLockedDetail),
                  for (var i = 0; i < result.length; i++)
                    _SlotCard(
                      rank: i + 1,
                      slot: result[i],
                      locked: locked,
                      onChart: () => _showChart(result[i]),
                      onCalendar: () => _addToCalendar(result[i]),
                      onSave: () => _saveSlot(result[i]),
                    ),
                ],
                const SizedBox(height: 12),
                Text(l.zeshiFootnote(_window.label(l), _perDayLabel(l)), style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
                const SizedBox(height: 4),
                Text(l.homeDisclaimer, style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
              ],
            ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard(
      {required this.rank, required this.slot, required this.locked, required this.onChart, required this.onCalendar, required this.onSave});

  final int rank;
  final ZeShiSlot slot;
  final bool locked;
  final VoidCallback onChart, onCalendar, onSave;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final theme = Theme.of(context);
    final s = slot;
    final good = s.flags.where(ZeShiText.isPlus).map((f) => ZeShiText.flag(l, f)).join('、');
    final bad = s.flags.where((f) => !ZeShiText.isPlus(f)).map((f) => ZeShiText.flag(l, f)).join('、');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: locked ? null : onChart,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$rank', style: serif(theme.textTheme.headlineSmall).copyWith(color: qm.primary, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ZeShiText.when(l, s), style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                if (locked)
                  BlurredText(l.travelDirDoor(TravelText.direction(l, s.palace), QimenTerms.door(s.door, L10n.language)),
                      style: serif(theme.textTheme.titleMedium).copyWith(color: qm.text))
                else ...[
                  Text(l.travelDirDoor(TravelText.direction(l, s.palace), QimenTerms.door(s.door, L10n.language)),
                      style: serif(theme.textTheme.titleMedium).copyWith(color: qm.text)),
                  if (good.isNotEmpty) Text('＋ $good', style: theme.textTheme.bodySmall?.copyWith(color: qm.good)),
                  if (bad.isNotEmpty) Text('－ $bad', style: theme.textTheme.bodySmall?.copyWith(color: qm.bad)),
                ],
              ]),
            ),
            Column(children: [
              ToneBadge(tone: toneOfLevel(s.level), label: TravelText.level(l, s.level)),
              if (!locked) ...[
                IconButton(tooltip: l.zeshiAddCalendar, icon: const Icon(Icons.event_available_outlined), onPressed: onCalendar),
                IconButton(tooltip: l.recordSaveTitle, icon: const Icon(Icons.bookmark_add_outlined), onPressed: onSave),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
