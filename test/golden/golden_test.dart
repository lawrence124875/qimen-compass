// 時家轉盤 golden tests：比對 test/golden/cases/*.json 的參考盤（由 Lawrence 從信任的排盤軟體提供）。
// 格式見 test/golden/README.md。expected 只比對有寫的欄位。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/engine/engine.dart';

void main() {
  final dir = Directory('test/golden/cases');
  final files = dir.existsSync()
      ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  if (files.isEmpty) {
    test('golden：尚無測試盤', () {}, skip: '等待參考盤（test/golden/cases/*.json）');
    return;
  }

  const engine = ShiJiaEngine();
  for (final f in files) {
    final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final name = '${f.uri.pathSegments.last} ${data['name'] ?? ''}';
    test('golden：$name', () {
      final input = data['input'] as Map<String, dynamic>;
      final chart = engine.compute(
        _parseInstant(input['datetime'] as String, input['utcOffset'] as String? ?? '+08:00'),
        settings: TimeSettings(
          utcOffset: _parseOffset(input['utcOffset'] as String? ?? '+08:00'),
          trueSolarTime: input['trueSolarTime'] == true,
          longitude: (input['longitude'] as num?)?.toDouble(),
          ziHour: input['ziHour'] == 'lateZi' ? ZiHourMode.lateZi : ZiHourMode.nextDay,
        ),
        method: input['method'] == 'zhiRun' ? JuMethod.zhiRun : JuMethod.chaiBu,
      );
      _compare(chart, data['expected'] as Map<String, dynamic>);
    });
  }
}

Duration _parseOffset(String s) {
  final m = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(s)!;
  final d = Duration(hours: int.parse(m[2]!), minutes: int.parse(m[3]!));
  return m[1] == '-' ? -d : d;
}

DateTime _parseInstant(String local, String offset) =>
    DateTime.parse('${local}Z').subtract(_parseOffset(offset));

String _stems(List<int> s) => s.map((i) => stemNames[i]).join();

void _compare(QimenChart c, Map<String, dynamic> e) {
  void check(String key, Object actual) {
    if (e.containsKey(key)) expect(actual, e[key], reason: key);
  }

  check('dun', c.dun == Dun.yang ? 'yang' : 'yin');
  check('ju', c.ju);
  check('yuan', c.yuan.zh);
  check('term', solarTermNames[c.termIndex]);
  check('pillars', '${c.year} ${c.month} ${c.day} ${c.hour}');
  check('zhiFu', c.zhiFu.zh);
  check('zhiShi', c.zhiShi.zh);

  final palaces = (e['palaces'] as Map<String, dynamic>?) ?? const {};
  for (final entry in palaces.entries) {
    final p = c[int.parse(entry.key)];
    final x = entry.value as Map<String, dynamic>;
    void pc(String key, Object? actual) {
      if (x.containsKey(key)) expect(actual, x[key], reason: '${p.palace}宮 $key');
    }

    pc('earth', _stems(p.earthStems));
    pc('heaven', _stems(p.heavenStems));
    pc('star', p.stars.map((s) => s.zh).join('/'));
    pc('door', p.door?.zh);
    pc('god', p.god?.zh);
    pc('kongWang', p.kongWang);
    pc('horse', p.horse);
  }
}
