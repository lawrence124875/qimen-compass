import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../app/services.dart';
import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart';
import '../../shared/premium/usage_gate.dart';
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import '../../shared/widgets/result_card.dart';
import 'travel_intro.dart';
import 'travel_log.dart';
import 'travel_notify_options.dart';
import 'travel_reminders.dart';
import 'travel_session_page.dart';
import 'travel_text.dart';

/// 出行訣（HANDOFF §5）：選事類 → 當下與接下來的吉時、吉方 → 走路／跑步／喝水法。
class TravelPage extends StatefulWidget {
  const TravelPage({super.key});

  @override
  State<TravelPage> createState() => _TravelPageState();
}

class _TravelPageState extends State<TravelPage> {
  static const _planner = ChuXingPlanner();

  TravelPrefs? _prefs;
  TravelEvent _event = TravelEvent.general;
  List<TravelSlot> _slots = const [];
  bool _notify = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await TravelPrefs.load();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _event = prefs.event;
      _notify = prefs.notify;
      _slots = _compute();
    });
    // 首次進入：3 頁引導，看完結果後才請求通知權限（比照謙卦）。
    if (!prefs.introSeen) {
      await prefs.setIntroSeen();
      if (mounted) await showTravelIntro(context);
    }
    if (!prefs.askedPermission) {
      await prefs.setAskedPermission();
      await Notifications.requestPermission();
      await TravelReminders.reschedule();
    }
  }

  List<TravelSlot> _compute() =>
      _planner.plan(DateTime.now(), _event, settings: TravelReminders.timeSettings, count: 12);

  Future<void> _setEvent(TravelEvent e) async {
    setState(() {
      _event = e;
      _slots = _compute();
    });
    await _prefs?.setEvent(e);
    await TravelReminders.reschedule();
  }

  Future<void> _setNotify(bool v) async {
    if (v && !await Notifications.enabled() && !await Notifications.requestPermission()) {
      if (!mounted) return;
      _snack(context.l10n.travelNotifyDenied, action: (context.l10n.travelOpenSettings, _openSettings));
      return;
    }
    setState(() => _notify = v);
    await _prefs?.setNotify(v);
    await TravelReminders.reschedule();
  }

  void _openSettings() => openAppSettings();

  void _snack(String text, {(String, VoidCallback)? action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      persist: false, // 有按鈕的 SnackBar 預設不會自動消失
      duration: const Duration(seconds: 4),
      action: action == null ? null : SnackBarAction(label: action.$1, onPressed: action.$2),
    ));
  }

  Future<void> _remind(TravelSlot s) async {
    final ok = await TravelReminders.remindSlot(s, _event);
    if (!mounted) return;
    final l = context.l10n;
    if (ok) {
      _snack(l.travelRemindSet(TravelText.timeRange(s)));
    } else {
      _snack(l.travelNotifyDenied, action: (l.travelOpenSettings, _openSettings));
    }
  }

  /// 免費版每天 1 次＋看廣告 1 次（比照謙卦），今天第一次免費使用先播插頁。
  Future<void> _start(TravelSlot s, SessionMode mode) async {
    final pass = await ensureCanUse(context, quota: AppServices.of(context).travelQuota, type: 'travel');
    if (pass == null || !mounted) return;
    if (pass.interstitial) await pauseBeforeResult(context);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TravelSessionPage(slot: s, mode: mode, event: _event)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = _slots.isEmpty ? null : _slots.first;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.travelTitle),
        actions: [
          IconButton(
            tooltip: l.travelLogTitle,
            icon: const Icon(Icons.history),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TravelLogPage())),
          ),
          IconButton(
            tooltip: l.travelIntroAgain,
            icon: const Icon(Icons.info_outline),
            onPressed: () => showTravelIntro(context),
          ),
          IconButton(
            tooltip: l.homeRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _slots = _compute()),
          ),
        ],
      ),
      body: _prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in TravelEvent.values)
                      ChoiceChip(
                        label: Text(TravelText.event(l, e)),
                        selected: e == _event,
                        onSelected: (_) => _setEvent(e),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(TravelText.cover(l, _event), style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
                const SizedBox(height: 16),
                if (now != null) _NowCard(slot: now, onStart: (m) => _start(now, m)),
                const SizedBox(height: 16),
                Text(l.travelUpcoming, style: theme.textTheme.titleMedium),
                for (final s in _slots.skip(1))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${TravelText.timeRange(s)}  ${TravelText.hourName(l, s)}'),
                    subtitle: Text(l.travelDirDoor(
                        TravelText.direction(l, s.palace), QimenTerms.door(s.door, L10n.language))),
                    leading: _LevelBadge(level: s.level),
                    trailing: s.recommended
                        ? IconButton(
                            tooltip: l.travelRemindMe,
                            icon: const Icon(Icons.notifications_active_outlined),
                            onPressed: () => _remind(s),
                          )
                        : null,
                  ),
                const Divider(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.travelNotifySwitch),
                  subtitle: Text(_prefs == null
                      ? l.travelNotifyHint(TravelText.event(l, _event))
                      : '${l.travelNotifyHint(TravelText.event(l, _event))}\n${travelNotifySummary(l, _prefs!)}'),
                  value: _notify,
                  onChanged: _setNotify,
                ),
                if (_notify && _prefs != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.tune, size: 18),
                      label: Text(l.travelNotifyOptions),
                      onPressed: () => showTravelNotifyOptions(context, _prefs!, onChanged: () {
                        if (mounted) setState(() {});
                      }),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(l.homeDisclaimer, style: theme.textTheme.bodySmall),
              ],
            ),
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({required this.slot, required this.onStart});

  final TravelSlot slot;
  final void Function(SessionMode) onStart;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dir = TravelText.direction(l, slot.palace);
    final flags = slot.flags.map((f) => TravelText.flag(l, f)).join('、');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${l.travelNow}  ${TravelText.timeRange(slot)}  ${TravelText.hourName(l, slot)}',
                      style: theme.textTheme.labelLarge),
                ),
                _LevelBadge(level: slot.level),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.travelGoTo(dir, slot.bearing.round()), style: theme.textTheme.headlineSmall),
            Text(QimenTerms.door(slot.door, L10n.language), style: theme.textTheme.titleMedium),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(flags, style: theme.textTheme.bodySmall),
            ],
            if (!slot.recommended) ...[
              const SizedBox(height: 4),
              Text(l.travelNotIdeal, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.directions_walk),
                  label: Text(l.travelWalk),
                  onPressed: () => onStart(SessionMode.walk),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.directions_run),
                  label: Text(l.travelRun),
                  onPressed: () => onStart(SessionMode.run),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.local_drink_outlined),
                  label: Text(l.travelWater),
                  onPressed: () => onStart(SessionMode.water),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final TravelLevel level;

  @override
  Widget build(BuildContext context) => ToneBadge(tone: toneOfLevel(level), label: TravelText.level(context.l10n, level));
}
