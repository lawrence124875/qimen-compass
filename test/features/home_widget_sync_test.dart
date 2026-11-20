import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/app/settings/app_settings.dart';
import 'package:qimen_compass/features/widget/home_widget_sync.dart';
import 'package:qimen_compass/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, String>> build({required bool premium, bool birth = true}) async {
    SharedPreferences.setMockInitialValues({if (birth) 'qm_birth_date': '1988-02-04'});
    await AppSettings.instance.load();
    return QimenHomeWidget.build(lookupAppLocalizations(const Locale('zh')), premium: premium, now: DateTime(2026, 11, 20, 10));
  }

  test('小工具資料：每個項目此刻都有一筆、九宮盤 84 個時辰', () async {
    final d = await build(premium: true);
    final items = jsonDecode(d['qm_w_items']!) as Map<String, dynamic>;
    final now = DateTime(2026, 11, 20, 10).millisecondsSinceEpoch;
    final later = DateTime(2026, 11, 26, 22).millisecondsSinceEpoch;
    for (final i in WidgetItem.values) {
      final list = (items[i.name] as List).cast<Map<String, dynamic>>();
      for (final t in [now, later]) {
        final hit = list.where((e) => t >= (e['s'] as int) && t < (e['e'] as int));
        expect(hit, isNotEmpty, reason: '${i.name} @ $t');
        expect((hit.first['m'] as String), isNotEmpty);
      }
    }
    final board = jsonDecode(d['qm_w_board']!) as List;
    expect(board, hasLength(84));
    expect(((board.first as Map)['c'] as List), hasLength(9));
    final names = jsonDecode(d['qm_w_names']!) as Map<String, dynamic>;
    expect(names['_hint1'], contains('3'));
  });

  test('免費版：訂閱項目上鎖、沒有九宮盤', () async {
    final d = await build(premium: false);
    final items = jsonDecode(d['qm_w_items']!) as Map<String, dynamic>;
    final p = (items['pdir'] as List).single as Map;
    expect(p['u'], QimenHomeWidget.uriPaywall);
    expect(jsonDecode(d['qm_w_board']!), isEmpty);
  });

  test('沒填生日：個人項目提示設定生日', () async {
    final d = await build(premium: true, birth: false);
    final items = jsonDecode(d['qm_w_items']!) as Map<String, dynamic>;
    expect(((items['pcolor'] as List).single as Map)['u'], QimenHomeWidget.uriMe);
  });
}
