import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';
import 'package:qimen_compass/l10n/l10n.dart';

void main() {
  test('11 語清單；目前開放 zh-Hant、en', () {
    expect(AppLanguages.all.length, 11);
    expect(AppLanguages.enabled.map((l) => l.code), ['zh-Hant', 'en']);
  });

  test('語言解析', () {
    expect(AppLanguages.resolve(const [Locale('zh', 'TW')]).code, 'zh-Hant');
    expect(AppLanguages.resolve(const [Locale('zh', 'CN')]).code, 'zh-Hant'); // 簡中未開放 → 繁中
    expect(AppLanguages.resolve(const [Locale('ja')]).code, 'en');
  });

  test('術語：非中文介面保留中文＋拼音＋意譯', () {
    expect(QimenTerms.door(Door.sheng, AppLanguages.en), '生門 Sheng Men（Gate of Life）');
    expect(QimenTerms.door(Door.sheng, AppLanguages.zhHant), '生門');
  });
}
