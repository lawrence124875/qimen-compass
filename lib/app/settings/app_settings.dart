import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../engine/engine.dart' hide Element;
import 'cities.dart';

/// App 設定：外觀、排盤（定元方法、子時換日、真太陽時城市）、首次引導。
/// 啟動時 [load]，畫面用 ListenableBuilder 監聽；排盤一律經 [timeSettingsAt]／[juMethod]。
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final instance = AppSettings._();

  static const _kThemeMode = 'qm_theme_mode';
  static const _kJuMethod = 'qm_ju_method';
  static const _kZiHour = 'qm_zi_hour';
  static const _kSolarCity = 'qm_solar_city'; // -1＝不用真太陽時
  static const _kGuidePrefix = 'qm_guide_seen_';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  JuMethod _juMethod = JuMethod.chaiBu;
  ZiHourMode _ziHour = ZiHourMode.nextDay;
  int _solarCity = -1;

  ThemeMode get themeMode => _themeMode;
  JuMethod get juMethod => _juMethod;
  ZiHourMode get ziHour => _ziHour;

  /// 真太陽時所用城市；null＝不用真太陽時。
  City? get solarCity => _solarCity >= 0 && _solarCity < kCities.length ? kCities[_solarCity] : null;
  int get solarCityIndex => _solarCity;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      T pick<T>(List<T> values, String key, T fallback) {
        final i = p.getInt(key);
        return i != null && i >= 0 && i < values.length ? values[i] : fallback;
      }

      _themeMode = pick(ThemeMode.values, _kThemeMode, ThemeMode.system);
      _juMethod = pick(JuMethod.values, _kJuMethod, JuMethod.chaiBu);
      _ziHour = pick(ZiHourMode.values, _kZiHour, ZiHourMode.nextDay);
      _solarCity = p.getInt(_kSolarCity) ?? -1;
    } catch (_) {
      // 讀不到設定時用預設值。
    }
  }

  /// [instant] 當下的排盤時間設定（時區取裝置在該時刻的時差）。
  TimeSettings timeSettingsAt(DateTime instant) {
    final city = solarCity;
    return TimeSettings(
      utcOffset: instant.toLocal().timeZoneOffset,
      trueSolarTime: city != null,
      longitude: city?.longitude,
      ziHour: _ziHour,
    );
  }

  /// 首次引導是否已看過（[id] 例如 home）。
  bool guideSeen(String id) => _prefs?.getBool('$_kGuidePrefix$id') ?? false;
  void markGuideSeen(String id) => _prefs?.setBool('$_kGuidePrefix$id', true);

  void _save(String key, int v) {
    notifyListeners();
    _prefs?.setInt(key, v);
  }

  set themeMode(ThemeMode m) {
    if (m == _themeMode) return;
    _themeMode = m;
    _save(_kThemeMode, m.index);
  }

  set juMethod(JuMethod m) {
    if (m == _juMethod) return;
    _juMethod = m;
    _save(_kJuMethod, m.index);
  }

  set ziHour(ZiHourMode m) {
    if (m == _ziHour) return;
    _ziHour = m;
    _save(_kZiHour, m.index);
  }

  set solarCityIndex(int i) {
    if (i == _solarCity) return;
    _solarCity = i;
    _save(_kSolarCity, i);
  }
}
