import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/services.dart';
import '../../l10n/l10n.dart';
import 'paywall_page.dart';

/// 免費試用提示：安裝後第 N 天（Remote Config `qm_trial_prompt_day1/2`，預設 3、7）各提示一次。
/// 年訂方案在 Play 已設 7 天免費試用，按鈕直接開訂閱頁。
class TrialPrompt {
  TrialPrompt._();

  static const _kInstall = 'qm_install_date';
  static const _kShown = 'qm_trial_prompt_shown';

  /// 該顯示第幾天的提示（沒有就 null）。純函式，可測試。
  static int? due({required int daysSinceInstall, required List<int> days, required List<int> shown}) {
    int? hit;
    for (final d in days) {
      if (d > 0 && daysSinceInstall >= d && !shown.contains(d)) hit = d;
    }
    return hit;
  }

  static Future<void> maybeShow(BuildContext context) async {
    final s = AppServices.of(context);
    if (s.isPremium) return;
    final SharedPreferences p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final now = DateTime.now();
    final installMs = p.getInt(_kInstall);
    if (installMs == null) {
      await p.setInt(_kInstall, now.millisecondsSinceEpoch);
      return;
    }
    final days = now.difference(DateTime.fromMillisecondsSinceEpoch(installMs)).inDays;
    final shown = [for (final x in p.getStringList(_kShown) ?? const <String>[]) int.tryParse(x) ?? 0];
    final d = due(daysSinceInstall: days, days: [s.limits.trialPromptDay1, s.limits.trialPromptDay2], shown: shown);
    if (d == null || !context.mounted) return;
    // 一次補上所有已過的天數，避免隔天又跳
    final all = {...shown, for (final x in [s.limits.trialPromptDay1, s.limits.trialPromptDay2]) if (x > 0 && days >= x) x};
    await p.setStringList(_kShown, [for (final x in all) '$x']);
    s.analytics.log('qm_trial_prompt', {'day': d});
    final l = context.l10n;
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.trialPromptTitle, style: Theme.of(sheet).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(l.trialPromptBody),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(sheet, true), child: Text(l.trialPromptStart)),
            TextButton(onPressed: () => Navigator.pop(sheet, false), child: Text(l.trialPromptLater)),
          ]),
        ),
      ),
    );
    if (go == true && context.mounted) await openPaywall(context, source: 'trial_day$d');
  }
}
