import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_languages.dart';

/// 課程資料（HANDOFF §14 課程）：內容在私人 repo qimen-content `app/course/<語言>.json`，
/// CI 建置時複製到 assets/content/course/。結構以 zh-Hant 為準，各語只翻文字。

/// 課末按鈕開啟的功能。新增類型：先在這裡與 [CourseActionType.parse] 加上，再寫進內容 JSON。
enum CourseActionType {
  chart, // 首頁時盤
  travel; // 出行訣

  static CourseActionType? parse(String? s) {
    for (final t in values) {
      if (t.name == s) return t;
    }
    return null;
  }
}

class CourseAction {
  const CourseAction(this.type, this.label);
  final CourseActionType type;
  final String label;
}

class CourseSection {
  const CourseSection(this.heading, this.paragraphs);
  final String heading;
  final List<String> paragraphs;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.free,
    required this.minutes,
    required this.title,
    required this.summary,
    required this.sections,
    required this.takeaways,
    this.action,
  });

  final String id;
  final bool free;
  final int minutes;
  final String title, summary;
  final List<CourseSection> sections;
  final List<String> takeaways;

  /// 不認得的類型（舊版 App 讀到新內容）為 null，不顯示按鈕。
  final CourseAction? action;
}

class Course {
  const Course({required this.title, required this.intro, required this.lessons});

  static const supportedSchema = 1;
  static const empty = Course(title: '', intro: '', lessons: []);

  final String title, intro;
  final List<Lesson> lessons;

  bool get isEmpty => lessons.isEmpty;

  static Course parse(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final v = j['schemaVersion'] as int? ?? 0;
    if (v > supportedSchema) throw FormatException('schemaVersion $v 不支援');
    List<String> strs(Object? o) => [for (final s in (o as List? ?? const [])) s as String];
    return Course(
      title: j['title'] as String? ?? '',
      intro: j['intro'] as String? ?? '',
      lessons: [
        for (final l in (j['lessons'] as List).cast<Map<String, dynamic>>())
          Lesson(
            id: l['id'] as String,
            free: l['free'] as bool? ?? false,
            minutes: l['minutes'] as int? ?? 3,
            title: l['title'] as String,
            summary: l['summary'] as String? ?? '',
            sections: [
              for (final s in (l['sections'] as List? ?? const []).cast<Map<String, dynamic>>())
                CourseSection(s['heading'] as String? ?? '', strs(s['paragraphs'])),
            ],
            takeaways: strs(l['takeaways']),
            action: switch (l['action']) {
              {'type': final String t, 'label': final String label} when CourseActionType.parse(t) != null =>
                CourseAction(CourseActionType.parse(t)!, label),
              _ => null,
            },
          ),
      ],
    );
  }
}

/// 讀取課程：依語言找檔，找不到退回英文、再退回繁中；都沒有（本機未匯入內容）回傳 [Course.empty]。
class CourseRepository {
  CourseRepository._();

  static final _cache = <String, Course>{};

  static String assetPath(String folder) => 'assets/content/course/$folder.json';

  static Future<Course> load(AppLanguage lang) async {
    final hit = _cache[lang.code];
    if (hit != null) return hit;
    for (final folder in {lang.contentFolder, AppLanguages.en.contentFolder, AppLanguages.zhHant.contentFolder}) {
      try {
        final c = Course.parse(await rootBundle.loadString(assetPath(folder)));
        if (!c.isEmpty) return _cache[lang.code] = c;
      } catch (e) {
        debugPrint('課程 $folder 讀取失敗：$e');
      }
    }
    return Course.empty;
  }
}

/// 解鎖規則：前 2 課（`free`）免費；其餘需訂閱。
/// 付費牆（RevenueCat）接上前 [paywallEnabled] 為 false，全部開放；接上後把它改成 true 並更新 [premium]。
class CourseAccess {
  CourseAccess._();

  static const paywallEnabled = false;

  /// 訂閱狀態，由付費功能模組更新。
  static final premium = ValueNotifier<bool>(false);

  static bool unlocked(Lesson l) => !paywallEnabled || l.free || premium.value;
}

/// 已讀進度（本機）。
class CourseProgress extends ChangeNotifier {
  CourseProgress._();

  static final instance = CourseProgress._();
  static const _key = 'qm_course_done';

  SharedPreferences? _prefs;
  Set<String> _done = {};

  bool isDone(String id) => _done.contains(id);
  int get doneCount => _done.length;

  Future<void> load() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _done = (_prefs!.getStringList(_key) ?? const []).toSet();
      notifyListeners();
    } catch (_) {
      // 讀不到時視為全部未讀。
    }
  }

  void markDone(String id) {
    if (!_done.add(id)) return;
    notifyListeners();
    _prefs?.setStringList(_key, _done.toList());
  }
}
