import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme/app_theme.dart';
import '../../core/monetization/ad_service.dart';
import '../../core/monetization/usage_quota.dart';
import '../../l10n/l10n.dart';
import 'paywall_page.dart';

/// 免費版閘門（比照謙卦 cast_gate）：
/// - [ensureCanUse]：有每日次數的功能（出行訣）。每天 1 次＋看獎勵廣告 1 次（廣告失敗也給）；
///   都用完開訂閱頁。今天第一次免費使用回傳 interstitial = true，結果前呼叫 [pauseBeforeResult]。
/// - [requirePremium]：訂閱功能（擇時、宅盤、占卜解讀）。免費版可完整體驗一次，之後開訂閱頁
///   （回傳 [PremiumAccess.titleOnly]：畫面只顯示標題）。
class UsagePass {
  const UsagePass({required this.interstitial});

  final bool interstitial;
}

Future<UsagePass?> ensureCanUse(BuildContext context, {required UsageQuota quota, required String type}) async {
  final s = AppServices.of(context);
  if (s.isPremium) {
    await quota.recordUse(counted: false);
    return const UsagePass(interstitial: false);
  }
  final allowance = await quota.check();
  if (allowance == UsageAllowance.free) {
    final r = await quota.recordUse();
    if (r.firstEver) s.analytics.log('qm_first_use', {'type': type});
    if (r.dailyFree) s.ads.preloadInterstitial();
    return UsagePass(interstitial: r.dailyFree);
  }
  s.analytics.log('qm_hit_free_limit', {'type': type});
  if (!context.mounted) return null;
  if (allowance == UsageAllowance.exhausted) return _paywall(context, type);
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const _LimitSheet(),
  );
  if (!context.mounted) return null;
  switch (choice) {
    case _Choice.watch:
      final outcome = await s.ads.showRewarded();
      s.analytics.log('qm_rewarded', {'type': type, 'outcome': outcome.name});
      if (outcome == RewardedOutcome.dismissed) return null; // 中途關掉不給；失敗照樣給
      await quota.grantReward();
      if (await quota.check() != UsageAllowance.free) return null;
      await quota.recordUse();
      return const UsagePass(interstitial: false);
    case _Choice.subscribe:
      return _paywall(context, type);
    case null:
      return null;
  }
}

Future<UsagePass?> _paywall(BuildContext context, String type) async {
  final ok = await openPaywall(context, source: '${type}_limit', note: context.l10n.paywallUsageLimitNote);
  return ok ? const UsagePass(interstitial: false) : null;
}

enum PremiumAccess {
  /// 訂閱戶。
  full,

  /// 免費版第一次：完整體驗（已記下用過）。
  preview,

  /// 免費版、體驗過了：只顯示標題（已開過訂閱頁，使用者沒有訂閱）。
  titleOnly,
}

/// 訂閱功能入口呼叫。[feature]：功能 id（例：`zeshi`、`house`、`divination`），統計與體驗紀錄用。
Future<PremiumAccess> requirePremium(BuildContext context, {required String feature}) async {
  final s = AppServices.of(context);
  if (s.isPremium) return PremiumAccess.full;
  if (s.limits.premiumPreviewOnce && !await s.previews.used(feature)) {
    await s.previews.markUsed(feature);
    s.analytics.log('qm_premium_preview', {'feature': feature});
    return PremiumAccess.preview;
  }
  if (!context.mounted) return PremiumAccess.titleOnly;
  final ok = await openPaywall(context, source: feature, note: context.l10n.paywallPremiumNote);
  return ok ? PremiumAccess.full : PremiumAccess.titleOnly;
}

/// 每天第一次免費使用、顯示結果前：過場文字「靜心片刻」，再播一則插頁；載入失敗或超過 3 秒就直接回傳。
Future<void> pauseBeforeResult(BuildContext context) async {
  final s = AppServices.of(context);
  if (s.isPremium || !s.ads.enabled) return;
  final nav = Navigator.of(context);
  final load = s.ads.loadInterstitial(timeout: const Duration(seconds: 3));
  final route = PageRouteBuilder<void>(
    opaque: true,
    pageBuilder: (_, __, ___) => const _PausePage(),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
  unawaited(nav.push(route));
  final pause = Future<void>.delayed(const Duration(milliseconds: 1200));
  final loaded = await load;
  await pause;
  if (loaded == AdLoad.ready) {
    final shown = await s.ads.showInterstitial();
    s.analytics.log(shown ? 'qm_interstitial_shown' : 'qm_interstitial_failed', shown ? const {} : {'reason': 'show_failed'});
  } else {
    s.analytics.log('qm_interstitial_failed', {'reason': loaded.name});
  }
  if (route.isActive) nav.removeRoute(route);
}

class _PausePage extends StatelessWidget {
  const _PausePage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(context.l10n.usagePause,
                  textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: context.qm.textMuted)),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Choice { watch, subscribe }

class _LimitSheet extends StatelessWidget {
  const _LimitSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.usageLimitTitle, style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(l.usageLimitBody, style: t.bodyMedium),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context, _Choice.watch), child: Text(l.usageWatchAd)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(context, _Choice.subscribe), child: Text(l.menuPremium)),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.usageComeTomorrow)),
          ],
        ),
      ),
    );
  }
}
