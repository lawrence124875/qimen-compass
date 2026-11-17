import 'package:flutter/material.dart';

import '../compass/compass_page.dart';
import '../engine/engine.dart' hide Element;
import '../features/house/house_page.dart';
import '../features/travel/travel_page.dart';
import '../l10n/l10n.dart';
import 'pages/settings_page.dart';
import 'theme/app_theme.dart';
import 'widgets/chart_board.dart';

/// 首頁：目前時盤（九宮格）。可前後切換時辰；直式上下排、橫式／平板左右排。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _engine = ShiJiaEngine();
  DateTime _instant = DateTime.now();
  late QimenChart _chart = _compute();

  QimenChart _compute() => _engine.compute(_instant, settings: TimeSettings(utcOffset: _instant.timeZoneOffset));

  void _set(DateTime t) => setState(() {
        _instant = t;
        _chart = _compute();
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.settingsTitle,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 560;
          final info = ChartInfo(chart: _chart, instant: _instant);
          final nav = _HourNav(
            onPrev: () => _set(_instant.subtract(const Duration(hours: 2))),
            onNow: () => _set(DateTime.now()),
            onNext: () => _set(_instant.add(const Duration(hours: 2))),
          );
          final board = ChartBoard(chart: _chart);
          final compass = FilledButton.icon(
            icon: const Icon(Icons.explore),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CompassPage())),
            label: Text(l.homeOpenCompass),
          );
          final travel = FilledButton.tonal(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TravelPage())),
            child: Text(l.homeTravel),
          );
          final house = FilledButton.tonal(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HousePage())),
            child: Text(l.homeHouse),
          );
          final footer = Text(l.homeDisclaimer,
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.qm.textMuted));
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxHeight - 32), child: board),
                const SizedBox(width: 16),
                Expanded(
                  child: ListView(children: [info, const SizedBox(height: 12), nav, const SizedBox(height: 8), compass, const SizedBox(height: 8), travel, const SizedBox(height: 8), house, const SizedBox(height: 12), footer]),
                ),
              ]),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              info,
              const SizedBox(height: 10),
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: board)),
              const SizedBox(height: 6),
              Text(l.homeTapHint,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
              const SizedBox(height: 10),
              nav,
              const SizedBox(height: 8),
              compass,
              const SizedBox(height: 8),
              travel,
              const SizedBox(height: 8),
              house,
              const SizedBox(height: 12),
              footer,
            ],
          );
        }),
      ),
    );
  }
}

/// 盤頭資訊：時間與節氣、四柱、局數、值符值使、旬首、伏吟反吟。
class ChartInfo extends StatelessWidget {
  const ChartInfo({super.key, required this.chart, required this.instant});

  final QimenChart chart;
  final DateTime instant;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final c = chart;
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${instant.year}-${two(instant.month)}-${two(instant.day)} ${two(instant.hour)}:${two(instant.minute)}';
    final flags = [
      if (c.starFuYin) l.flagStarFuYin,
      if (c.starFanYin) l.flagStarFanYin,
      if (c.doorFuYin) l.flagDoorFuYin,
      if (c.doorFanYin) l.flagDoorFanYin,
    ];
    final muted = text.bodyMedium?.copyWith(color: qm.textMuted);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.homeTime(time, solarTermNames[c.termIndex]), style: muted),
          const SizedBox(height: 4),
          Text(l.homePillars('${c.year}', '${c.month}', '${c.day}', '${c.hour}'),
              style: serif(text.titleMedium).copyWith(color: qm.text)),
          const SizedBox(height: 4),
          Text(l.homeJu(c.dun.zh, c.ju, c.yuan.zh), style: serif(text.titleMedium).copyWith(color: qm.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(spacing: 16, runSpacing: 2, children: [
            Text(l.homeZhiFu(QimenTerms.star(c.zhiFu, lang)), style: muted),
            Text(l.homeZhiShi(QimenTerms.door(c.zhiShi, lang)), style: muted),
            Text(l.homeXun('${c.xunShou}'), style: muted),
          ]),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final f in flags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: qm.bad), borderRadius: BorderRadius.circular(6)),
                  child: Text(f, style: text.bodySmall?.copyWith(color: qm.bad)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _HourNav extends StatelessWidget {
  const _HourNav({required this.onPrev, required this.onNow, required this.onNext});

  final VoidCallback onPrev, onNow, onNext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6));
    Widget label(String s) => Flexible(child: Text(s, maxLines: 1, overflow: TextOverflow.fade, softWrap: false));
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          style: style,
          onPressed: onPrev,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.chevron_left, size: 20), label(l.homePrevHour)]),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: FilledButton(onPressed: onNow, child: Text(l.homeNow))),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton(
          style: style,
          onPressed: onNext,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [label(l.homeNextHour), const Icon(Icons.chevron_right, size: 20)]),
        ),
      ),
    ]);
  }
}
