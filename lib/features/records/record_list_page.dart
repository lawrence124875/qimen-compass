import 'package:flutter/material.dart';

import '../../app/main_shell.dart';
import '../../shared/widgets/result_card.dart';
import '../../app/services.dart';
import '../../app/theme/app_theme.dart';
import '../../core/records/record_store.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/premium/paywall_page.dart';
import '../divination/divination_journal.dart';
import 'record_actions.dart';
import 'record_detail_page.dart';

String recordKindLabel(AppLocalizations l, RecordKind k) => switch (k) {
      RecordKind.chart => l.recordKindChart,
      RecordKind.travel => l.recordKindTravel,
      RecordKind.zeshi => l.recordKindZeshi,
      RecordKind.house => l.recordKindHouse,
      RecordKind.divination => l.recordKindDivination,
      RecordKind.other => l.recordKindOther,
    };

String recordOutcomeLabel(AppLocalizations l, RecordOutcome o) => switch (o) {
      RecordOutcome.matched => l.outcomeMatched,
      RecordOutcome.partly => l.outcomePartly,
      RecordOutcome.notMatched => l.outcomeNotMatched,
    };

String formatRecordTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 紀錄列表（比照謙卦卦記）：搜尋、依種類／待回饋篩選、左滑刪除可復原、應驗統計、備份還原。
/// 免費版只顯示最近 [FreeLimits.recordDays] 天，較早的上鎖（點了開訂閱頁）。
class RecordListPage extends StatefulWidget {
  const RecordListPage({super.key, this.initialKind});

  /// 從功能頁開啟時預先篩選（例如問事頁的「紀錄」按鈕）。
  final RecordKind? initialKind;

  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

enum _Filter { all, pending }

class _RecordListPageState extends State<RecordListPage> {
  final _search = TextEditingController();
  late Object _filter = widget.initialKind ?? _Filter.all; // _Filter 或 RecordKind

  @override
  void initState() {
    super.initState();
    // 舊版問事紀錄搬進統一紀錄（只做一次）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) DivinationJournal.migrate(AppServices.of(context).records);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _pass(QimenRecord r) {
    if (!r.matches(_search.text)) return false;
    final f = _filter;
    if (f == _Filter.pending) return !r.hasOutcome;
    if (f is RecordKind) return r.kind == f;
    return true;
  }

  Future<void> _delete(QimenRecord r) async {
    final s = AppServices.of(context);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await s.records.delete(r.id);
    await RecordReminders.cancel(r);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(l.recordDeleted),
      action: SnackBarAction(label: l.undo, onPressed: () => s.records.save(r)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = AppServices.of(context);
    final qm = context.qm;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.recordsTitle),
        actions: [
          PopupMenuButton<int>(
            onSelected: (i) => i == 0 ? RecordBackupActions.backup(context) : RecordBackupActions.restore(context),
            itemBuilder: (_) => [
              PopupMenuItem(value: 0, child: Text(l.recordBackup)),
              PopupMenuItem(value: 1, child: Text(l.recordRestore)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const AdBanner(),
      body: ValueListenableBuilder<int>(
        valueListenable: s.records.changes,
        builder: (context, _, __) => FutureBuilder<List<QimenRecord>>(
          future: s.records.all(),
          builder: (context, snap) {
            final all = snap.data;
            if (all == null) return const Center(child: CircularProgressIndicator());
            if (all.isEmpty) {
              return Center(
                child: EmptyState(
                  icon: Icons.bookmarks_outlined,
                  text: l.recordsEmpty,
                  action: l.emptyRecordsAction,
                  onAction: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    MainShell.select(MainTab.chart);
                  },
                ),
              );
            }
            final cutoff = DateTime.now().subtract(Duration(days: s.limits.recordDays));
            final kinds = {for (final r in all) r.kind, if (widget.initialKind != null) widget.initialKind!}.toList()..sort((a, b) => a.index.compareTo(b.index));
            final shown = all.where(_pass).toList();
            final judged = all.where((r) => r.hasOutcome).toList();
            int count(RecordOutcome o) => judged.where((r) => r.outcome == o).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.recordSearchHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in <Object>[_Filter.all, _Filter.pending, ...kinds])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: Text(switch (f) {
                            _Filter.all => l.recordFilterAll,
                            _Filter.pending => l.recordFilterPending,
                            RecordKind k => recordKindLabel(l, k),
                            _ => '',
                          }),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ]),
                ),
                if (judged.isNotEmpty && !s.isPremium) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart),
                    onPressed: () async {
                      if (await openPaywall(context, source: 'record_stats') && mounted) setState(() {});
                    },
                    icon: const Icon(Icons.lock_outline, size: 16),
                    label: Text(l.recordStatsLocked(judged.length)),
                  ),
                ] else if (judged.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.recordStats(judged.length, count(RecordOutcome.matched), count(RecordOutcome.partly),
                        count(RecordOutcome.notMatched)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: qm.textMuted),
                  ),
                ],
                const SizedBox(height: 8),
                for (final r in shown)
                  if (!s.isPremium && r.createdAt.isBefore(cutoff))
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.lock_outline, color: qm.textMuted),
                        title: Text(formatRecordTime(r.createdAt)),
                        subtitle: Text(l.recordLocked(s.limits.recordDays)),
                        onTap: () => openPaywall(context, source: 'record_locked'),
                      ),
                    )
                  else
                    Dismissible(
                      key: ValueKey(r.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: qm.bad.withValues(alpha: 0.25),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) => _delete(r),
                      child: Card(
                        child: ListTile(
                          title: Text(r.title.isEmpty ? r.summary : r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${recordKindLabel(l, r.kind)}${l.separator}${formatRecordTime(r.chartAt)}'
                            '${r.title.isEmpty ? '' : '\n${r.summary}'}',
                          ),
                          isThreeLine: r.title.isNotEmpty,
                          trailing: r.outcome == null
                              ? Text(l.recordFilterPending, style: TextStyle(color: qm.accent))
                              : Text(recordOutcomeLabel(l, r.outcome!)),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => RecordDetailPage(record: r))),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
