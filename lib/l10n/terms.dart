import '../engine/qimen_types.dart';
import 'app_languages.dart';

part 'terms_data.dart';

/// 奇門術語的顯示（資料來源：tools/l10n/glossary.json → terms_data.dart，改譯法只改 JSON 再跑 gen）。
/// - 繁中介面：中文；簡中介面：簡體（乾宮不轉成干）。
/// - 其他語言：保留中文，加上帶聲調拼音與該語言的意譯，例如「生門 Shēng Mén (Gate of Life)」。
///   日、韓、越的「意譯」用各自的漢字讀法（せいもん、생문、Sinh Môn），日韓用全形括號。
/// - 盤面格內空間小，用 [doorName]／[starName]／[godName] 只顯示漢字（簡中為簡體）。

/// 盤面標記。
enum ChartMark { kongWang, horse, menPo, jiXing, ruMu }

/// 術語表一筆：繁體、簡體、拼音、各語言意譯。
class TermEntry {
  const TermEntry(this.hant, this.hans, this.pinyin, this.gloss);
  final String hant;
  final String hans;
  final String pinyin;
  final Map<String, String> gloss;

  String hanzi(AppLanguage lang) => lang.code == 'zh-Hans' ? hans : hant;

  String format(AppLanguage lang) {
    if (lang.code.startsWith('zh')) return hanzi(lang);
    final g = gloss[lang.code] ?? gloss['en']!;
    return const {'ja', 'ko'}.contains(lang.code) ? '$hant $pinyin（$g）' : '$hant $pinyin ($g)';
  }
}

class QimenTerms {
  QimenTerms._();

  static String door(Door d, AppLanguage lang) => _doorTerms[d.name]!.format(lang);
  static String star(Star s, AppLanguage lang) => _starTerms[s.name]!.format(lang);
  static String god(God g, AppLanguage lang) => _godTerms[g.name]!.format(lang);
  static String dun(Dun d, AppLanguage lang) => _dunTerms[d.name]!.format(lang);
  static String yuan(Yuan y, AppLanguage lang) => _yuanTerms[y.name]!.format(lang);

  /// 節氣（索引同 solarTermNames，冬至＝0）。
  static String solarTerm(int i, AppLanguage lang) => _solarTermTerms[i].format(lang);

  /// 只要漢字（盤面格內）：繁中以外一律繁體，簡中為簡體。
  static String doorName(Door d, AppLanguage lang) => _doorTerms[d.name]!.hanzi(lang);
  static String starName(Star s, AppLanguage lang) => _starTerms[s.name]!.hanzi(lang);
  static String godName(God g, AppLanguage lang) => _godTerms[g.name]!.hanzi(lang);
  static String dunName(Dun d, AppLanguage lang) => _dunTerms[d.name]!.hanzi(lang);
  static String yuanName(Yuan y, AppLanguage lang) => _yuanTerms[y.name]!.hanzi(lang);
  static String palaceName(int p, AppLanguage lang) => _palaceTerms['$p']!.hanzi(lang);

  /// 宮名，例如「坎宮」或「坎宮 Kǎn (North)」。
  static String palace(int p, AppLanguage lang) => _palaceTerms['$p']!.format(lang);

  static String mark(ChartMark m, AppLanguage lang) => _markTerms[m.name]!.format(lang);

  /// 盤面格內用的單字標記（空、馬、迫、刑、墓），各語言一律漢字（簡中為簡體）。
  static String markShort(ChartMark m, [AppLanguage? lang]) {
    final i = m == ChartMark.kongWang || m == ChartMark.horse ? 0 : 1; // 空亡→空、馬星→馬、門迫→迫、擊刑→刑、入墓→墓
    return _markTerms[m.name]!.hanzi(lang ?? AppLanguages.zhHant).substring(i, i + 1);
  }
}
