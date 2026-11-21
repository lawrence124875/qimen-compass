import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../features/travel/travel_page.dart';
import '../features/widget/home_widget_sync.dart';
import '../l10n/l10n.dart';
import '../shared/premium/ad_banner.dart';
import '../shared/premium/paywall_page.dart';
import '../shared/premium/trial_prompt.dart';
import 'compass_tab.dart';
import 'home_page.dart';
import 'now_page.dart';
import 'pages/me_page.dart';
import 'services.dart';

/// 底部 4 分頁：此刻／羅盤（羅盤⇄地圖）／盤面／我的（HANDOFF §12 UI 改版）。
/// 擇時、問事是此刻頁的大按鈕。此刻、盤面、我的切走後保留狀態；羅盤只在選到時建立（離開就停感測器）。
/// 羅盤可由 Remote Config `qm_feature_compass` 關閉（關閉時不顯示分頁）。
enum MainTab { now, compass, chart, me }

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initial = MainTab.now});

  final MainTab initial;

  /// 其他畫面（含推上去的頁面）切換分頁，例：課程按鈕開羅盤。呼叫前先 pop 回首頁。
  static final tabRequest = ValueNotifier<MainTab?>(null);

  static void select(MainTab tab) {
    tabRequest.value = null;
    tabRequest.value = tab;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late MainTab _tab = widget.initial;
  final _built = <MainTab>{};

  void _onRequest() {
    final t = MainShell.tabRequest.value;
    if (t != null) _select(t);
  }

  @override
  void initState() {
    super.initState();
    MainShell.tabRequest.addListener(_onRequest);
    // 桌面小工具：每次開 App、訂閱狀態改變時重算 7 天；點小工具開對應頁面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppServices.of(context);
      if (s.featureEnabled('widget')) {
        _premium = s.premium.isPremium..addListener(_syncWidget);
        // 小工具要算 7 天資料：首頁畫好後再做，不拖慢啟動
        Future<void>.delayed(const Duration(seconds: 3), _syncWidget);
        HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetUri, onError: (_) {});
        _widgetSub = HomeWidget.widgetClicked.listen(_onWidgetUri, onError: (_) {});
      }
      TrialPrompt.maybeShow(context);
    });
  }

  ValueListenable<bool>? _premium;
  StreamSubscription<Uri?>? _widgetSub;

  void _syncWidget() {
    if (mounted) QimenHomeWidget.sync(context.l10n, premium: AppServices.of(context).isPremium);
  }

  void _onWidgetUri(Uri? u) {
    if (!mounted || u == null) return;
    switch (u.host) {
      case 'travel':
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TravelPage()));
      case 'paywall':
        openPaywall(context, source: 'widget');
      case 'me':
        _select(MainTab.me);
    }
  }

  @override
  void dispose() {
    MainShell.tabRequest.removeListener(_onRequest);
    _premium?.removeListener(_syncWidget);
    _widgetSub?.cancel();
    super.dispose();
  }

  List<MainTab> _tabs(BuildContext context) {
    final s = AppServices.of(context);
    return [
      MainTab.now,
      if (s.featureEnabled('compass')) MainTab.compass,
      MainTab.chart,
      MainTab.me,
    ];
  }

  void _select(MainTab t) {
    if (t == _tab) return;
    setState(() => _tab = t);
  }

  Widget _page(MainTab t) => switch (t) {
        MainTab.now => const NowPage(),
        MainTab.compass => const CompassTab(),
        MainTab.chart => const HomePage(),
        MainTab.me => const MePage(),
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = _tabs(context);
    if (!tabs.contains(_tab)) _tab = MainTab.now;
    _built.add(_tab);
    return Scaffold(
      body: IndexedStack(
        index: tabs.indexOf(_tab),
        children: [
          for (final t in tabs)
            // 羅盤離開就拆掉（停止磁力計、陀螺儀）；其他分頁建立後保留
            if (t == _tab || (t != MainTab.compass && _built.contains(t))) _page(t) else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const AdBanner(),
        NavigationBar(
          selectedIndex: tabs.indexOf(_tab),
          onDestinationSelected: (i) => _select(tabs[i]),
          destinations: [
            for (final t in tabs)
              switch (t) {
                MainTab.now => NavigationDestination(icon: const Icon(Icons.wb_sunny_outlined), selectedIcon: const Icon(Icons.wb_sunny), label: l.tabNow),
                MainTab.compass => NavigationDestination(icon: const Icon(Icons.explore_outlined), selectedIcon: const Icon(Icons.explore), label: l.tabCompass),
                MainTab.chart => NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view_rounded), label: l.tabChart),
                MainTab.me => NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.tabMe),
              },
          ],
        ),
      ]),
    );
  }
}
