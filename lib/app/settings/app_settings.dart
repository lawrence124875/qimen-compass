import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App 設定（目前：外觀）。啟動時 [load]，畫面用 ListenableBuilder 監聽。
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final instance = AppSettings._();

  static const _kThemeMode = 'qm_theme_mode';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final i = _prefs!.getInt(_kThemeMode);
      if (i != null && i >= 0 && i < ThemeMode.values.length) _themeMode = ThemeMode.values[i];
    } catch (_) {
      // 讀不到設定時用預設值（跟隨系統）。
    }
  }

  set themeMode(ThemeMode m) {
    if (m == _themeMode) return;
    _themeMode = m;
    notifyListeners();
    _prefs?.setInt(_kThemeMode, m.index);
  }
}
