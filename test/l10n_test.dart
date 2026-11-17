import 'dart:convert';
import 'dart:io';
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

  // 謙卦的坑：ARB 少一個鍵或參數不同，某個語言就會顯示錯誤。所有 ARB 的鍵與參數必須和範本一致。
  test('所有 ARB 的鍵與參數與範本一致', () {
    Map<String, dynamic> read(String f) => jsonDecode(File(f).readAsStringSync()) as Map<String, dynamic>;
    Set<String> params(String v) => RegExp(r'\{(\w+)').allMatches(v).map((m) => m[1]!).toSet();
    final tpl = read('lib/l10n/app_zh.arb');
    final keys = tpl.keys.where((k) => !k.startsWith('@')).toSet();
    final files = Directory('lib/l10n').listSync().map((e) => e.path).where((p) => p.endsWith('.arb'));
    for (final f in files) {
      final arb = read(f);
      expect(arb.keys.where((k) => !k.startsWith('@')).toSet(), keys, reason: f);
      for (final k in keys) {
        expect(params(arb[k] as String), params(tpl[k] as String), reason: '$f $k');
      }
    }
  });
}
