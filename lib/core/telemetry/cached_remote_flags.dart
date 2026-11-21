import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';
import 'remote_flags.dart';

/// 啟動加速：遠端開關改讀本機快取（上次 Remote Config 套用的值），首頁不必等 Firebase 初始化。
/// Firebase 在背景初始化、抓新值後寫回快取，下次啟動生效（與原本「下次啟動生效」的規則一致）。
class CachedRemoteFlags implements RemoteFlags {
  CachedRemoteFlags._(this._values);

  static const _kCache = 'qm_rc_cache';
  final Map<String, String> _values;

  static Future<CachedRemoteFlags> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kCache);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        return CachedRemoteFlags._({for (final e in m.entries) e.key: '${e.value}'});
      }
    } catch (_) {}
    return CachedRemoteFlags._(const {});
  }

  /// [values]：Remote Config 從伺服器來的值（不含 App 內預設）。
  static Future<void> save(Map<String, String> values) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_kCache, jsonEncode(values));
    } catch (_) {}
  }

  @override
  bool featureEnabled(String featureId) {
    final v = _values[featureFlagKey(featureId)]?.trim().toLowerCase();
    return !(v == 'false' || v == '0' || v == 'no' || v == 'off');
  }

  @override
  int intValue(String key, int fallback) => int.tryParse(_values[key]?.trim() ?? '') ?? fallback;
}

/// Firebase 還沒初始化好之前先收著事件，好了再送出（最多收 50 則）。
class LateAnalytics implements Analytics {
  Analytics? _inner;
  final _pending = <(String, Map<String, Object>)>[];

  set inner(Analytics a) {
    _inner = a;
    for (final (name, params) in _pending) {
      a.log(name, params);
    }
    _pending.clear();
  }

  @override
  Future<void> log(String name, [Map<String, Object> params = const {}]) async {
    final a = _inner;
    if (a != null) return a.log(name, params);
    if (_pending.length < 50) _pending.add((name, params));
  }
}
