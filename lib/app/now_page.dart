import 'dart:async';

import 'package:flutter/material.dart';

import '../compass/compass_page.dart';
import '../engine/engine.dart' hide Element;
import '../features/almanac/almanac_page.dart';
import '../features/divination/divination_page.dart';
import '../features/family/now_cards.dart';
import '../features/lucky/lucky_cards.dart';
import '../features/personal/personal_day_card.dart';
import '../features/travel/travel_page.dart';
import '../features/travel/travel_reminders.dart';
import '../features/travel/travel_text.dart';
import '../features/zeshi/zeshi_page.dart';
import '../l10n/l10n.dart';
import '../shared/premium/usage_gate.dart';
import '../shared/widgets/result_card.dart';
import 'home_page.dart' show ChartInfo;
import 'main_shell.dart';
import 'services.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'widgets/chart_board.dart';

/// 「此刻」首頁（HANDOFF §12 UI 改版）：打開先看到現在的吉方吉門、下一個吉時倒數、今日黃曆；
/// 擇時與問事是大按鈕；九宮格盤面收合，想看再點開。
class NowPage extends StatefulWidget {
  const NowPage({super.key});

  @override
  State<NowPage> createState() => _NowPageState();
}

class _NowPageState extends State<NowPage> {
  static const _planner = ChuXingPlanner();
  static const _engine = ShiJiaEngine();
  List<TravelSlot> _slots = const [];
  late QimenChart _chart;
  DateTime _now = DateTime.now();
  Timer? _timer;

  void _compute() {
    _now = DateTime.now();
    _slots = _planner.plan(_now, TravelEvent.general, settings: TravelReminders.timeSettings, count: 12);
    final app = AppSettings.instance;
    _chart = _engine.compute(_now, settings: app.timeSettingsAt(_now), method: app.juMethod);
  }

  void _onSettings() => setState(_compute);

  @override
  void initState() {
    super.initState();
    _compute();
    AppSettings.instance.addListener(_onSettings);
    // 每 30 秒更新倒數；跨時辰就重算
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final t = DateTime.now();
      setState(() {
        if (_slots.isEmpty || !_slots.first.contains(t.toUtc())) {
          _compute();
        } else {
          _now = t;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    AppSettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _findWithCompass(Door door) {
    CompassPage.pendingTarget = door;
    MainShell.select(MainTab.compass);
  }

  Future<void> _openZeshi() async {
    final access = await peekPremium(context, feature: 'zeshi');
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => ZeShiPage(locked: access == PremiumAccess.titleOnly)));
  }

  String _countdown(AppLocalizations l, Duration d) {
    final m = d.inMinutes.clamp(0, 99999);
    return m >= 60 ? l.nowCountdownHM(m ~/ 60, m % 60) : l.nowCountdownM(m < 1 ? 1 : m);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final s = AppServices.of(context);
    final cur = _slots.isEmpty ? null : _slots.first;
    final next = _slots.skip(1).where((x) => x.recommended).firstOrNull;
    final lang = L10n.language;

    Widget hero() {
      if (cur == null) return const SizedBox.shrink();
      final good = cur.recommended;
      final target = good ? cur : next;
      final headline = good
          ? l.resultGoNow(TravelText.direction(l, cur.palace))
          : next != null
              ? l.resultGoAt(TravelText.timeRange(next).split('–').first, TravelText.direction(l, next.palace))
              : l.resultNoneGood;
      return ResultCard(
        tone: toneOfLevel(cur.level),
        grade: TravelText.level(l, cur.level),
        kicker: '${l.nowBestDir}・${TravelText.timeRange(cur)} ${TravelText.hourName(l, cur)}',
        headline: headline,
        meta: [
          l.travelDirDoor(TravelText.direction(l, cur.palace), QimenTerms.door(cur.door, lang)) +
              (good ? '' : '（${l.travelNotIdeal}）'),
          if (good) l.nowGoodLeft(_countdown(l, cur.endUtc.difference(_now.toUtc()))),
        ],
        footer: Wrap(spacing: 8, runSpacing: 8, children: [
          if (target != null && s.featureEnabled('compass'))
            FilledButton.icon(
              icon: const Icon(Icons.explore_outlined),
              label: Text(l.nowFindWithCompass),
              onPressed: () => _findWithCompass(target.door),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.directions_walk),
            label: Text(l.homeTravel),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TravelPage())),
          ),
        ]),
      );
    }

    Widget nextCard() {
      if (next == null) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(Icons.timer_outlined, color: qm.primary),
          title: Text('${l.nowNextGood}  ${TravelText.timeRange(next)}'),
          subtitle: Text(l.travelDirDoor(TravelText.direction(l, next.palace), QimenTerms.door(next.door, lang))),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            ToneBadge(tone: toneOfLevel(next.level), label: TravelText.level(l, next.level)),
            const SizedBox(height: 2),
            Text(_countdown(l, next.startUtc.difference(_now.toUtc())), style: text.bodySmall?.copyWith(color: qm.textMuted)),
          ]),
        ),
      );
    }

    Widget bigButton(IconData icon, String title, String sub, VoidCallback onTap) => Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            color: qm.primary.withValues(alpha: 0.10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: qm.primary, size: 30),
                  const SizedBox(height: 8),
                  Text(title, style: serif(text.titleLarge).copyWith(color: qm.text, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sub, style: text.bodySmall?.copyWith(color: qm.textMuted)),
                ]),
              ),
            ),
          ),
        );

    final buttons = Row(children: [
      if (s.featureEnabled('zeshi')) ...[
        bigButton(Icons.event_available_outlined, l.tabZeShi, l.nowZeshiSub, _openZeshi),
        const SizedBox(width: 10),
      ],
      bigButton(Icons.help_outline, l.homeDivination, l.nowDivSub,
          () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DivinationPage()))),
    ]);

    final chartFold = DetailsFold(
      title: l.nowShowChart,
      children: [
        ChartInfo(chart: _chart, instant: _now),
        const SizedBox(height: 8),
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: ChartBoard(chart: _chart))),
        const SizedBox(height: 6),
        Text(l.homeTapHint, textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: qm.textMuted)),
        TextButton(onPressed: () => MainShell.select(MainTab.chart), child: Text(l.nowOpenChartTab)),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: () async => setState(_compute),
              child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 16), children: [
                hero(),
                nextCard(),
                if (s.featureEnabled('personal_day')) PersonalDayCard(now: _now),
                if (s.featureEnabled('alerts')) const DayAlertCard(),
                if (s.featureEnabled('family')) const FamilyTodayCard(),
                MessageTimingCard(now: _now),
                buttons,
                const SizedBox(height: 12),
                LuckyColorCard(day: _chart.day),
                if (s.featureEnabled('almanac')) ...[const AlmanacTile(), const SizedBox(height: 12)],
                chartFold,
                Text(l.homeDisclaimer, textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: qm.textMuted)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
