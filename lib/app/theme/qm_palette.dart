import 'package:flutter/material.dart';

import '../../engine/engine.dart' hide Element;
import '../../engine/ganzhi.dart' as gz show Element;

/// 奇門配色（沿用謙卦「天玄地黃」）。依深淺色各一份，透過 `context.qm` 取用；
/// 不放 const 全域色，避免深淺色切換時漏改（HANDOFF §14）。
@immutable
class QmPalette extends ThemeExtension<QmPalette> {
  const QmPalette({
    required this.background,
    required this.card,
    required this.primary,
    required this.accent,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.good,
    required this.neutral,
    required this.bad,
    required this.wood,
    required this.fire,
    required this.earth,
    required this.metal,
    required this.water,
  });

  /// 玄墨底、玄灰卡片、地黃主色、稻金點綴、山褐框線、淡金文字。
  static const dark = QmPalette(
    background: Color(0xFF1C1B22),
    card: Color(0xFF26242E),
    primary: Color(0xFFC9A45C),
    accent: Color(0xFFD8B56A),
    border: Color(0xFF7E6A52),
    text: Color(0xFFE8D9B0),
    textMuted: Color(0xFFA89C82),
    good: Color(0xFF86BC7F),
    neutral: Color(0xFFC9A45C),
    bad: Color(0xFFE07A5F),
    wood: Color(0xFF86BC7F),
    fire: Color(0xFFE07A5F),
    earth: Color(0xFFC9A45C),
    metal: Color(0xFFDAD4C4),
    water: Color(0xFF7FA8DA),
  );

  /// 宣紙底、地黃主色。
  static const light = QmPalette(
    background: Color(0xFFF3ECDD),
    card: Color(0xFFFBF7EE),
    primary: Color(0xFF946C2A),
    accent: Color(0xFFB8893A),
    border: Color(0xFFC9B48E),
    text: Color(0xFF2B2620),
    textMuted: Color(0xFF6E6454),
    good: Color(0xFF3F7D3A),
    neutral: Color(0xFF946C2A),
    bad: Color(0xFFB5452E),
    wood: Color(0xFF3F7D3A),
    fire: Color(0xFFB5452E),
    earth: Color(0xFF946C2A),
    metal: Color(0xFF6E6A60),
    water: Color(0xFF2F6BA8),
  );

  /// 圖片上的文字一律用固定色，不隨深淺色變。
  static const onImage = Color(0xFFFFFFFF);

  final Color background, card, primary, accent, border, text, textMuted;

  /// 八門吉／平／凶（§4：吉 開休生；平 杜景；凶 死驚傷）。
  final Color good, neutral, bad;

  /// 五行色。
  final Color wood, fire, earth, metal, water;

  Color luck(Luck l) => switch (l) { Luck.good => good, Luck.neutral => neutral, Luck.bad => bad };

  Color element(gz.Element e) => switch (e) {
        gz.Element.wood => wood,
        gz.Element.fire => fire,
        gz.Element.earth => earth,
        gz.Element.metal => metal,
        gz.Element.water => water,
      };

  @override
  QmPalette copyWith() => this;

  @override
  QmPalette lerp(QmPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return QmPalette(
      background: c(background, other.background),
      card: c(card, other.card),
      primary: c(primary, other.primary),
      accent: c(accent, other.accent),
      border: c(border, other.border),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      good: c(good, other.good),
      neutral: c(neutral, other.neutral),
      bad: c(bad, other.bad),
      wood: c(wood, other.wood),
      fire: c(fire, other.fire),
      earth: c(earth, other.earth),
      metal: c(metal, other.metal),
      water: c(water, other.water),
    );
  }
}

extension QmPaletteContext on BuildContext {
  QmPalette get qm => Theme.of(this).extension<QmPalette>() ?? QmPalette.dark;
}
