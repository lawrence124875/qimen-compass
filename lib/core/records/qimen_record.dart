import 'dart:convert';

/// 事後應驗回饋（五級制以外的簡單三選一，文字避開「準／不準」的保證語氣）。
enum RecordOutcome { matched, partly, notMatched }

/// 紀錄的來源功能（篩選用）。新功能加在這裡；舊版讀到不認得的種類一律當 [other]。
enum RecordKind { chart, travel, zeshi, house, divination, other }

/// 一則紀錄（比照謙卦卦記）：當時的盤、使用者想記的事，之後回來填應驗結果。
/// 不上傳；存在 App 文件資料夾 `records.json`。
class QimenRecord {
  const QimenRecord({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.chartAt,
    required this.summary,
    this.title = '',
    this.note = '',
    this.outcome,
    this.outcomeNote = '',
    this.outcomeAt,
    this.meta = const {},
  });

  final String id;
  final DateTime createdAt;
  final RecordKind kind;

  /// 起盤的時間（可能與建立時間不同，例如記下一個未來的吉時）。
  final DateTime chartAt;

  /// 盤面摘要（App 產生，例如「陽遁三局・東南・生門」）。
  final String summary;

  /// 使用者寫的事由（可空）。
  final String title;
  final String note;

  final RecordOutcome? outcome;
  final String outcomeNote;
  final DateTime? outcomeAt;

  /// 功能自帶的資料（例如問事的 topic／school／verdict，重看解讀用）。
  final Map<String, Object?> meta;

  bool get hasOutcome => outcome != null;

  QimenRecord copyWith({
    String? title,
    String? note,
    RecordOutcome? outcome,
    bool clearOutcome = false,
    String? outcomeNote,
    DateTime? outcomeAt,
  }) =>
      QimenRecord(
        id: id,
        createdAt: createdAt,
        kind: kind,
        chartAt: chartAt,
        summary: summary,
        title: title ?? this.title,
        note: note ?? this.note,
        outcome: clearOutcome ? null : (outcome ?? this.outcome),
        outcomeNote: outcomeNote ?? this.outcomeNote,
        outcomeAt: clearOutcome ? null : (outcomeAt ?? this.outcomeAt),
        meta: meta,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'kind': kind.name,
        'chartAt': chartAt.toUtc().toIso8601String(),
        'summary': summary,
        if (title.isNotEmpty) 'title': title,
        if (note.isNotEmpty) 'note': note,
        if (outcome != null) 'outcome': outcome!.name,
        if (outcomeNote.isNotEmpty) 'outcomeNote': outcomeNote,
        if (outcomeAt != null) 'outcomeAt': outcomeAt!.toUtc().toIso8601String(),
        if (meta.isNotEmpty) 'meta': meta,
      };

  /// 格式不對回傳 null（略過該筆，不讓整份檔案讀不出來）。
  static QimenRecord? tryFromJson(Map<String, dynamic> j) {
    try {
      T? byName<T extends Enum>(List<T> values, Object? name) {
        for (final v in values) {
          if (v.name == name) return v;
        }
        return null;
      }

      return QimenRecord(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        kind: byName(RecordKind.values, j['kind']) ?? RecordKind.other,
        chartAt: DateTime.parse(j['chartAt'] as String).toLocal(),
        summary: j['summary'] as String? ?? '',
        title: j['title'] as String? ?? '',
        note: j['note'] as String? ?? '',
        outcome: byName(RecordOutcome.values, j['outcome']),
        outcomeNote: j['outcomeNote'] as String? ?? '',
        outcomeAt: j['outcomeAt'] == null ? null : DateTime.parse(j['outcomeAt'] as String).toLocal(),
        meta: j['meta'] is Map ? (j['meta'] as Map).cast<String, Object?>() : const {},
      );
    } catch (_) {
      return null;
    }
  }

  /// 搜尋（事由、筆記、摘要、應驗筆記）。
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [title, note, summary, outcomeNote].any((s) => s.toLowerCase().contains(q));
  }
}

/// 備份檔：使用者自行匯出、自己選擇存放位置，換手機時再匯入。App 不上傳任何資料。
class RecordBackup {
  RecordBackup._();

  static const format = 'qimen-records';
  static const schemaVersion = 1;

  static String encode(List<QimenRecord> records, DateTime exportedAt) => const JsonEncoder.withIndent(' ').convert({
        'format': format,
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'records': [for (final r in records) r.toJson()],
      });

  /// 不是紀錄備份時丟 [FormatException]；個別不合法的紀錄略過。
  static List<QimenRecord> decode(String text) {
    final Object? data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      throw const FormatException('not json');
    }
    if (data is! Map<String, dynamic>) throw const FormatException('not an object');
    final fmt = data['format'];
    if (fmt != null && fmt != format) throw const FormatException('other format');
    final list = data['records'];
    if (list is! List) throw const FormatException('no records');
    return [for (final e in list.whereType<Map<String, dynamic>>()) QimenRecord.tryFromJson(e)]
        .whereType<QimenRecord>()
        .toList();
  }

  static String fileName(DateTime at) =>
      '$format-${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}.json';
}
