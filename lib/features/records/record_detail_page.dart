import 'package:flutter/material.dart';

import '../../app/home_page.dart' show ChartInfo;
import '../../app/services.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/chart_board.dart';
import '../../core/records/record_store.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import 'record_list_page.dart';

/// 紀錄詳情：重看當時的盤、改事由與筆記、事後填應驗結果。
class RecordDetailPage extends StatefulWidget {
  const RecordDetailPage({super.key, required this.record});

  final QimenRecord record;

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  late QimenRecord _r = widget.record;
  late final _title = TextEditingController(text: _r.title);
  late final _note = TextEditingController(text: _r.note);
  late final _outcomeNote = TextEditingController(text: _r.outcomeNote);
  late RecordOutcome? _outcome = _r.outcome;
  late final QimenChart _chart =
      const ShiJiaEngine().compute(_r.chartAt, settings: TimeSettings(utcOffset: _r.chartAt.timeZoneOffset));

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _outcomeNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppServices.of(context);
    final first = _r.outcome == null && _outcome != null;
    _r = _r.copyWith(
      title: _title.text.trim(),
      note: _note.text.trim(),
      outcome: _outcome,
      clearOutcome: _outcome == null,
      outcomeNote: _outcomeNote.text.trim(),
      outcomeAt: first ? DateTime.now() : null,
    );
    await s.records.save(_r);
    if (first) s.analytics.log('qm_record_outcome', {'kind': _r.kind.name, 'outcome': _outcome!.name});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(recordKindLabel(l, _r.kind))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(_r.summary, style: serif(t.titleMedium)),
                const SizedBox(height: 4),
                Text(l.recordCreatedAt(formatRecordTime(_r.createdAt)),
                    style: t.bodySmall?.copyWith(color: context.qm.textMuted)),
                const SizedBox(height: 12),
                ChartInfo(chart: _chart, instant: _r.chartAt),
                const SizedBox(height: 8),
                ChartBoard(chart: _chart),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: l.recordTitleLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: InputDecoration(labelText: l.recordNoteLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Text(l.recordOutcomeLabel, style: t.titleSmall),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final o in RecordOutcome.values)
                    ChoiceChip(
                      label: Text(recordOutcomeLabel(l, o)),
                      selected: _outcome == o,
                      onSelected: (on) => setState(() => _outcome = on ? o : null),
                    ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _outcomeNote,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: InputDecoration(
                      labelText: l.recordOutcomeNoteLabel, hintText: l.recordOutcomeNoteHint, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: Text(l.recordSave)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
