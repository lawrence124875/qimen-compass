import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';
import 'package:qimen_compass/l10n/l10n.dart';

void main() {
  test('11 語清單；全部開放', () {
    expect(AppLanguages.all.length, 11);
    expect(AppLanguages.enabled.length, 11);
  });

  test('語言解析', () {
    expect(AppLanguages.resolve(const [Locale('zh', 'TW')]).code, 'zh-Hant');
    expect(AppLanguages.resolve(const [Locale('zh', 'CN')]).code, 'zh-Hans');
    expect(AppLanguages.resolve(const [Locale('zh', 'CN')], available: const [AppLanguages.zhHant, AppLanguages.en]).code, 'zh-Hant'); // 簡中未開放 → 繁中
    expect(AppLanguages.resolve(const [Locale('ja')]).code, 'ja');
    expect(AppLanguages.resolve(const [Locale('pt', 'PT')]).code, 'pt-BR');
    expect(AppLanguages.resolve(const [Locale('fr')]).code, 'en');
  });

  test('術語：非中文介面保留中文＋拼音＋意譯', () {
    expect(QimenTerms.door(Door.sheng, AppLanguages.en), '生門 Shēng Mén (Gate of Life)');
    expect(QimenTerms.door(Door.sheng, AppLanguages.zhHant), '生門');
    expect(QimenTerms.door(Door.sheng, AppLanguages.zhHans), '生门');
    expect(QimenTerms.door(Door.sheng, AppLanguages.ja), '生門 Shēng Mén（せいもん）');
    expect(QimenTerms.palace(6, AppLanguages.zhHans), '乾宫'); // 乾不可轉成干
    expect(QimenTerms.star(Star.chong, AppLanguages.zhHans), '天冲');
    expect(QimenTerms.solarTerm(0, AppLanguages.zhHant), solarTermNames[0]);
    expect(QimenTerms.markShort(ChartMark.menPo), '迫');
    expect(QimenTerms.markShort(ChartMark.horse, AppLanguages.zhHans), '马');
    for (final lang in AppLanguages.all) {
      for (final d in Door.values) {
        expect(QimenTerms.door(d, lang), isNotEmpty);
      }
      for (var i = 0; i < 24; i++) {
        expect(QimenTerms.solarTerm(i, lang), startsWith(lang.code == 'zh-Hans' ? '' : solarTermNames[i]));
      }
    }
  });

  // 謙卦的坑：ARB 少一個鍵或參數不同，某個語言就會顯示錯誤。
  // 已開放（ready）的語言鍵必須與範本完全相同；未開放的語言可以暫缺（翻譯中，gen-l10n 以範本補上），但不可多鍵、參數必須一致。
  test('ARB 的鍵與參數與範本一致', () {
    Map<String, dynamic> read(String f) => jsonDecode(File(f).readAsStringSync()) as Map<String, dynamic>;
    Set<String> params(String v) => RegExp(r'(?<![A-Za-z0-9_=])\{(\w+)\s*[,}]').allMatches(v).map((m) => m[1]!).toSet();
    const arbOf = {
      'zh-Hant': 'app_zh.arb', 'zh-Hans': 'app_zh_Hans.arb', 'en': 'app_en.arb', 'ja': 'app_ja.arb', 'ko': 'app_ko.arb', //
      'vi': 'app_vi.arb', 'id': 'app_id.arb', 'es': 'app_es.arb', 'pt-BR': 'app_pt.arb', 'th': 'app_th.arb', 'ar': 'app_ar.arb',
    };
    expect(arbOf.keys.toSet(), AppLanguages.all.map((l) => l.code).toSet());
    final tpl = read('lib/l10n/app_zh.arb');
    final keys = tpl.keys.where((k) => !k.startsWith('@')).toSet();
    for (final lang in AppLanguages.all) {
      final f = 'lib/l10n/${arbOf[lang.code]}';
      if (!File(f).existsSync()) {
        expect(lang.ready, isFalse, reason: '$f 不存在但已開放');
        continue;
      }
      final arb = read(f);
      final own = arb.keys.where((k) => !k.startsWith('@')).toSet();
      expect(own.difference(keys), isEmpty, reason: '$f 多出的鍵');
      if (lang.ready) expect(keys.difference(own), isEmpty, reason: '$f 缺少的鍵');
      for (final k in own) {
        expect(params(arb[k] as String), params(tpl[k] as String), reason: '$f $k');
      }
    }
  });
}
