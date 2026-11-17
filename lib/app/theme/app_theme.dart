import 'package:flutter/material.dart';

import 'qm_palette.dart';

export 'qm_palette.dart';

/// 字型（CI 由 scripts/build_fonts.py 產生子集，不進 repo）。
/// 一律帶 fallback：子集外的字（日後新增語言）交給系統字型。
const kSans = 'QmSans';
const kSerif = 'QmSerif';
const kFontFallback = <String>['Noto Sans TC', 'PingFang TC', 'Noto Sans CJK TC', 'sans-serif'];

/// 盤面用的宋體樣式（宮內文字）。
TextStyle serif(TextStyle? base) => (base ?? const TextStyle()).copyWith(fontFamily: kSerif, fontFamilyFallback: kFontFallback);

class AppTheme {
  AppTheme._();

  static ThemeData of(Brightness b) {
    final p = b == Brightness.dark ? QmPalette.dark : QmPalette.light;
    final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: b).copyWith(
      primary: p.primary,
      onPrimary: b == Brightness.dark ? p.background : QmPalette.onImage,
      secondary: p.accent,
      surface: p.background,
      onSurface: p.text,
      surfaceContainerHighest: p.card,
      outline: p.border,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      fontFamily: kSans,
      fontFamilyFallback: kFontFallback,
      extensions: [p],
    );
    // 全 App 同一按鈕樣式（§14）。
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return base.copyWith(
      appBarTheme: AppBarTheme(backgroundColor: p.background, foregroundColor: p.text, elevation: 0, centerTitle: true),
      cardTheme: CardThemeData(color: p.card, elevation: 0, shape: shape.copyWith(side: BorderSide(color: p.border.withValues(alpha: 0.5)))),
      dividerTheme: DividerThemeData(color: p.border.withValues(alpha: 0.4)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape, minimumSize: const Size(48, 44))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: shape, minimumSize: const Size(48, 44), side: BorderSide(color: p.border))),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.card, showDragHandle: true),
    );
  }
}
