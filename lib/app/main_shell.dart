import 'package:flutter/material.dart';

import '../compass/compass_page.dart';
import '../features/zeshi/zeshi_page.dart';
import '../l10n/l10n.dart';
import '../shared/premium/ad_banner.dart';
import '../shared/premium/usage_gate.dart';
import 'home_page.dart';
import 'pages/me_page.dart';
import 'services.dart';

/// 底部 4 分頁：羅盤（含地圖模式）／盤面／擇時／我的（HANDOFF §12 P1）。
/// 盤面、擇時、我的切走後保留狀態；羅盤只在選到時建立（離開就停感測器）。
/// 羅盤、擇時可由 Remote Config `qm_feature_compass`／`qm_feature_zeshi` 關閉（關閉時不顯示分頁）。
enum MainTab { compass, chart, zeshi, me }

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initial = MainTab.chart});

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
  }

  @override
  void dispose() {
    MainShell.tabRequest.removeListener(_onRequest);
    super.dispose();
  }

  List<MainTab> _tabs(BuildContext context) {
    final s = AppServices.of(context);
    return [
      if (s.featureEnabled('compass')) MainTab.compass,
      MainTab.chart,
      if (s.featureEnabled('zeshi')) MainTab.zeshi,
      MainTab.me,
    ];
  }

  Future<void> _select(MainTab t) async {
    if (t == _tab) return;
    // 擇時屬訂閱功能：免費版完整體驗一次，之後開訂閱頁；沒訂閱就留在原分頁
    if (t == MainTab.zeshi && !_built.contains(t)) {
      final access = await requirePremium(context, feature: 'zeshi');
      if (access == PremiumAccess.titleOnly || !mounted) return;
    }
    setState(() => _tab = t);
  }

  Widget _page(MainTab t) => switch (t) {
        MainTab.compass => const CompassPage(),
        MainTab.chart => const HomePage(),
        MainTab.zeshi => const ZeShiPage(),
        MainTab.me => const MePage(),
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = _tabs(context);
    if (!tabs.contains(_tab)) _tab = MainTab.chart;
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
                MainTab.compass => NavigationDestination(icon: const Icon(Icons.explore_outlined), selectedIcon: const Icon(Icons.explore), label: l.tabCompass),
                MainTab.chart => NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view_rounded), label: l.tabChart),
                MainTab.zeshi => NavigationDestination(icon: const Icon(Icons.event_outlined), selectedIcon: const Icon(Icons.event), label: l.tabZeShi),
                MainTab.me => NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.tabMe),
              },
          ],
        ),
      ]),
    );
  }
}
