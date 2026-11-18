import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/services.dart';
import '../../app/theme/app_theme.dart';
import '../../core/records/record_store.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import 'divination_content.dart';
import '../records/record_list_page.dart';
import 'divination_journal.dart';
import 'reading_page.dart';

/// 奇門問事（HANDOFF §8）：選事類 → 以現在時間起局 → 解讀。
class DivinationPage extends StatefulWidget {
  const DivinationPage({super.key});

  @override
  State<DivinationPage> createState() => _DivinationPageState();
}

class _DivinationPageState extends State<DivinationPage> {
  static const _kTopic = 'qm_div_topic';
  static const _kSchool = 'qm_div_school';
  static const _kGuide = 'qm_div_guide_seen';

  DivinationContent? _content;
  bool _loaded = false;
  String? _topic;
  final Map<String, String> _schools = {};
  final _question = TextEditingController();
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final content = await DivinationContent.load(L10n.language);
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    if (!mounted) return;
    DivinationJournal.migrate(AppServices.of(context).records);
    setState(() {
      _content = content;
      _prefs = prefs;
      _loaded = true;
      if (content != null) {
        final saved = prefs?.getString(_kTopic);
        _topic = content.rules.topics.contains(saved) ? saved : content.rules.topics.first;
        for (final s in prefs?.getStringList(_kSchool) ?? const <String>[]) {
          final i = s.indexOf('=');
          if (i > 0) _schools[s.substring(0, i)] = s.substring(i + 1);
        }
      }
    });
    if (content != null && prefs?.getBool(_kGuide) != true) {
      await prefs?.setBool(_kGuide, true);
      if (mounted) await showDivinationGuide(context);
    }
  }

  String _schoolOf(String topic) {
    final s = _schools[topic];
    return s != null && _content!.rules.schoolsFor(topic).contains(s) ? s : _content!.rules.defaultSchool;
  }

  void _setTopic(String t) {
    setState(() => _topic = t);
    _prefs?.setString(_kTopic, t);
  }

  void _setSchool(String s) {
    setState(() => _schools[_topic!] = s);
    _prefs?.setStringList(_kSchool, [for (final e in _schools.entries) '${e.key}=${e.value}']);
  }

  Future<void> _start() async {
    final content = _content!;
    final now = DateTime.now();
    final reading = const DivinationEngine().read(
      content.rules,
      _topic!,
      now,
      school: _schoolOf(_topic!),
      settings: TimeSettings(utcOffset: now.timeZoneOffset),
    );
    final journal = DivinationJournal(AppServices.of(context).records);
    final entry = await journal.add(
      askedAt: now,
      topic: reading.topic,
      school: reading.school,
      question: _question.text.trim(),
      verdict: reading.verdict.name,
      summary: divinationSummary(context.l10n, content.text, reading.topic, reading.verdict.name),
    );
    if (!mounted) return;
    _question.clear();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReadingPage(content: content, reading: reading, entry: entry, journal: journal),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final content = _content;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.divTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l.divGuideTitle,
            onPressed: () => showDivinationGuide(context),
          ),
          // 明顯的「紀錄」按鈕：開統一紀錄並只顯示問事
          TextButton.icon(
            icon: const Icon(Icons.history),
            label: Text(l.divJournal),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const RecordListPage(initialKind: RecordKind.divination))),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : content == null
              ? Center(child: Text(l.divContentMissing, textAlign: TextAlign.center))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(l.divTopic, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in content.rules.topics)
                        ChoiceChip(
                          label: Text(content.text.topicName(t)),
                          selected: t == _topic,
                          onSelected: (_) => _setTopic(t),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Text(content.text.topicDesc(_topic!), style: theme.textTheme.bodyMedium?.copyWith(color: context.qm.textMuted)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _question,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: l.divQuestion,
                        hintText: content.text.topicAsk(_topic!),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (content.rules.schoolsFor(_topic!).length > 1) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _schoolOf(_topic!),
                        decoration: InputDecoration(labelText: l.divSchool, border: const OutlineInputBorder()),
                        isExpanded: true,
                        items: [
                          for (final s in content.rules.schoolsFor(_topic!))
                            DropdownMenuItem(value: s, child: Text(content.text.schoolName(s))),
                        ],
                        onChanged: (s) => s == null ? null : _setSchool(s),
                      ),
                      const SizedBox(height: 4),
                      Text(content.text.schoolDesc(_schoolOf(_topic!)),
                          style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _start, child: Text(l.divStart)),
                    const SizedBox(height: 16),
                    Text(l.homeDisclaimer,
                        textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
                  ],
                ),
    );
  }
}

/// 首次進入的 3 頁引導（右上 ⓘ 可重看）。
Future<void> showDivinationGuide(BuildContext context) {
  final l = context.l10n;
  final pages = [l.divGuide1, l.divGuide2, l.divGuide3];
  var i = 0;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('${l.divGuideTitle}（${i + 1}/3）'),
        content: Text(pages[i]),
        actions: [
          if (i > 0) TextButton(onPressed: () => set(() => i--), child: Text(l.divGuidePrev)),
          FilledButton(
            onPressed: () => i < 2 ? set(() => i++) : Navigator.of(ctx).pop(),
            child: Text(i < 2 ? l.divGuideNext : l.divGuideDone),
          ),
        ],
      ),
    ),
  );
}

String formatAskedAt(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// 五級徽章（大吉／吉／平／小阻／阻）。
class VerdictBadge extends StatelessWidget {
  const VerdictBadge({super.key, required this.verdict, this.large = false});

  final Verdict verdict;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final label = switch (verdict) {
      Verdict.great => l.levelGreat,
      Verdict.good => l.levelGood,
      Verdict.neutral => l.levelNeutral,
      Verdict.minor => l.levelMinor,
      Verdict.blocked => l.levelBlocked,
    };
    final color = switch (verdict) {
      Verdict.great || Verdict.good => qm.good,
      Verdict.neutral => qm.neutral,
      _ => qm.bad,
    };
    final size = large ? 64.0 : 40.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: large ? 2 : 1.5)),
      child: Text(label,
          style: serif(large ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.bodyMedium)
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
