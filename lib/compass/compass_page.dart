import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../app/theme/app_theme.dart';
import '../engine/engine.dart' hide Element;
import '../l10n/l10n.dart';
import 'compass_intro.dart';
import 'compass_math.dart';
import 'declination.dart';

/// 奇門羅盤（HANDOFF §4）：八門盤依手機朝向反向旋轉，對準現實方位。
class CompassPage extends StatefulWidget {
  const CompassPage({super.key});

  @override
  State<CompassPage> createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> {
  static const _engine = ShiJiaEngine();

  final _field = MagneticMonitor();
  final _gyro = GyroLock();
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _ticker;

  double? _magHeading; // 平滑後的磁北方位角
  double? _accuracyDeg;
  bool _noSensor = false;
  double _tilt = 0;

  bool _trueNorth = false;
  double? _declination;
  bool _locating = false;

  late QimenChart _chart;
  QimenChart? _nextChart;
  DateTime? _nextAt;
  bool _showNext = false;
  Door? _target;

  QimenChart _computeAt(DateTime t) =>
      _engine.compute(t, settings: TimeSettings(utcOffset: t.toLocal().timeZoneOffset));

  @override
  void initState() {
    super.initState();
    _refreshCharts();
    _loadPrefs();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final at = _nextAt;
      if (at != null && !DateTime.now().isBefore(at)) _refreshCharts();
      setState(() {}); // 倒數
    });

    final compass = FlutterCompass.events;
    if (compass == null) {
      _noSensor = true;
    } else {
      _subs.add(compass.listen((e) {
        final h = e.heading;
        if (h == null) {
          if (!_noSensor) setState(() => _noSensor = true);
          return;
        }
        setState(() {
          _noSensor = false;
          _magHeading = smoothHeading(_magHeading, h);
          _accuracyDeg = e.accuracy;
        });
      }, onError: (_) => setState(() => _noSensor = true)));
    }
    _subs.add(magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) => _field.add(e.x, e.y, e.z), onError: (_) {}));
    _subs.add(gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen((e) => _gyro.update(e.z, DateTime.now()), onError: (_) {}));
    _subs.add(accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) => _tilt = tiltDegrees(e.x, e.y, e.z), onError: (_) {}));
  }

  Future<void> _loadPrefs() async {
    final p = await CompassPrefs.load();
    if (!mounted) return;
    setState(() {
      _declination = p.declination;
      _trueNorth = p.trueNorth && p.declination != null;
    });
    if (!p.introSeen) {
      await CompassPrefs.markIntroSeen();
      if (mounted) await showCompassIntro(context);
    }
  }

  void _refreshCharts() {
    final now = DateTime.now();
    _chart = _computeAt(now);
    _nextAt = nextChartChange(now, _computeAt);
    _nextChart = _nextAt == null ? null : _computeAt(_nextAt!.add(const Duration(seconds: 1)));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  double? get _heading {
    if (_gyro.locked) return _gyro.heading; // 鎖定時已含北方基準
    final h = _magHeading;
    if (h == null) return null;
    return _trueNorth && _declination != null ? normalizeDeg(h + _declination!) : h;
  }

  QimenChart get _shown => _showNext && _nextChart != null ? _nextChart! : _chart;

  Future<void> _setTrueNorth(bool on) async {
    if (!on || _declination != null) {
      setState(() => _trueNorth = on);
      CompassPrefs.saveNorth(on, null);
      return;
    }
    setState(() => _locating = true);
    final r = await Declination.locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _declination = r.degrees;
      _trueNorth = r.degrees != null;
    });
    CompassPrefs.saveNorth(_trueNorth, r.degrees);
    if (r.error != null) {
      final l = context.l10n;
      final msg = switch (r.error!) {
        DeclinationError.serviceOff => l.compassLocationOff,
        DeclinationError.denied => l.compassLocationDenied,
        DeclinationError.unavailable => l.compassLocationFailed,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final heading = _heading;
    final chart = _shown;
    return Scaffold(
      appBar: AppBar(title: Text(l.compassTitle), actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: l.compassIntroInfo,
          onPressed: () => showCompassIntro(context),
        ),
      ]),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight && box.maxWidth > 600;
          final dial = _Dial(chart: chart, heading: heading ?? 0, target: _target, live: heading != null);
          final panel = _panel(context, heading, chart);
          if (wide) {
            return Row(children: [
              Expanded(child: Padding(padding: const EdgeInsets.all(16), child: Center(child: dial))),
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: panel)),
            ]);
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.min(box.maxWidth, 420)),
              child: Center(child: dial),
            ),
            const SizedBox(height: 12),
            ...panel,
          ]);
        }),
      ),
    );
  }

  List<Widget> _panel(BuildContext context, double? heading, QimenChart chart) {
    final l = context.l10n;
    final lang = L10n.language;
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    // 前方
    if (heading != null) {
      final door = doorAtBearing(chart, heading);
      widgets.add(Text(
        l.compassAhead(QimenTerms.door(door, lang), _luckLabel(l, door.luck)),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge?.copyWith(color: context.qm.luck(door.luck)),
      ));
      widgets.add(Text('${_dirLabel(l, palaceAtBearing(heading))} ${heading.round()}°',
          textAlign: TextAlign.center, style: theme.textTheme.bodyMedium));
    } else {
      widgets.add(Text(_noSensor ? l.compassNoSensor : l.compassWaiting, textAlign: TextAlign.center));
    }

    // 狀態提示
    final notes = <String>[];
    switch (_field.status) {
      case FieldStatus.outOfRange:
        notes.add(l.compassInterference(_field.strength!.round()));
      case FieldStatus.unstable:
        notes.add(l.compassUnstable);
      case FieldStatus.ok:
      case FieldStatus.unknown:
        break;
    }
    final acc = accuracyFromDegrees(_accuracyDeg);
    if (acc == CompassAccuracy.low || _field.status != FieldStatus.ok && _field.status != FieldStatus.unknown) {
      notes.add(l.compassCalibrate);
    }
    if (_tilt > 25) notes.add(l.compassKeepFlat);
    widgets.add(const SizedBox(height: 8));
    widgets.add(Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 4, children: [
      Chip(label: Text(l.compassAccuracy(_accuracyLabel(l, acc))), visualDensity: VisualDensity.compact),
      if (_field.strength != null)
        Chip(label: Text('${_field.strength!.round()} μT'), visualDensity: VisualDensity.compact),
    ]));
    if (_gyro.locked) notes.clear();
    for (final n in notes) {
      widgets.add(Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(n, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
        ),
      ));
    }

    // 室內鎖定（房間內金屬、家電多：先在門口或陽台鎖定，再走到房間中心）
    widgets.add(const SizedBox(height: 8));
    widgets.add(SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l.compassLock),
      subtitle: Text(_gyro.locked ? l.compassLockOn : l.compassLockHint),
      value: _gyro.locked,
      onChanged: heading == null && !_gyro.locked
          ? null
          : (on) => setState(() => on ? _gyro.lock(heading!) : _gyro.unlock()),
    ));

    // 北方基準
    widgets.add(const SizedBox(height: 8));
    widgets.add(Center(
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text(l.compassMagneticNorth)),
          ButtonSegment(
            value: true,
            label: Text(l.compassTrueNorth),
            icon: _locating ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
          ),
        ],
        selected: {_trueNorth},
        onSelectionChanged: _locating || _gyro.locked ? null : (s) => _setTrueNorth(s.first),
      ),
    ));
    if (_trueNorth && _declination != null) {
      widgets.add(Text(l.compassDeclination(_declination!.toStringAsFixed(1)),
          textAlign: TextAlign.center, style: theme.textTheme.bodySmall));
    }

    // 找吉門
    widgets.add(const SizedBox(height: 16));
    widgets.add(Text(l.compassFindDoor, style: theme.textTheme.titleMedium));
    widgets.add(Wrap(spacing: 6, runSpacing: 4, children: [
      for (final d in const [Door.kai, Door.xiu, Door.sheng, Door.du, Door.jingScene, Door.si, Door.jing, Door.shang])
        ChoiceChip(
          label: Text(d.zh),
          selected: _target == d,
          selectedColor: context.qm.luck(d.luck).withValues(alpha: 0.3),
          onSelected: (on) => setState(() => _target = on ? d : null),
        ),
    ]));
    if (_target != null && heading != null) {
      final delta = turnDelta(heading, doorBearing(chart, _target!));
      final aligned = delta.abs() <= 10;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!aligned) Icon(delta < 0 ? Icons.rotate_left : Icons.rotate_right, size: 32),
          if (aligned) Icon(Icons.check_circle, size: 32, color: context.qm.good),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              aligned
                  ? l.compassAligned(QimenTerms.door(_target!, lang))
                  : (delta < 0 ? l.compassTurnLeft(delta.abs().round()) : l.compassTurnRight(delta.round())),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ]),
      ));
    }

    // 下個時辰
    widgets.add(const SizedBox(height: 16));
    final at = _nextAt;
    if (at != null) {
      final left = at.difference(DateTime.now());
      final hh = left.inHours, mm = left.inMinutes % 60, ss = left.inSeconds % 60;
      final cd = '${hh > 0 ? '$hh:' : ''}${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
      widgets.add(Text(l.compassCountdown(cd), style: theme.textTheme.titleMedium));
      widgets.add(SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.compassPreviewNext),
        subtitle: Text(l.compassNextFrom(
            '${at.toLocal().hour.toString().padLeft(2, '0')}:${at.toLocal().minute.toString().padLeft(2, '0')}')),
        value: _showNext,
        onChanged: (v) => setState(() => _showNext = v),
      ));
      final next = _nextChart;
      if (next != null) {
        widgets.add(Text(
          [
            for (final d in const [Door.kai, Door.xiu, Door.sheng])
              '${d.zh} ${_dirLabel(l, next.palaceOfDoor(d))}',
          ].join('　'),
          style: theme.textTheme.bodyMedium,
        ));
      }
    }
    widgets.add(const SizedBox(height: 16));
    widgets.add(Text(l.homeDisclaimer, style: theme.textTheme.bodySmall, textAlign: TextAlign.center));
    return widgets;
  }
}

String _luckLabel(AppLocalizations l, Luck luck) => switch (luck) {
      Luck.good => l.luckGood,
      Luck.neutral => l.luckNeutral,
      Luck.bad => l.luckBad,
    };

String _accuracyLabel(AppLocalizations l, CompassAccuracy a) => switch (a) {
      CompassAccuracy.high => l.accuracyHigh,
      CompassAccuracy.medium => l.accuracyMedium,
      CompassAccuracy.low => l.accuracyLow,
      CompassAccuracy.unknown => l.accuracyUnknown,
    };

String _dirLabel(AppLocalizations l, int palace) => switch (palace) {
      1 => l.dirN,
      8 => l.dirNE,
      3 => l.dirE,
      4 => l.dirSE,
      9 => l.dirS,
      2 => l.dirSW,
      7 => l.dirW,
      6 => l.dirNW,
      _ => '',
    };

/// 羅盤盤面：八宮扇形依 [heading] 反向旋轉；上方固定指針。
class _Dial extends StatelessWidget {
  const _Dial({required this.chart, required this.heading, required this.target, required this.live});

  final QimenChart chart;
  final double heading;
  final Door? target;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _DialPainter(
          chart: chart,
          heading: heading,
          target: target,
          qm: context.qm,
          line: theme.colorScheme.outline,
          text: theme.colorScheme.onSurface,
          accent: theme.colorScheme.primary,
          dirs: {for (final p in palaceBearing.keys) p: _dirLabel(l, p)},
          live: live,
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.chart,
    required this.heading,
    required this.target,
    required this.qm,
    required this.line,
    required this.text,
    required this.accent,
    required this.dirs,
    required this.live,
  });

  final QimenChart chart;
  final double heading;
  final Door? target;
  final QmPalette qm;
  final Color line, text, accent;
  final Map<int, String> dirs;
  final bool live;

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 14;
    final inner = r * 0.34;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_rad(-heading));

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 1;
    for (final e in palaceBearing.entries) {
      final p = chart[e.key];
      final door = p.door!;
      final color = qm.luck(door.luck);
      final start = _rad(e.value - 22.5 - 90);
      final sweep = _rad(45);
      final isTarget = door == target;
      final fill = Paint()..color = color.withValues(alpha: isTarget ? 0.45 : 0.16);
      final path = Path()
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), start, sweep, true)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: inner), start + sweep, -sweep, false)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
      if (isTarget) {
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = color
              ..strokeWidth = 3);
      }

      // 文字沿半徑排列，字頭朝外。
      canvas.save();
      canvas.rotate(_rad(e.value));
      _text(canvas, door.zh, Offset(0, -r * 0.62), r * 0.13, color, bold: true);
      _text(canvas, '${p.name}${e.key}', Offset(0, -r * 0.83), r * 0.075, text);
      _text(canvas, dirs[e.key]!, Offset(0, -r * 0.43), r * 0.07, text.withValues(alpha: 0.7));
      canvas.restore();
    }
    // 北方記號
    canvas.drawCircle(Offset(0, -r - 7), 4, Paint()..color = const Color(0xFFC0392B));
    canvas.restore();

    // 中央與固定指針
    canvas.drawCircle(c, inner, Paint()..color = accent.withValues(alpha: 0.08));
    final pointer = Path()
      ..moveTo(c.dx, c.dy - r - 12)
      ..lineTo(c.dx - 9, c.dy - r + 8)
      ..lineTo(c.dx + 9, c.dy - r + 8)
      ..close();
    canvas.drawPath(pointer, Paint()..color = live ? accent : line);
    canvas.drawLine(
        c,
        Offset(c.dx, c.dy - inner),
        Paint()
          ..color = live ? accent : line
          ..strokeWidth = 2);
    _text(canvas, '${chart.hour}', c.translate(0, -inner * 0.25), inner * 0.3, text, bold: true);
    _text(canvas, '${chart.dun.zh}${chart.ju}局', c.translate(0, inner * 0.3), inner * 0.2, text);
  }

  void _text(Canvas canvas, String s, Offset at, double size, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s, style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.heading != heading || old.chart != chart || old.target != target || old.qm != qm || old.live != live;
}
