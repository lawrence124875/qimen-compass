import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

/// 內嵌的最小規則（不依賴私人內容檔）。
const _rules = {
  'schemaVersion': 1,
  'topics': ['wealth', 'lost', 'love'],
  'defaultSchool': 'standard',
  'schools': {
    'standard': {
      'topics': {
        'wealth': {
          'yongShen': [
            {'type': 'door', 'value': '生門'},
            {'type': 'stem', 'value': '戊'},
          ],
          'relation': true,
        },
        'lost': {
          'yongShen': [
            {'type': 'hourStem'},
            {'type': 'god', 'value': '六合'},
          ],
          'relation': true,
          'direction': true,
        },
        'love': {
          'yongShen': [
            {'type': 'door', 'value': '休門'},
          ],
        },
      },
    },
    'liuhe': {
      'topics': {
        'love': {
          'yongShen': [
            {'type': 'god', 'value': '六合'},
          ],
        },
      },
    },
  },
};

void main() {
  final rules = DivinationRules.fromJson(_rules);
  const engine = DivinationEngine();
  const tz = TimeSettings(utcOffset: Duration(hours: 8));

  test('旺相休囚死', () {
    // 寅月（木）：木旺、火相、水休、金囚、土死
    expect(seasonOf(Element.wood, 2), Season.wang);
    expect(seasonOf(Element.fire, 2), Season.xiang);
    expect(seasonOf(Element.water, 2), Season.xiu);
    expect(seasonOf(Element.metal, 2), Season.qiu);
    expect(seasonOf(Element.earth, 2), Season.si);
  });

  test('甲遁六儀', () {
    expect(hiddenYi(GanZhi.parse('甲子')), 4); // 戊
    expect(hiddenYi(GanZhi.parse('甲寅')), 9); // 癸
    expect(hiddenYi(GanZhi.parse('乙丑')), 4);
  });

  test('流派：沒寫的事類退回預設', () {
    expect(rules.rule('love', 'liuhe').yongShen.first.kind, YongShenKind.god);
    expect(rules.rule('wealth', 'liuhe').yongShen.first.value, '生門');
    expect(rules.schoolsFor('love'), ['standard', 'liuhe']);
    expect(rules.schoolsFor('wealth'), ['standard']);
  });

  test('用神落宮與盤面一致；一週每時辰都能判斷', () {
    var t = DateTime.utc(2026, 11, 17);
    for (var i = 0; i < 84; i++, t = t.add(const Duration(hours: 2))) {
      for (final topic in rules.topics) {
        final r = engine.read(rules, topic, t, settings: tz);
        final main = r.main;
        switch (main.spec.kind) {
          case YongShenKind.door:
            expect(r.chart[main.palace!].door!.zh, main.spec.value);
          case YongShenKind.god:
            expect(r.chart[main.palace!].god!.zh, main.spec.value);
          case YongShenKind.hourStem:
            if (main.palace != null) expect(r.chart[main.palace!].heavenStems, contains(main.stem));
          default:
            break;
        }
        expect(r.score, r.factors.fold<int>(0, (s, f) => s + factorWeight[f]!));
        expect(r.factors.first.index, lessThanOrEqualTo(Factor.si.index));
        if (topic == 'lost' && main.palace != null && main.palace != 5) expect(r.bearing, isNotNull);
      }
    }
  });

  test('同一時間結果固定', () {
    final t = DateTime.utc(2026, 5, 1, 3);
    final a = engine.read(rules, 'wealth', t, settings: tz);
    final b = engine.read(rules, 'wealth', t, settings: tz);
    expect(a.factors, b.factors);
    expect(a.seed, b.seed);
  });

  // CI 會把私人 repo 的內容複製到 assets/content/；本機沒有時略過。
  final dir = Directory('assets/content/divination');
  final hasContent = File('${dir.path}/rules.json').existsSync();
  test('內容檔：規則可解析、各語言文句齊全', () {
    final real = DivinationRules.fromJson(jsonDecode(File('${dir.path}/rules.json').readAsStringSync()) as Map<String, dynamic>);
    final texts = Directory('${dir.path}/text').listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    expect(texts.map((f) => f.uri.pathSegments.last), containsAll(['zh-Hant.json', 'en.json']));
    for (final f in texts) {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final name = f.uri.pathSegments.last;
      for (final topic in real.topics) {
        final tj = j['topics'][topic] as Map<String, dynamic>;
        for (final k in ['name', 'desc', 'ask']) {
          expect(tj[k], isA<String>(), reason: '$name $topic.$k');
        }
        for (final v in Verdict.values) {
          expect((tj['verdict'][v.name] as List), isNotEmpty, reason: '$name $topic.verdict.${v.name}');
          expect(tj['advice'][v.name], isA<String>(), reason: '$name $topic.advice.${v.name}');
        }
        for (final s in real.schoolsFor(topic)) {
          expect(j['schools'][s]?['name'], isA<String>(), reason: '$name school $s');
          for (final y in real.rule(topic, s).yongShen) {
            expect(j['yongShen'][y.key], isA<String>(), reason: '$name yongShen ${y.key}');
          }
        }
      }
      for (final fct in Factor.values) {
        expect(j['factors'][fct.name], isA<String>(), reason: '$name factors.${fct.name}');
      }
      for (final p in [1, 2, 3, 4, 6, 7, 8, 9]) {
        expect(j['topics']['lost']['place']['$p'], isA<String>(), reason: '$name lost.place.$p');
      }
      for (final g in God.values) {
        expect(j['topics']['lost']['god'][g.zh], isA<String>(), reason: '$name lost.god.${g.zh}');
      }
      expect(j['disclaimer'], isA<String>());
      expect(j['schemaVersion'], 1);
    }
    expect(real.rule('lawsuit').disclaimer, isTrue);
    expect(real.rule('health').disclaimer, isTrue);
  }, skip: hasContent ? false : '沒有 assets/content/divination（私人內容，只在 CI 檢查）');

  // run 11–25 的坑：pubspec 的資料夾 asset 不含子資料夾，text/ 沒打包進 APK。
  test('assets/content 底下有檔案的資料夾都列在 pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dirs = Directory('assets/content')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => '${f.parent.path.replaceAll(r'\\', '/')}/')
        .where((d) => d != 'assets/content/')
        .toSet();
    for (final d in dirs) {
      expect(pubspec, contains('- $d'), reason: '$d 沒列在 pubspec.yaml assets');
    }
  });
}
