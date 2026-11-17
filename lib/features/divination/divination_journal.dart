import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 問事紀錄（比照謙卦卦記）：起局時間、事類、流派、問題，加上事後應驗回饋。
/// 盤面與解讀不存，打開時依起局時間重算（引擎固定，結果一致）。
class JournalEntry {
  JournalEntry({
    required this.id,
    required this.askedAt,
    required this.topic,
    required this.school,
    required this.question,
    required this.verdict,
    this.feedback,
  });

  final int id;
  final DateTime askedAt;
  final String topic, school, question;

  /// 當時的五級（Verdict.name），列表顯示用。
  final String verdict;

  /// 事後回饋：true 應驗、false 不準、null 未回饋。
  bool? feedback;

  Map<String, dynamic> toJson() => {
        'id': id,
        'askedAt': askedAt.toUtc().toIso8601String(),
        'topic': topic,
        'school': school,
        'question': question,
        'verdict': verdict,
        if (feedback != null) 'feedback': feedback,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as int,
        askedAt: DateTime.parse(j['askedAt'] as String),
        topic: j['topic'] as String,
        school: j['school'] as String,
        question: j['question'] as String? ?? '',
        verdict: j['verdict'] as String,
        feedback: j['feedback'] as bool?,
      );
}

class DivinationJournal {
  DivinationJournal._(this._prefs, this.entries);

  static const _key = 'qm_div_journal';
  static const _schemaVersion = 1;

  /// 最多保留筆數（超過刪最舊的）。
  static const maxEntries = 200;

  final SharedPreferences _prefs;

  /// 新的在前。
  final List<JournalEntry> entries;

  static Future<DivinationJournal> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <JournalEntry>[];
    try {
      final j = jsonDecode(prefs.getString(_key) ?? '{}') as Map<String, dynamic>;
      for (final e in (j['entries'] as List?) ?? const []) {
        list.add(JournalEntry.fromJson(e as Map<String, dynamic>));
      }
    } catch (_) {}
    return DivinationJournal._(prefs, list);
  }

  Future<void> _save() => _prefs.setString(
      _key, jsonEncode({'schemaVersion': _schemaVersion, 'entries': [for (final e in entries) e.toJson()]}));

  Future<JournalEntry> add({
    required DateTime askedAt,
    required String topic,
    required String school,
    required String question,
    required String verdict,
  }) async {
    final e = JournalEntry(
      id: DateTime.now().microsecondsSinceEpoch,
      askedAt: askedAt,
      topic: topic,
      school: school,
      question: question,
      verdict: verdict,
    );
    entries.insert(0, e);
    if (entries.length > maxEntries) entries.removeRange(maxEntries, entries.length);
    await _save();
    return e;
  }

  Future<void> setFeedback(int id, bool? value) async {
    for (final e in entries) {
      if (e.id == id) e.feedback = value;
    }
    await _save();
  }

  Future<void> remove(JournalEntry e) async {
    entries.removeWhere((x) => x.id == e.id);
    await _save();
  }

  Future<void> restore(JournalEntry e, int index) async {
    entries.insert(index.clamp(0, entries.length), e);
    await _save();
  }
}
