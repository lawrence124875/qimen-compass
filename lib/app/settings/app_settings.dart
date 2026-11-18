import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  static const _kSolarCity = 'qm_solar_city'; // -1＝不用真太陽時；-2＝目前位置（GPS）；≥0＝kCities 索引
  static const _kSolarLon = 'qm_solar_lon'; // GPS 取得的經度
  static const solarGps = -2;
  static const _kGuidePrefix = 'qm_guide_seen_';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  JuMethod _juMethod = JuMethod.chaiBu;
  ZiHourMode _ziHour = ZiHourMode.nextDay;
  int _solarCity = -1;
  double? _gpsLon;

  ThemeMode get themeMode => _themeMode;
  JuMethod get juMethod => _juMethod;
  ZiHourMode get ziHour => _ziHour;

  /// 真太陽時所用城市；null＝不用真太陽時或用目前位置。
  City? get solarCity => _solarCity >= 0 && _solarCity < kCities.length ? kCities[_solarCity] : null;
  int get solarCityIndex => _solarCity;

  /// 用目前位置（GPS）時的經度。
  double? get gpsLongitude => _gpsLon;

  /// 真太陽時所用經度；null＝不用真太陽時。
  double? get solarLongitude => _solarCity == solarGps ? _gpsLon : solarCity?.longitude;

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
      _gpsLon = p.getDouble(_kSolarLon);
    } catch (_) {
      // 讀不到設定時用預設值。
    }
  }

  /// [instant] 當下的排盤時間設定（時區取裝置在該時刻的時差）。
  TimeSettings timeSettingsAt(DateTime instant) {
    final lon = solarLongitude;
    return TimeSettings(
      utcOffset: instant.toLocal().timeZoneOffset,
      trueSolarTime: lon != null,
      longitude: lon,
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

  /// 改用目前位置：只要求概略位置權限。[ask]＝false 時不跳權限詢問（啟動時靜默更新經度）。
  /// 成功回傳 null；失敗回傳原因（serviceOff／denied／unavailable）。
  Future<String?> useGpsLocation({bool ask = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return 'serviceOff';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && ask) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return 'denied';
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
          );
      _gpsLon = pos.longitude;
      await _prefs?.setDouble(_kSolarLon, pos.longitude);
      if (_solarCity != solarGps) {
        solarCityIndex = solarGps;
      } else {
        notifyListeners();
      }
      return null;
    } catch (_) {
      return 'unavailable';
    }
  }

  /// 啟動時：若設定為目前位置，靜默更新經度（不跳權限詢問；取不到就沿用上次的經度）。
  Future<void> refreshGps() async {
    if (_solarCity == solarGps) await useGpsLocation(ask: false);
  }
}
