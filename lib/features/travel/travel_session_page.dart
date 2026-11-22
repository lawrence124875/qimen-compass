import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../compass/building_facing.dart';
import '../../engine/engine.dart';
import '../house/heading_tracker.dart';
import '../house/house_widgets.dart' show HeadingPanel;
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import 'travel_log.dart';
import 'travel_reminders.dart';
import 'travel_text.dart';

enum SessionMode { walk, run, water }

/// 出行訣計時：走路、跑步（15–30 分鐘＋計步）、喝水法（在吉方靜置水杯）。
/// 畫面上有指向吉方的箭頭；計時結束另排一則通知，App 在背景也會提醒。
class TravelSessionPage extends StatefulWidget {
  const TravelSessionPage({super.key, required this.slot, required this.mode, required this.event});

  final TravelSlot slot;
  final SessionMode mode;
  final TravelEvent event;

  @override
  State<TravelSessionPage> createState() => _TravelSessionPageState();
}

class _TravelSessionPageState extends State<TravelSessionPage> {
  late final List<int> _choices = widget.mode == SessionMode.water ? const [15, 30, 60] : const [15, 20, 30];
  late int _minutes = _choices[widget.mode == SessionMode.water ? 1 : 0];

  DateTime? _endsAt;
  Duration _left = Duration.zero;
  bool _done = false;
  Timer? _ticker;

  StreamSubscription<StepCount>? _stepSub;
  int? _stepBase;
  int _steps = 0;
  bool _stepsUnavailable = false;

  bool get _running => _endsAt != null && !_done;

  final _heading = HeadingTracker.of(NorthFeature.travel);

  @override
  void initState() {
    super.initState();
    _heading.acquire();
  }

  @override
  void dispose() {
    _heading.release();
    _ticker?.cancel();
    _stepSub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final l = context.l10n;
    final end = DateTime.now().add(Duration(minutes: _minutes));
    setState(() {
      _endsAt = end;
      _left = Duration(minutes: _minutes);
      _done = false;
      _steps = 0;
      _stepBase = null;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (await Notifications.enabled()) {
      await Notifications.schedule(
        id: TravelReminders.sessionEnd,
        title: l.travelSessionDoneTitle,
        body: widget.mode == SessionMode.water ? l.travelWaterDoneBody : l.travelSessionDoneBody,
        atUtc: end.toUtc(),
        channelId: TravelReminders.channelId,
        channelName: l.travelChannelName,
      );
    }
    if (widget.mode != SessionMode.water) await _startSteps();
  }

  Future<void> _startSteps() async {
    if (Platform.isAndroid && !(await Permission.activityRecognition.request()).isGranted) {
      if (mounted) setState(() => _stepsUnavailable = true);
      return;
    }
    _stepSub = Pedometer.stepCountStream.listen(
      (e) {
        if (!mounted) return;
        setState(() {
          _stepBase ??= e.steps;
          _steps = e.steps - _stepBase!;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _stepsUnavailable = true);
      },
    );
  }

  void _tick() {
    final left = _endsAt!.difference(DateTime.now());
    if (left <= Duration.zero) {
      _finish(completed: true);
    } else {
      setState(() => _left = left);
    }
  }

  Future<void> _finish({required bool completed}) async {
    _ticker?.cancel();
    await _stepSub?.cancel();
    _stepSub = null;
    if (!completed) await Notifications.cancel(TravelReminders.sessionEnd);
    if (completed) {
      await TravelLog.add(TravelRecord(
        at: DateTime.now(),
        mode: widget.mode.name,
        minutes: _minutes,
        steps: _steps,
        door: widget.slot.door,
        palace: widget.slot.palace,
        event: widget.event,
      ));
    }
    if (!mounted) return;
    setState(() {
      _done = true;
      _left = Duration.zero;
      if (!completed) _endsAt = null;
    });
  }

  String get _clock {
    final m = _left.inMinutes.toString().padLeft(2, '0');
    final s = (_left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final slot = widget.slot;
    final dir = TravelText.direction(l, slot.palace);
    final title = switch (widget.mode) {
      SessionMode.walk => l.travelWalk,
      SessionMode.run => l.travelRun,
      SessionMode.water => l.travelWater,
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.travelGoTo(dir, slot.bearing.round()), style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          Text('${QimenTerms.door(slot.door, L10n.language)}  ${TravelText.timeRange(slot)}',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(child: _DirectionArrow(bearing: slot.bearing, tracker: _heading)),
          const SizedBox(height: 8),
          const HeadingPanel(compact: true, feature: NorthFeature.travel, showHeading: false),
          const SizedBox(height: 16),
          Text(
            widget.mode == SessionMode.water ? l.travelWaterGuide(dir) : l.travelWalkGuide(dir),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_endsAt == null)
            Center(
              child: SegmentedButton<int>(
                segments: [for (final m in _choices) ButtonSegment(value: m, label: Text(l.travelMinutes(m)))],
                selected: {_minutes},
                onSelectionChanged: (s) => setState(() => _minutes = s.first),
              ),
            ),
          if (_endsAt != null) ...[
            Text(_done ? l.travelSessionDoneTitle : _clock,
                style: theme.textTheme.displayMedium, textAlign: TextAlign.center),
            if (widget.mode != SessionMode.water)
              Text(_stepsUnavailable ? l.travelStepsUnavailable : l.travelSteps(_steps),
                  style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          Center(
            child: _running
                ? OutlinedButton(onPressed: () => _finish(completed: false), child: Text(l.travelStop))
                : FilledButton(onPressed: _start, child: Text(_done ? l.travelAgain : l.travelStart)),
          ),
        ],
      ),
    );
  }
}

/// 指向吉方的箭頭（依所選北方基準即時旋轉；沒有磁力計時只顯示方位角）。
class _DirectionArrow extends StatelessWidget {
  const _DirectionArrow({required this.bearing, required this.tracker});

  final double bearing;
  final HeadingTracker tracker;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final heading = tracker.heading;
        final angle = heading == null ? 0.0 : (bearing - heading) * math.pi / 180;
        final basis = tracker.showsMagnetic ? l.compassMagneticNorth : l.compassTrueNorth;
        return Column(
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.outline, width: 2)),
              child: Transform.rotate(
                angle: angle,
                child: Icon(Icons.navigation, size: 96, color: heading == null ? cs.outline : cs.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(heading == null ? l.travelNoCompass(bearing.round()) : '${l.travelHeading(heading.round() % 360)} · $basis'),
          ],
        );
      },
    );
  }
}
