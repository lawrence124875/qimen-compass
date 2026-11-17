import 'dart:ui';

/// App 支援的語言（11 語，清單與架構比照謙卦 iching-cards）。
///
/// - 介面文字放在 lib/l10n/app_<語言>.arb；判讀文句庫放在私人 repo qimen-content/<contentFolder>/。
/// - 只有 [ready] 為 true 的語言會出現在 [enabled]。
/// - 新增語言：① 新增 app_xx.arb ② 把該語言的 ready 改成 true（內容寫完、CI 匯入後）。
/// - 奇門術語（八門、九星、八神、宮名）在非中文介面一律保留中文，加上拼音與一句意譯（lib/l10n/terms.dart）。
class AppLanguage {
  const AppLanguage({required this.code, required this.locale, required this.contentFolder, required this.ready});

  /// 與內容資料夾一致的代碼：zh-Hant、en、zh-Hans、ja…
  final String code;

  /// 交給 MaterialApp 的 Locale。繁中要帶 scriptCode Hant，否則 Material 內建文字會用簡體。
  final Locale locale;

  final String contentFolder;

  /// 介面（ARB）與內容是否已完成。
  final bool ready;

  @override
  String toString() => code;
}

class AppLanguages {
  AppLanguages._();

  static const zhHant = AppLanguage(
      code: 'zh-Hant', locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), contentFolder: 'zh-Hant', ready: true);
  static const en = AppLanguage(code: 'en', locale: Locale('en'), contentFolder: 'en', ready: true);
  static const zhHans = AppLanguage(
      code: 'zh-Hans', locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'), contentFolder: 'zh-Hans', ready: false);
  static const ja = AppLanguage(code: 'ja', locale: Locale('ja'), contentFolder: 'ja', ready: false);
  static const ko = AppLanguage(code: 'ko', locale: Locale('ko'), contentFolder: 'ko', ready: false);
  static const vi = AppLanguage(code: 'vi', locale: Locale('vi'), contentFolder: 'vi', ready: false);
  static const es = AppLanguage(code: 'es', locale: Locale('es'), contentFolder: 'es', ready: false);

  /// 葡萄牙文：寫巴西葡萄牙文，任何葡萄牙文地區都用這一份。
  static const pt = AppLanguage(code: 'pt-BR', locale: Locale('pt'), contentFolder: 'pt-BR', ready: false);
  static const id = AppLanguage(code: 'id', locale: Locale('id'), contentFolder: 'id', ready: false);
  static const th = AppLanguage(code: 'th', locale: Locale('th'), contentFolder: 'th', ready: false);

  /// 阿拉伯文：由右至左（MaterialApp 依 locale 自動 RTL）。
  static const ar = AppLanguage(code: 'ar', locale: Locale('ar'), contentFolder: 'ar', ready: false);

  static const all = [zhHant, en, zhHans, ja, ko, vi, es, pt, id, th, ar];

  /// 測試用：建置時加 --dart-define=FORCE_LANG=en，不論手機語言一律用該語言介面。
  static const _forced = String.fromEnvironment('FORCE_LANG');

  static AppLanguage? byCode(String code) {
    for (final l in all) {
      if (l.code == code) return l;
    }
    return null;
  }

  static AppLanguage? get forced => _forced.isEmpty ? null : byCode(_forced);

  static List<AppLanguage> get enabled => [for (final l in all) if (l.ready) l];

  /// 手機語言清單（依偏好順序）→ App 使用的語言。
  /// 中文：標示 Hans 或地區為 CN／SG／MY 優先簡體，其餘優先繁體；沒開放的那一種就用另一種。
  /// 葡萄牙文對應 pt-BR；都對不上時用英文，再不行用繁中。
  static AppLanguage resolve(Iterable<Locale> device, {List<AppLanguage>? available}) {
    final f = available == null ? forced : null;
    if (f != null) return f;
    final langs = available ?? enabled;
    AppLanguage? find(String code) {
      for (final l in langs) {
        if (l.code == code) return l;
      }
      return null;
    }

    for (final d in device) {
      if (d.languageCode == 'zh') {
        final hans = d.scriptCode == 'Hans' || (d.scriptCode == null && const {'CN', 'SG', 'MY'}.contains(d.countryCode));
        final hit = hans ? (find('zh-Hans') ?? find('zh-Hant')) : (find('zh-Hant') ?? find('zh-Hans'));
        if (hit != null) return hit;
        continue;
      }
      final hit = find(d.languageCode == 'pt' ? 'pt-BR' : d.languageCode);
      if (hit != null) return hit;
    }
    return find('en') ?? find('zh-Hant') ?? langs.first;
  }
}
