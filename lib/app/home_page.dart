import 'package:flutter/material.dart';

import '../engine/engine.dart' hide Element;
import '../features/divination/divination_page.dart';
import '../features/travel/travel_page.dart';
import '../l10n/l10n.dart';
import '../core/records/record_store.dart';
import '../features/records/record_actions.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'widgets/chart_board.dart';
import 'widgets/guide.dart';
import 'widgets/share_capture.dart';

/// 首頁：目前的時盤／月盤／年盤（九宮格）。可前後切換；直式上下排、橫式／平板左右排。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _engine = ShiJiaEngine();
  final _shareKey = GlobalKey();
  final _settings = AppSettings.instance;
  DateTime _instant = DateTime.now();
  PanUnit _unit = PanUnit.hour;
  late QimenChart _chart = _compute();
  bool _capturing = false;

  QimenChart _compute() =>
      _engine.compute(_instant, settings: _settings.timeSettingsAt(_instant), method: _settings.juMethod, unit: _unit);

  void _setUnit(PanUnit u) => setState(() {
        _unit = u;
        _chart = _compute();
      });

  /// 前後切換一個單位（時辰／月／年）。月、年取同一日；遇月底則取該月最後一天。
  DateTime _shift(int n) => switch (_unit) {
        PanUnit.month => _addMonths(_instant, n),
        PanUnit.year => _addMonths(_instant, 12 * n),
        _ => _instant.add(Duration(hours: 2 * n)),
      };

  static DateTime _addMonths(DateTime t, int n) {
    final m0 = t.month - 1 + n;
    final y = t.year + (m0 / 12).floor();
    final m = m0 % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, t.day > last ? last : t.day, t.hour, t.minute);
  }

  void _set(DateTime t) => setState(() {
        _instant = t;
        _chart = _compute();
      });

  void _onSettings() => setState(() => _chart = _compute());

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showGuide();
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    super.dispose();
  }

  Future<void> _showGuide({bool force = false}) {
    final l = context.l10n;
    return showGuide(
      context,
      'home',
      [
        GuidePage(icon: Icons.grid_view_rounded, title: l.guideHome1Title, body: l.guideHome1Body),
        GuidePage(icon: Icons.door_front_door_outlined, title: l.guideHome2Title, body: l.guideHome2Body),
        GuidePage(icon: Icons.schedule, title: l.guideHome3Title, body: l.guideHome3Body),
      ],
      force: force,
    );
  }

  Future<void> _share() async {
    final l = context.l10n;
    setState(() => _capturing = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await shareBoundary(_shareKey, text: '${l.appTitle} ${l.homeJu(_chart.dun.zh, _chart.ju, _chart.yuan.zh)}');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// 分享卡片的範圍：盤頭＋九宮格（擷取時加上 App 名稱與聲明）。
  Widget _shareBlock(BuildContext context, Widget info, Widget board) {
    final qm = context.qm;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: qm.textMuted);
    return RepaintBoundary(
      key: _shareKey,
      child: Container(
        color: qm.background,
        padding: _capturing ? const EdgeInsets.all(12) : EdgeInsets.zero,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          info,
          const SizedBox(height: 10),
          board,
          if (_capturing) ...[
            const SizedBox(height: 8),
            Row(children: [
              Text(context.l10n.appTitle, style: small?.copyWith(color: qm.primary)),
              const Spacer(),
              Text(context.l10n.homeDisclaimer, style: small),
            ]),
          ],
        ]),
      ),
    );
  }

  /// 記下這一盤（紀錄＋事後應驗回饋）。
  Future<void> _saveRecord() {
    final l = context.l10n;
    final c = _chart;
    return saveRecord(context,
        kind: RecordKind.chart,
        chartAt: _instant,
        summary: '${l.homeJu(c.dun.zh, c.ju, c.yuan.zh)}${l.separator}${l.homeZhiShi(QimenTerms.door(c.zhiShi, L10n.language))}');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), tooltip: l.guideTooltip, onPressed: () => _showGuide(force: true)),
          IconButton(icon: const Icon(Icons.ios_share), tooltip: l.homeShare, onPressed: _capturing ? null : _share),
          IconButton(icon: const Icon(Icons.bookmark_add_outlined), tooltip: l.recordSaveTitle, onPressed: _saveRecord),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 560;
          final info = ChartInfo(chart: _chart, instant: _instant);
          final nav = _HourNav(
            prevLabel: switch (_unit) { PanUnit.month => l.homePrevMonth, PanUnit.year => l.homePrevYear, _ => l.homePrevHour },
            nextLabel: switch (_unit) { PanUnit.month => l.homeNextMonth, PanUnit.year => l.homeNextYear, _ => l.homeNextHour },
            onPrev: () => _set(_shift(-1)),
            onNow: () => _set(DateTime.now()),
            onNext: () => _set(_shift(1)),
          );
          final units = SegmentedButton<PanUnit>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: PanUnit.hour, label: Text(l.unitHour)),
              ButtonSegment(value: PanUnit.month, label: Text(l.unitMonth)),
              ButtonSegment(value: PanUnit.year, label: Text(l.unitYear)),
            ],
            selected: {_unit},
            onSelectionChanged: (v) => _setUnit(v.first),
          );
          final board = ChartBoard(chart: _chart);
          final actions = Row(children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TravelPage())),
                child: Text(l.homeTravel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DivinationPage())),
                child: Text(l.homeDivination),
              ),
            ),
          ]);
          final unitNote = _unit == PanUnit.hour
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.homeUnitNote,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
                );
          final footer = Text(l.homeDisclaimer,
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.qm.textMuted));
          final hint = Text(l.homeTapHint,
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.qm.textMuted));
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: (box.maxHeight * 0.85).clamp(320.0, box.maxWidth * 0.6),
                  child: SingleChildScrollView(child: _shareBlock(context, info, board)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListView(children: [units, unitNote, const SizedBox(height: 8), hint, const SizedBox(height: 12), nav, const SizedBox(height: 8), actions, const SizedBox(height: 12), footer]),
                ),
              ]),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              units,
              unitNote,
              const SizedBox(height: 8),
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: _shareBlock(context, info, board))),
              const SizedBox(height: 6),
              hint,
              const SizedBox(height: 10),
              nav,
              const SizedBox(height: 8),
              actions,
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
          Text(l.homeTime(time, QimenTerms.solarTerm(c.termIndex, lang)), style: muted),
          const SizedBox(height: 4),
          Text(l.homePillars('${c.year}', '${c.month}', '${c.day}', '${c.hour}'),
              style: serif(text.titleMedium).copyWith(color: qm.text)),
          const SizedBox(height: 4),
          Text(l.homeJu(QimenTerms.dun(c.dun, lang), c.ju, QimenTerms.yuan(c.yuan, lang)), style: serif(text.titleMedium).copyWith(color: qm.primary, fontWeight: FontWeight.w700)),
          // 起局依據：讓使用者能對照書本（節氣見上一行）
          if (c.fuTou != null)
            Text([
              l.homeFuTou('${c.fuTou}'),
              if (c.chaoShen != null) c.chaoShen! >= 0 ? l.homeChaoShen(c.chaoShen!) : l.homeJieQi(-c.chaoShen!),
              if (c.leap) l.homeLeap,
            ].join(l.separator), style: muted),
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
  const _HourNav({
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNow,
    required this.onNext,
  });

  final String prevLabel, nextLabel;
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
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.chevron_left, size: 20), label(prevLabel)]),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: FilledButton(onPressed: onNow, child: Text(l.homeNow))),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton(
          style: style,
          onPressed: onNext,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [label(nextLabel), const Icon(Icons.chevron_right, size: 20)]),
        ),
      ),
    ]);
  }
}
