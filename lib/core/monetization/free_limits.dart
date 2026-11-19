/// 免費版限制（比照謙卦 HANDOFF §2.1；奇門 HANDOFF §10）。數值可由 Remote Config 調整
/// （`qm_` 開頭，只設在奇門羅盤 App 條件下），不設就用這裡的預設值。
/// 羅盤、當下時盤永遠免費；出行訣每天有次數限制；擇時、宅盤、占卜解讀屬訂閱（各功能用 [requirePremium]）。
class FreeLimits {
  const FreeLimits({
    this.travelPerDay = 1,
    this.rewardedPerDay = 1,
    this.recordMax = 30,
    this.recordDays = 30,
    this.premiumPreviewOnce = true,
    this.notifyPerDay = 1,
    this.trialPromptDay1 = 3,
    this.trialPromptDay2 = 7,
    this.familyMax = 1,
    this.alertClashFree = false,
    this.wearPremium = false,
  });

  /// 出行訣（走路、跑步、喝水計時）每天免費開始幾次。
  final int travelPerDay;

  /// 每天最多可用獎勵廣告換幾次。
  final int rewardedPerDay;

  /// 免費版紀錄上限（已存的不刪，只是不能再新增）。比照謙卦：30 則、只看最近 30 天。
  final int recordMax;

  /// 免費版紀錄只顯示最近幾天；較早的保留在手機上但上鎖。
  final int recordDays;

  /// 訂閱功能「免費完整體驗一次，之後只看標題」（謙卦做法）。
  final bool premiumPreviewOnce;

  /// 免費版吉時推播每天最多幾則（訂閱最多 6）。
  final int notifyPerDay;

  /// 安裝後第幾天提示一次免費試用（0＝不提示）。
  final int trialPromptDay1, trialPromptDay2;

  /// 家人盤：免費版可存幾位家人（不含自己；訂閱無限）。
  final int familyMax;

  /// 節氣與重要日提醒裡「與家人生年相沖」那一行是否免費（預設訂閱才有；換局、月破、歲破、四離四絕免費）。
  final bool alertClashFree;

  /// 手錶羅盤是否需訂閱（預設免費）。
  final bool wearPremium;

  /// Remote Config 參數名稱與預設值（firebase_telemetry 設定預設值用）。
  static const remoteDefaults = <String, int>{
    'qm_free_travel_per_day': 1,
    'qm_free_rewarded_per_day': 1,
    'qm_free_record_max': 30,
    'qm_free_record_days': 30,
    'qm_premium_preview_once': 1,
    'qm_free_notify_per_day': 1,
    'qm_trial_prompt_day1': 3,
    'qm_trial_prompt_day2': 7,
    'qm_free_family_max': 1,
    'qm_free_alert_clash': 0,
    'qm_wear_premium': 0,
  };

  /// 由遠端數值建立；讀不到或數值不合理就用預設。
  factory FreeLimits.from(int Function(String key, int fallback) read) {
    int v(String k, {int min = 0, int max = 1000}) {
      final d = remoteDefaults[k]!;
      final x = read(k, d);
      return (x < min || x > max) ? d : x;
    }

    return FreeLimits(
      travelPerDay: v('qm_free_travel_per_day', min: 1),
      rewardedPerDay: v('qm_free_rewarded_per_day'),
      recordMax: v('qm_free_record_max', min: 1, max: 100000),
      recordDays: v('qm_free_record_days', min: 1, max: 3650),
      premiumPreviewOnce: v('qm_premium_preview_once', max: 1) == 1,
      notifyPerDay: v('qm_free_notify_per_day', min: 1, max: 6),
      trialPromptDay1: v('qm_trial_prompt_day1', max: 365),
      trialPromptDay2: v('qm_trial_prompt_day2', max: 365),
      familyMax: v('qm_free_family_max', max: 100),
      alertClashFree: v('qm_free_alert_clash', max: 1) == 1,
      wearPremium: v('qm_wear_premium', max: 1) == 1,
    );
  }
}
