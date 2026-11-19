import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/services.dart';
import '../../core/records/record_store.dart';
import '../../l10n/l10n.dart';
import '../../services/notifications.dart';
import '../../shared/premium/paywall_page.dart';
import '../../shared/premium/usage_gate.dart';

/// 記下一盤（首頁、出行訣、擇時、占卜共用）。其他功能直接呼叫：
/// `saveRecord(context, kind: RecordKind.zeshi, chartAt: t, summary: '…')`。
/// 免費版已達上限時開訂閱頁；存好後可選「N 天後提醒我回來記應驗」。
Future<bool> saveRecord(
  BuildContext context, {
  required RecordKind kind,
  required DateTime chartAt,
  required String summary,
  String title = '',
}) async {
  final s = AppServices.of(context);
  final l = context.l10n;
  if (!s.isPremium && (await s.records.all()).length >= s.limits.recordMax) {
    if (!context.mounted) return false;
    final ok = await openPaywall(context, source: 'record_limit', note: l.recordLimitNote(s.limits.recordMax));
    if (!ok) return false;
  }
  if (!context.mounted) return false;
  final input = await showModalBottomSheet<_SaveInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SaveSheet(summary: summary, title: title),
  );
  if (input == null || !context.mounted) return false;
  final now = DateTime.now();
  final r = QimenRecord(
    id: '${now.microsecondsSinceEpoch}',
    createdAt: now,
    kind: kind,
    chartAt: chartAt,
    summary: summary,
    title: input.title,
    note: input.note,
  );
  await s.records.save(r);
  s.analytics.log('qm_record_saved', {'kind': kind.name, 'remind_days': input.remindDays});
  final messenger = ScaffoldMessenger.of(context);
  var text = l.recordSaved;
  if (input.remindDays > 0) {
    final ok = await RecordReminders.schedule(r, input.remindDays);
    if (!ok) text = '$text\n${l.recordRemindDenied}';
  }
  messenger.showSnackBar(SnackBar(content: Text(text)));
  return true;
}

class _SaveInput {
  const _SaveInput(this.title, this.note, this.remindDays);
  final String title, note;
  final int remindDays;
}

class _SaveSheet extends StatefulWidget {
  const _SaveSheet({required this.summary, required this.title});
  final String summary, title;

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  late final _title = TextEditingController(text: widget.title);
  final _note = TextEditingController();
  int _days = 3;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(l.recordSaveTitle, style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(widget.summary, style: t.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 100,
              decoration: InputDecoration(labelText: l.recordTitleLabel, hintText: l.recordTitleHint, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(labelText: l.recordNoteLabel, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Text(l.recordRemindLabel, style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final d in const [0, 1, 3, 7])
                ChoiceChip(
                  label: Text(d == 0 ? l.recordRemindNone : l.recordRemindDays(d)),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, _SaveInput(_title.text.trim(), _note.text.trim(), _days)),
              child: Text(l.recordSave),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 「回來記應驗」提醒：N 天後晚上八點（id 1100–1199；通知內文不放使用者寫的事由，鎖定畫面看得到）。
class RecordReminders {
  RecordReminders._();

  static const idFrom = 1100, idTo = 1199;
  static const hour = 20;

  static int idFor(QimenRecord r) => idFrom + (r.id.hashCode.abs() % (idTo - idFrom + 1));

  static Future<bool> schedule(QimenRecord r, int days) async {
    if (!await Notifications.enabled() && !await Notifications.requestPermission()) return false;
    final c = r.createdAt;
    final at = DateTime(c.year, c.month, c.day + days, hour);
    final l = L10n.current;
    await Notifications.schedule(
      id: idFor(r),
      title: l.recordRemindTitle,
      body: l.recordRemindBody(days),
      atUtc: at.toUtc(),
      channelId: 'qm_record_review',
      channelName: l.recordChannelName,
    );
    return true;
  }

  static Future<void> cancel(QimenRecord r) => Notifications.cancel(idFor(r));
}

/// 備份與還原（設定頁、紀錄列表選單共用）。App 不上傳任何資料：使用者自行選擇存放位置。
class RecordBackupActions {
  RecordBackupActions._();

  static void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  static Future<void> backup(BuildContext context) async {
    final l = context.l10n;
    final store = AppServices.of(context).records;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final records = await store.all();
    if (!context.mounted) return;
    if (records.isEmpty) return _snack(context, l.recordBackupEmpty);
    // 備份屬訂閱功能（還原永遠免費，避免資料拿不回來）
    final access = await requirePremium(context, feature: 'backup');
    if (access == PremiumAccess.titleOnly || !context.mounted) return;
    try {
      final now = DateTime.now();
      final file = File('${(await getTemporaryDirectory()).path}/${RecordBackup.fileName(now)}');
      await file.writeAsString(RecordBackup.encode(records, now));
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: l.recordBackupSubject,
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (context.mounted) _snack(context, l.shareFailed);
    }
  }

  static Future<void> restore(BuildContext context) async {
    final l = context.l10n;
    final store = AppServices.of(context).records;
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      final records = RecordBackup.decode(utf8.decode(await file.readAsBytes()));
      final added = await store.addMissing(records);
      if (context.mounted) _snack(context, added == 0 ? l.recordRestoreNone : l.recordRestoreDone(added));
    } catch (_) {
      if (context.mounted) _snack(context, l.recordRestoreFailed);
    }
  }
}
