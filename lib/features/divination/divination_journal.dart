import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/records/record_store.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import 'divination_content.dart';

/// 五級文字（大吉／吉／平／小阻／阻）。
String verdictLabel(AppLocalizations l, Verdict v) => switch (v) {
      Verdict.great => l.levelGreat,
      Verdict.good => l.levelGood,
      Verdict.neutral => l.levelNeutral,
      Verdict.minor => l.levelMinor,
      Verdict.blocked => l.levelBlocked,
    };

/// 紀錄列表顯示的摘要：「求財・吉」。
String divinationSummary(AppLocalizations l, DivinationText text, String topic, String verdict) {
  final v = Verdict.values.asNameMap()[verdict];
  return v == null ? text.topicName(topic) : '${text.topicName(topic)}${l.separator}${verdictLabel(l, v)}';
}

/// 問事紀錄：存在統一紀錄（`RecordKind.divination`，`meta` 帶 topic／school／verdict），
/// 盤面與解讀不存，打開時依起局時間重算（引擎固定，結果一致）。應驗回饋對應紀錄的 outcome。
class JournalEntry {
  JournalEntry(this.record);

  QimenRecord record;

  String get id => record.id;
  DateTime get askedAt => record.chartAt;
  String get topic => record.meta['topic'] as String? ?? '';
  String get school => record.meta['school'] as String? ?? '';
  String get verdict => record.meta['verdict'] as String? ?? '';
  String get question => record.title;

  /// 事後回饋：true 應驗、false 不準、null 未回饋（部分應驗當作應驗）。
  bool? get feedback => switch (record.outcome) {
        null => null,
        RecordOutcome.notMatched => false,
        _ => true,
      };

  static bool isDivination(QimenRecord r) => r.kind == RecordKind.divination && r.meta['topic'] is String;
}

class DivinationJournal {
  DivinationJournal(this._store);

  final RecordStore _store;

  static const _legacyKey = 'qm_div_journal';

  /// 舊版（SharedPreferences `qm_div_journal`）搬進統一紀錄，只做一次；id 沿用避免重複。
  static Future<void> migrate(RecordStore store) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null) return;
    final out = <QimenRecord>[];
    final content = await DivinationContent.load(L10n.language);
    final l = L10n.current;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in (j['entries'] as List?) ?? const []) {
        final m = e as Map<String, dynamic>;
        final askedAt = DateTime.parse(m['askedAt'] as String).toLocal();
        final fb = m['feedback'] as bool?;
        out.add(QimenRecord(
          id: 'div${m['id']}',
          createdAt: askedAt,
          kind: RecordKind.divination,
          chartAt: askedAt,
          summary: content == null
              ? '${m['topic']}'
              : divinationSummary(l, content.text, m['topic'] as String, m['verdict'] as String? ?? ''),
          title: m['question'] as String? ?? '',
          outcome: fb == null ? null : (fb ? RecordOutcome.matched : RecordOutcome.notMatched),
          meta: {'topic': m['topic'], 'school': m['school'], 'verdict': m['verdict']},
        ));
      }
    } catch (_) {}
    if (out.isNotEmpty) await store.addMissing(out);
    await prefs.remove(_legacyKey);
  }

  /// 新增一筆（問事不受免費紀錄上限限制，屬訂閱功能）。[summary] 例「求財・吉」。
  Future<JournalEntry> add({
    required DateTime askedAt,
    required String topic,
    required String school,
    required String question,
    required String verdict,
    required String summary,
  }) async {
    final r = QimenRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      kind: RecordKind.divination,
      chartAt: askedAt,
      summary: summary,
      title: question,
      meta: {'topic': topic, 'school': school, 'verdict': verdict},
    );
    await _store.save(r);
    return JournalEntry(r);
  }

  Future<void> setFeedback(JournalEntry e, bool? value) async {
    e.record = e.record.copyWith(
      outcome: value == null ? null : (value ? RecordOutcome.matched : RecordOutcome.notMatched),
      clearOutcome: value == null,
      outcomeAt: value == null ? null : DateTime.now(),
    );
    await _store.save(e.record);
  }
}
