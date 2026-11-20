import 'package:flutter/material.dart' hide Element;

import '../../app/services.dart';
import '../../app/settings/app_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/usage_gate.dart';
import '../../shared/widgets/result_card.dart';
import '../meaning/meaning_content.dart';
import '../personal/profile.dart';
import '../travel/travel_text.dart';

/// 五行代表色（色票用實際顏色，不跟主題）。
const Map<Element, Color> elementSwatch = {
  Element.wood: Color(0xFF2E7D32),
  Element.fire: Color(0xFFD32F2F),
  Element.earth: Color(0xFFC9A227),
  Element.metal: Color(0xFFF2F2F2),
  Element.water: Color(0xFF1F3B73),
};

class _Swatch extends StatelessWidget {
  const _Swatch(this.e);
  final Element e;

  Future<void> _setBirth() async {
    final np = await editProfile(context, _profile);
    if (np != null && mounted) setState(() => _profile = np);
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: elementSwatch[e],
          shape: BoxShape.circle,
          border: Border.all(color: context.qm.textMuted.withValues(alpha: 0.5)),
        ),
      );
}

/// 今日吉色（此刻頁）：免費版看日干五行；訂閱結合年命給個人吉色。
class LuckyColorCard extends StatefulWidget {
  const LuckyColorCard({super.key, required this.day});

  final GanZhi day;

  @override
  State<LuckyColorCard> createState() => _LuckyColorCardState();
}

class _LuckyColorCardState extends State<LuckyColorCard> {
  MeaningContent? _meaning = MeaningContent.cached;
  Profile? _profile;
  bool _loaded = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    MeaningContent.load(L10n.language).then((m) {
      if (mounted && m != null) setState(() => _meaning = m);
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await Profile.load();
    if (mounted) {
      setState(() {
        _profile = p;
        _loaded = true;
      });
    }
  }

  Future<void> _unlock() async {
    final a = await requirePremium(context, feature: 'lucky_personal');
    if (mounted && a != PremiumAccess.titleOnly) setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final c = LuckyColors.ofDay(widget.day);
    String colors(Element e) => _meaning?.lookup('color', e.zh) ?? e.zh;
    String rankName(ColorRank r) => switch (r) {
          ColorRank.great => l.luckyGreat,
          ColorRank.good => l.luckyGood,
          ColorRank.wealth => l.luckyWealth,
          ColorRank.drain => l.luckyDrain,
          ColorRank.avoid => l.luckyAvoid,
        };
    Widget row(String label, Element e, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 76, child: Text(label, style: text.bodyMedium?.copyWith(color: color ?? qm.textMuted))),
            _Swatch(e),
            const SizedBox(width: 8),
            Expanded(
                child: Text(colors(e),
                    style: (bold ? text.titleSmall : text.bodyMedium)?.copyWith(color: qm.text, fontWeight: bold ? FontWeight.w700 : null))),
          ]),
        );

    final premium = AppServices.of(context).isPremium || _revealed;
    final p = _profile;
    Widget personal;
    if (!_loaded) {
      personal = const SizedBox.shrink();
    } else if (p == null) {
      personal = TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        icon: const Icon(Icons.cake_outlined, size: 18),
        label: Text(l.profileTitle),
        onPressed: _setBirth, // 直接開生日設定，不跳到「我的」
      );
    } else if (!premium) {
      personal = TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        icon: const Icon(Icons.lock_outline, size: 18),
        label: Text(l.luckyPersonalUnlock),
        onPressed: _unlock,
      );
    } else {
      final s = AppSettings.instance;
      final birth = BirthInfo.fromInstant(p.birthInstant, settings: s.timeSettingsAt(p.birthInstant));
      final (best, worst) = c.personal(birth.year.stem);
      personal = Column(children: [
        row(l.luckyPersonal, best, color: qm.primary, bold: true),
        row(l.luckyPersonalAvoid, worst, color: qm.bad),
      ]);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.palette_outlined, color: qm.primary),
            const SizedBox(width: 8),
            Text(l.luckyTitle, style: serif(text.titleMedium).copyWith(color: qm.text, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 2),
          Text(l.luckyBasis, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          const SizedBox(height: 6),
          for (final r in ColorRank.values)
            row(rankName(r), c.of(r),
                color: r == ColorRank.great ? qm.good : r == ColorRank.avoid ? qm.bad : null, bold: r == ColorRank.great),
          const Divider(height: 16),
          personal,
        ]),
      ),
    );
  }
}

/// 發訊息時機（此刻頁）：目前起連續 4 個時辰，依「發訊息」情境打分。免費。
class MessageTimingCard extends StatelessWidget {
  const MessageTimingCard({super.key, required this.now});

  final DateTime now;

  static const _planner = ZeShiPlanner();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final app = AppSettings.instance;
    final slots = _planner.upcoming(now, ZeShiEvent.message, settings: app.timeSettingsAt(now), method: app.juMethod);
    String hm(DateTime t) {
      final x = t.toLocal();
      return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
    }

    bool good(ZeShiSlot s) => toneOfLevel(s.level) == Tone.good;
    final firstGood = slots.where(good).firstOrNull;
    final headline = firstGood == null
        ? l.msgNoneGood
        : identical(firstGood, slots.first)
            ? l.msgNowGood
            : l.msgBestAt(hm(firstGood.startUtc));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.send_outlined, color: qm.primary),
            const SizedBox(width: 8),
            Text(l.msgTitle, style: serif(text.titleMedium).copyWith(color: qm.text, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 2),
          Text(l.msgSub, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          const SizedBox(height: 6),
          Text(headline, style: text.titleSmall?.copyWith(color: firstGood == null ? qm.neutral : qm.good)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final s in slots)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${hm(s.startUtc)} ${l.travelHourName(branchNames[s.chart.hour.branch])}',
                    style: text.bodySmall?.copyWith(color: qm.textMuted)),
                const SizedBox(height: 2),
                ToneBadge(tone: toneOfLevel(s.level), label: TravelText.level(l, s.level)),
              ]),
          ]),
        ]),
      ),
    );
  }
}

/// 擇時「營業時段」的一週時段表：每天一列，每個時辰一格（吉凶顏色）。
class WeekTable extends StatelessWidget {
  const WeekTable({super.key, required this.slots});

  final List<ZeShiSlot> slots;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final byDay = <String, List<ZeShiSlot>>{};
    for (final s in [...slots]..sort((a, b) => a.startUtc.compareTo(b.startUtc))) {
      final t = s.startUtc.toLocal();
      byDay.putIfAbsent('${t.month}/${t.day}（${l.zeshiWeekdays.split(',')[t.weekday - 1]}）', () => []).add(s);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.zeshiWeekTitle, style: text.titleMedium),
      const SizedBox(height: 6),
      for (final e in byDay.entries.take(7))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 78, child: Text(e.key, style: text.bodySmall)),
            Expanded(
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (final s in e.value)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: toneOfLevel(s.level).color(context).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: toneOfLevel(s.level).color(context).withValues(alpha: 0.6)),
                    ),
                    child: Text('${s.startUtc.toLocal().hour.toString().padLeft(2, '0')} ${TravelText.level(l, s.level)}',
                        style: text.labelSmall?.copyWith(color: qm.text)),
                  ),
              ]),
            ),
          ]),
        ),
    ]);
  }
}
