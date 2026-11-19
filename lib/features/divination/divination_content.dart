import 'dart:convert';

import 'package:flutter/services.dart';

import '../../engine/engine.dart';
import '../../l10n/l10n.dart';

/// 事類問事的內容：用神對照表＋依語言分檔的文句庫。
/// 檔案在私人 repo qimen-content `app/divination/`，CI 建置時複製到 `assets/content/divination/`。
class DivinationContent {
  DivinationContent(this.rules, this.text);

  final DivinationRules rules;
  final DivinationText text;

  static const _dir = 'assets/content/divination';
  static DivinationContent? _cache;
  static String? _cacheLang;

  /// 讀不到（例如本機沒有內容檔）時回傳 null。
  static Future<DivinationContent?> load(AppLanguage lang, {AssetBundle? bundle}) async {
    if (_cache != null && _cacheLang == lang.code) return _cache;
    final b = bundle ?? rootBundle;
    try {
      final rules = DivinationRules.fromJson(jsonDecode(await b.loadString('$_dir/rules.json')) as Map<String, dynamic>);
      final fallback = jsonDecode(await b.loadString('$_dir/text/en.json')) as Map<String, dynamic>;
      Map<String, dynamic>? main;
      for (final code in {lang.code, lang.code.split('-').first}) {
        try {
          main = jsonDecode(await b.loadString('$_dir/text/$code.json')) as Map<String, dynamic>;
          break;
        } catch (_) {}
      }
      _cacheLang = lang.code;
      return _cache = DivinationContent(rules, DivinationText(main ?? fallback, fallback, lang));
    } catch (_) {
      return null;
    }
  }
}

/// 文句庫。缺的鍵退回英文，再退回鍵名本身。
class DivinationText {
  DivinationText(this._j, this._en, this.lang);

  final Map<String, dynamic> _j, _en;
  final AppLanguage lang;

  dynamic _get(Map<String, dynamic> m, List<String> path) {
    dynamic v = m;
    for (final k in path) {
      if (v is! Map<String, dynamic>) return null;
      v = v[k];
    }
    return v;
  }

  dynamic _lookup(List<String> path) => _get(_j, path) ?? _get(_en, path);

  String _s(List<String> path) => (_lookup(path) as String?) ?? path.join('.');

  String topicName(String t) => _s(['topics', t, 'name']);
  String topicDesc(String t) => _s(['topics', t, 'desc']);
  String topicAsk(String t) => _s(['topics', t, 'ask']);

  /// 事類的常用問題（點一下帶入輸入框）。
  List<String> topicExamples(String t) => ((_lookup(['topics', t, 'examples']) as List?) ?? const []).cast<String>();
  String schoolName(String s) => _s(['schools', s, 'name']);
  String schoolDesc(String s) => _s(['schools', s, 'desc']);
  String get disclaimer => _s(['disclaimer']);

  String yongShen(YongShen y) => (_lookup(['yongShen', y.key]) as String?) ?? y.value ?? y.key;

  /// 依盤面固定挑一句總評。
  String verdict(Reading r) {
    final list = (_lookup(['topics', r.topic, 'verdict', r.verdict.name]) as List?)?.cast<String>() ?? const [];
    return list.isEmpty ? '' : list[r.seed % list.length];
  }

  String advice(Reading r) => _s(['topics', r.topic, 'advice', r.verdict.name]);

  /// 判斷因素的說明（事類有專屬句子時優先）。
  String factor(Reading r, Factor f) {
    final cell = r.mainCell;
    final tpl = (_get(_j, ['topics', r.topic, 'factors', f.name]) ??
        _get(_j, ['factors', f.name]) ??
        _get(_en, ['topics', r.topic, 'factors', f.name]) ??
        _get(_en, ['factors', f.name])) as String?;
    return _fill(tpl ?? f.name, r.main, door: cell?.door, god: cell?.god);
  }

  /// 輔助用神一行，例如「六合（媒合、藏處）落坎宮」。
  String secondary(YongShenHit h) =>
      _fill(_s([h.palace == null ? 'notFound' : 'secondary']), h);

  /// 宜忌提示（[ReadingMore.tipKeys]）；沒有該句時為 null。
  String? tip(String key, {required bool good}) => _lookup(['tips', key, good ? 'do' : 'dont']) as String?;

  /// 有方位的事類（失物、尋人、尋寵物）：方位、地點、八神提示。事類沒有專屬句子時用失物的。
  dynamic _dirText(String topic, List<String> rest) => _lookup(['topics', topic, ...rest]) ?? _lookup(['topics', 'lost', ...rest]);
  String lostWhere(Reading r, String dir) => _fill((_dirText(r.topic, ['where']) as String?) ?? 'where', r.main, dir: dir);
  String? lostPlace(int palace, [String topic = 'lost']) => _dirText(topic, ['place', '$palace']) as String?;
  String? lostGod(God g, [String topic = 'lost']) => _dirText(topic, ['god', g.zh]) as String?;
  String lostNear([String topic = 'lost']) => (_dirText(topic, ['near']) as String?) ?? 'near';
  String lostFar([String topic = 'lost']) => (_dirText(topic, ['far']) as String?) ?? 'far';

  String _fill(String tpl, YongShenHit h, {String? dir, Door? door, God? god}) => tpl
      .replaceAll('{ys}', yongShen(h.spec))
      .replaceAll('{palace}', h.palace == null ? '' : QimenTerms.palace(h.palace!, lang))
      .replaceAll('{dir}', dir ?? '')
      .replaceAll('{door}', door == null ? '' : QimenTerms.door(door, lang))
      .replaceAll('{god}', god == null ? '' : QimenTerms.god(god, lang));
}
