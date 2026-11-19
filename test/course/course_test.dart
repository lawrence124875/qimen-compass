import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qimen_compass/app/theme/app_theme.dart';
import 'package:qimen_compass/features/course/course.dart';
import 'package:qimen_compass/features/course/course_page.dart';
import 'package:qimen_compass/l10n/l10n.dart';

const _fixture = '''
{"schemaVersion":1,"lang":"zh-Hant","title":"奇門入門","intro":"簡介",
 "lessons":[
  {"id":"a","free":true,"minutes":3,"title":"第一課標題","summary":"摘要",
   "sections":[{"heading":"小標","paragraphs":["段落一","段落二"]}],
   "takeaways":["重點一"],"action":{"type":"travel","label":"開始出行訣"}},
  {"id":"b","free":false,"minutes":4,"title":"第二課標題","summary":"摘要",
   "sections":[],"takeaways":[],"action":{"type":"teleport","label":"未來功能"}}
 ]}
''';

/// CI 建置時從 qimen-content 匯入；本機沒有時略過內容檢查。
final _dir = Directory('assets/content/course');

Map<String, dynamic> _read(File f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

/// 各語必須一致的結構（只翻文字）。
List<Object?> _shape(Map<String, dynamic> j) => [
      j['schemaVersion'],
      for (final l in (j['lessons'] as List).cast<Map<String, dynamic>>())
        [l['id'], l['free'], l['minutes'], (l['action'] as Map?)?['type'], (l['sections'] as List).length, (l['takeaways'] as List).length],
    ];

void main() {
  test('解析課程；不認得的功能類型不顯示按鈕', () {
    final c = Course.parse(_fixture);
    expect(c.lessons.map((l) => l.id), ['a', 'b']);
    expect(c.lessons.first.action?.type, CourseActionType.travel);
    expect(c.lessons.first.sections.single.paragraphs, hasLength(2));
    expect(c.lessons.last.action, isNull);
  });

  test('schemaVersion 比 App 新時拒絕讀取', () {
    expect(() => Course.parse('{"schemaVersion":99,"lessons":[]}'), throwsFormatException);
  });

  test('付費牆接上前全部開放', () {
    final c = Course.parse(_fixture);
    expect(CourseAccess.unlocked(c.lessons.last), !CourseAccess.paywallEnabled || CourseAccess.premium.value);
    expect(CourseAccess.unlocked(c.lessons.first), isTrue);
  });

  final files = _dir.existsSync() ? _dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList() : <File>[];

  test('內容：各語結構與 zh-Hant 一致、前 2 課免費、文案避開禁用字', () {
    if (files.isEmpty) {
      markTestSkipped('本機沒有 assets/content/course（CI 匯入 qimen-content 後才檢查）');
      return;
    }
    final base = _read(File('${_dir.path}/zh-Hant.json'));
    final baseShape = _shape(base);
    final lessons = (base['lessons'] as List).cast<Map<String, dynamic>>();
    expect([for (final l in lessons) l['free']].take(3), [true, true, false]);
    final folders = {for (final l in AppLanguages.all) l.contentFolder};
    for (final f in files) {
      final name = f.uri.pathSegments.last.replaceAll('.json', '');
      expect(folders, contains(name), reason: '${f.path}：檔名要用 app_languages.dart 的 contentFolder');
      final j = _read(f);
      expect(j['lang'], name, reason: f.path);
      expect(_shape(j), baseShape, reason: '${f.path} 結構與 zh-Hant 不同');
      final c = Course.parse(f.readAsStringSync());
      for (final l in c.lessons) {
        expect(l.title.trim(), isNotEmpty, reason: '${f.path} ${l.id}');
        expect(l.action, isNotNull, reason: '${f.path} ${l.id}：action.type App 不支援');
      }
    }
    for (final lang in ['zh-Hant', 'zh-Hans']) {
      final f = File('${_dir.path}/$lang.json');
      if (!f.existsSync()) continue;
      final text = f.readAsStringSync();
      for (final w in ['占卜', '保證', '保证', '療效', '疗效']) {
        expect(text.contains(w), isFalse, reason: '$lang 含禁用字「$w」');
      }
    }
  });

  for (final b in Brightness.values) {
    testWidgets('單課頁：段落、重點、課末按鈕（$b）', (tester) async {
      final c = Course.parse(_fixture);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.of(b),
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: LessonPage(course: c, index: 0),
      ));
      expect(find.text('第一課標題'), findsOneWidget);
      expect(find.text('段落二'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('開始出行訣'), 200);
      expect(find.text('重點一'), findsOneWidget);
      expect(find.text('開始出行訣'), findsOneWidget);
      expect(find.text('下一課'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
