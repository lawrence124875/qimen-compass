import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';
import 'package:qimen_compass/features/lucky/glossary_page.dart' show shenShaKeys;
import 'package:qimen_compass/l10n/l10n.dart';

/// 盤面點擊解說（qimen-content app/meaning）：每個語言都要有全部八門、九星、八神、天干。
void main() {
  final dir = Directory('assets/content/meaning');
  final has = dir.existsSync() && File('${dir.path}/zh-Hant.json').existsSync();
  test('各語解說鍵齊全', () {
    final keys = [
      for (final d in Door.values) 'door:${d.zh}',
      for (final s in Star.values) 'star:${s.zh}',
      for (final g in God.values) 'god:${g.zh}',
      for (final s in '戊己庚辛壬癸丁丙乙'.split('')) 'stem:$s',
      for (final e in Element.values) 'color:${e.zh}',
      for (final e in Element.values) 'cure:${e.zh}',
      for (final c in ChangSheng.values) 'cs:${c.zh}',
      for (final k in shenShaKeys) 'ss:$k',
      for (final d in Door.values) 'place:${d.zh}',
      'curetone:平', 'curetone:凶',
      for (final s in cureStars) 'curestar:${s.zh}',
      // 本命報告性格（日干宮的星門神）
      for (final s in Star.values) 'np:${s.zh}',
      for (final d in Door.values) 'np:${d.zh}',
      for (final g in God.values) 'np:${g.zh}',
    ];
    for (final lang in AppLanguages.all) {
      final f = File('${dir.path}/${lang.contentFolder}.json');
      expect(f.existsSync(), isTrue, reason: '缺 ${f.path}');
      final m = (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['meaning'] as Map<String, dynamic>;
      for (final k in keys) {
        expect((m[k] as String?)?.isNotEmpty, isTrue, reason: '${lang.code} 缺 $k');
      }
    }
  }, skip: has ? false : '沒有 assets/content/meaning（私人內容，只在 CI 檢查）');
}
