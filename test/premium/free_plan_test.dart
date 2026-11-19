import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/core/monetization/free_limits.dart';
import 'package:qimen_compass/shared/premium/trial_prompt.dart';

void main() {
  test('試用提示：第 3、7 天各一次，已顯示不重複', () {
    const days = [3, 7];
    expect(TrialPrompt.due(daysSinceInstall: 2, days: days, shown: const []), isNull);
    expect(TrialPrompt.due(daysSinceInstall: 3, days: days, shown: const []), 3);
    expect(TrialPrompt.due(daysSinceInstall: 5, days: days, shown: const [3]), isNull);
    expect(TrialPrompt.due(daysSinceInstall: 7, days: days, shown: const [3]), 7);
    expect(TrialPrompt.due(daysSinceInstall: 10, days: days, shown: const []), 7);
    expect(TrialPrompt.due(daysSinceInstall: 10, days: const [0, 0], shown: const []), isNull);
  });

  test('免費限制：推播則數與試用天數可由 Remote Config 調整', () {
    const d = FreeLimits();
    expect(d.notifyPerDay, 1);
    expect((d.trialPromptDay1, d.trialPromptDay2), (3, 7));
    final l = FreeLimits.from((k, f) => switch (k) {
          'qm_free_notify_per_day' => 9, // 超出範圍用預設
          'qm_trial_prompt_day1' => 2,
          _ => f,
        });
    expect(l.notifyPerDay, 1);
    expect(l.trialPromptDay1, 2);
  });
}
