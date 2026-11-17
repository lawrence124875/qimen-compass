import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'qimen_record.dart';

export 'qimen_record.dart';

/// 紀錄存放。[changes] 在新增、修改、刪除後通知（列表頁、首頁數字監聽）。
abstract class RecordStore {
  final changes = ValueNotifier<int>(0);

  /// 新到舊排序。
  Future<List<QimenRecord>> all();

  /// 新增或更新（同 id 取代）。
  Future<void> save(QimenRecord record);

  Future<void> delete(String id);

  /// 還原備份：只加入手機上沒有的 id；回傳實際加入的筆數。
  Future<int> addMissing(List<QimenRecord> records);

  void _changed() => changes.value++;
}

List<QimenRecord> _sorted(Iterable<QimenRecord> r) => r.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

class MemoryRecordStore extends RecordStore {
  final _items = <String, QimenRecord>{};

  @override
  Future<List<QimenRecord>> all() async => _sorted(_items.values);

  @override
  Future<void> save(QimenRecord record) async {
    _items[record.id] = record;
    _changed();
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
    _changed();
  }

  @override
  Future<int> addMissing(List<QimenRecord> records) async {
    var n = 0;
    for (final r in records) {
      if (_items.containsKey(r.id)) continue;
      _items[r.id] = r;
      n++;
    }
    if (n > 0) _changed();
    return n;
  }
}

/// App 文件資料夾 `records.json`（寫入先寫 .tmp 再改名，避免寫到一半當機留下壞檔）。
class FileRecordStore extends RecordStore {
  Map<String, QimenRecord>? _cache;
  Future<void> _writing = Future.value();

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/records.json');

  Future<Map<String, QimenRecord>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final map = <String, QimenRecord>{};
    try {
      final f = await _file();
      if (await f.exists()) {
        for (final r in RecordBackup.decode(await f.readAsString())) {
          map[r.id] = r;
        }
      }
    } catch (e) {
      debugPrint('讀取紀錄失敗：$e');
    }
    return _cache = map;
  }

  Future<void> _persist() {
    final snapshot = _sorted(_cache!.values);
    return _writing = _writing.then((_) async {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(RecordBackup.encode(snapshot, DateTime.now()), flush: true);
      await tmp.rename(f.path);
    }).catchError((Object e) => debugPrint('寫入紀錄失敗：$e'));
  }

  @override
  Future<List<QimenRecord>> all() async => _sorted((await _load()).values);

  @override
  Future<void> save(QimenRecord record) async {
    (await _load())[record.id] = record;
    await _persist();
    _changed();
  }

  @override
  Future<void> delete(String id) async {
    if ((await _load()).remove(id) == null) return;
    await _persist();
    _changed();
  }

  @override
  Future<int> addMissing(List<QimenRecord> records) async {
    final m = await _load();
    var n = 0;
    for (final r in records) {
      if (m.containsKey(r.id)) continue;
      m[r.id] = r;
      n++;
    }
    if (n > 0) {
      await _persist();
      _changed();
    }
    return n;
  }
}
