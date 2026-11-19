import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import 'travel_text.dart';

/// 一筆出行紀錄（完成的走路／跑步／喝水法）。
class TravelRecord {
  const TravelRecord({
    required this.at,
    required this.mode,
    required this.minutes,
    required this.steps,
    required this.door,
    required this.palace,
    required this.event,
  });

  final DateTime at;

  /// walk／run／water。
  final String mode;
  final int minutes;
  final int steps;
  final Door door;
  final int palace;
  final TravelEvent event;

  Map<String, Object> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'mode': mode,
        'minutes': minutes,
        'steps': steps,
        'door': door.name,
        'palace': palace,
        'event': event.name,
      };

  static TravelRecord? fromJson(Map<String, dynamic> j) {
    try {
      return TravelRecord(
        at: DateTime.parse(j['at'] as String),
        mode: j['mode'] as String,
        minutes: j['minutes'] as int,
        steps: j['steps'] as int,
        door: Door.values.byName(j['door'] as String),
        palace: j['palace'] as int,
        event: TravelEvent.values.byName(j['event'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// 出行紀錄（本機，JSON 帶 schemaVersion；比照謙卦免費版保留最近 30 則）。
class TravelLog {
  TravelLog._();

  static const _key = 'travel_log';
  static const maxItems = 30;

  static Future<List<TravelRecord>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    try {
      final items = (jsonDecode(raw) as Map<String, dynamic>)['items'] as List<dynamic>;
      return items.map((e) => TravelRecord.fromJson(e as Map<String, dynamic>)).whereType<TravelRecord>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<TravelRecord> items) async {
    final keep = items.take(maxItems).map((e) => e.toJson()).toList();
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode({'schemaVersion': 1, 'items': keep}));
  }

  /// 新紀錄放最前面。
  static Future<void> add(TravelRecord r) async => save([r, ...await load()]);
}

/// 出行紀錄頁：左滑刪除，可復原。
class TravelLogPage extends StatefulWidget {
  const TravelLogPage({super.key});

  @override
  State<TravelLogPage> createState() => _TravelLogPageState();
}

class _TravelLogPageState extends State<TravelLogPage> {
  List<TravelRecord>? _items;

  @override
  void initState() {
    super.initState();
    TravelLog.load().then((v) {
      if (mounted) setState(() => _items = v);
    });
  }

  void _delete(int i) {
    final items = _items!;
    final removed = items.removeAt(i);
    setState(() {});
    TravelLog.save(items);
    final l = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.travelLogDeleted),
        persist: false, // 有按鈕的 SnackBar 預設不會自動消失
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l.travelLogUndo,
          onPressed: () {
            if (!mounted) return;
            setState(() => items.insert(i, removed));
            TravelLog.save(items);
          },
        ),
      ));
  }

  String _mode(AppLocalizations l, String m) => switch (m) {
        'run' => l.travelRun,
        'water' => l.travelWater,
        _ => l.travelWalk,
      };

  String _date(DateTime t) {
    final d = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(l.travelLogTitle)),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(child: Text(l.travelLogEmpty, textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final r = items[i];
                    final detail = [
                      TravelText.event(l, r.event),
                      l.travelDirDoor(TravelText.direction(l, r.palace), QimenTerms.door(r.door, L10n.language)),
                      l.travelMinutes(r.minutes),
                      if (r.mode != 'water') l.travelSteps(r.steps),
                    ].join('・');
                    return Dismissible(
                      key: ObjectKey(r),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) => _delete(i),
                      child: ListTile(
                        title: Text('${_date(r.at)}  ${_mode(l, r.mode)}'),
                        subtitle: Text(detail),
                      ),
                    );
                  },
                ),
    );
  }
}
