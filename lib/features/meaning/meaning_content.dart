import 'dart:convert';

import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';

/// 盤面點擊解說：八門、九星、八神、天干的一句話意義。
/// 內容在 qimen-content `app/meaning/<語言>.json`（鍵如 `door:開門`、`star:天蓬`、`god:值符`、`stem:戊`），
/// CI 複製到 `assets/content/meaning/`。缺語言退回 en；讀不到時 [lookup] 回傳 null（畫面就不顯示解說）。
class MeaningContent {
  MeaningContent._(this._m);

  final Map<String, dynamic> _m;

  static const _dir = 'assets/content/meaning';
  static MeaningContent? _cache;
  static String? _cacheLang;

  /// 已載入過就同步取得（第一次開盤面時預先 [load]）。
  static MeaningContent? get cached => _cacheLang == L10n.language.code ? _cache : null;

  static Future<MeaningContent?> load(AppLanguage lang, {AssetBundle? bundle}) async {
    if (_cache != null && _cacheLang == lang.code) return _cache;
    final b = bundle ?? rootBundle;
    for (final code in [lang.contentFolder, lang.code, 'en']) {
      try {
        final j = jsonDecode(await b.loadString('$_dir/$code.json')) as Map<String, dynamic>;
        _cacheLang = lang.code;
        return _cache = MeaningContent._(j['meaning'] as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  /// [kind]：door、star、god、stem；[zh]：繁中術語（`Door.zh` 等）。
  String? lookup(String kind, String zh) => _m['$kind:$zh'] as String?;
}
