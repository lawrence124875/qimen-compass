import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../premium/paywall_page.dart';
import '../premium/usage_gate.dart' show AdUnlock;

/// 吉／平／凶三種調性。顏色之外一律加圖示（色弱也分得出來）：吉 ✓、平 –、凶 ✕。
enum Tone { good, neutral, bad }

Tone toneOfLuck(Luck l) => switch (l) { Luck.good => Tone.good, Luck.neutral => Tone.neutral, Luck.bad => Tone.bad };

Tone toneOfLevel(TravelLevel v) => switch (v) {
      TravelLevel.great || TravelLevel.good => Tone.good,
      TravelLevel.neutral => Tone.neutral,
      _ => Tone.bad,
    };

extension ToneStyle on Tone {
  Color color(BuildContext context) {
    final qm = context.qm;
    return switch (this) { Tone.good => qm.good, Tone.neutral => qm.neutral, Tone.bad => qm.bad };
  }

  IconData get icon => switch (this) {
        Tone.good => Icons.check_circle_outline,
        Tone.neutral => Icons.remove_circle_outline,
        Tone.bad => Icons.highlight_off,
      };
}

/// 小圖示＋文字的吉凶標記（列表、羅盤、地圖共用）。
class ToneLabel extends StatelessWidget {
  const ToneLabel({super.key, required this.tone, required this.text, this.style, this.iconSize = 16});

  final Tone tone;
  final String text;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = tone.color(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(tone.icon, size: iconSize, color: c),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: (style ?? const TextStyle()).copyWith(color: c, fontWeight: FontWeight.w700))),
    ]);
  }
}

/// 等級徽章（膠囊形，寬度隨文字）：圖示＋等級字。
class ToneBadge extends StatelessWidget {
  const ToneBadge({super.key, required this.tone, required this.label, this.large = false});

  final Tone tone;
  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = tone.color(context);
    final text = Theme.of(context).textTheme;
    final base = large ? text.headlineSmall : text.bodyMedium;
    return Container(
      constraints: BoxConstraints(minWidth: large ? 72 : 40, minHeight: large ? 48 : 28),
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: large ? 0.12 : 0.0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: large ? 2 : 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(tone.icon, size: large ? 22 : 15, color: color),
        SizedBox(width: large ? 6 : 3),
        Text(label,
            maxLines: 1,
            softWrap: false,
            style: serif(base).copyWith(color: color, fontWeight: FontWeight.w700, height: 1.2)),
      ]),
    );
  }
}

/// 統一結果卡（問事、擇時、目的地、此刻）：大字等級徽章＋一句白話結論＋補充資訊。
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.tone,
    required this.grade,
    required this.headline,
    this.kicker,
    this.meta = const [],
    this.footer,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Tone tone;
  final String grade;

  /// 一句白話結論，例如「15:00 往東南出發最好」。
  final String headline;

  /// 結論上方的小標（例如「此刻吉方」「最佳時段」）。
  final String? kicker;
  final List<String> meta;

  /// 卡片底部的按鈕或補充（例如「用羅盤找」）。
  final Widget? footer;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final color = tone.color(context);
    return Card(
      margin: margin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ToneBadge(tone: tone, label: grade, large: true),
            const SizedBox(width: 12),
            if (kicker != null)
              Expanded(child: Text(kicker!, style: text.labelLarge?.copyWith(color: qm.textMuted)))
            else
              const Spacer(),
          ]),
          const SizedBox(height: 10),
          Text(headline, style: serif(text.titleLarge).copyWith(color: qm.text, fontWeight: FontWeight.w700, height: 1.35)),
          for (final m in meta)
            if (m.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m, style: text.bodyMedium?.copyWith(color: qm.textMuted)),
              ),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ]),
      ),
    );
  }
}

/// 摺疊的「詳解」區。
class DetailsFold extends StatelessWidget {
  const DetailsFold({super.key, required this.children, this.title, this.initiallyExpanded = false});

  final List<Widget> children;
  final String? title;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(Icons.menu_book_outlined, color: qm.primary),
          title: Text(title ?? context.l10n.resultDetails, style: TextStyle(color: qm.primary, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// 免費版鎖住區：把真正的內容模糊顯示（看得到有東西，看不清楚），上面放解鎖按鈕。
/// 內容超過 [height] 會截斷並淡出。
class LockedPreview extends StatelessWidget {
  const LockedPreview({
    super.key,
    required this.feature,
    required this.text,
    required this.child,
    this.onUnlocked,
    this.height = 280,
  });

  final String feature;
  final String text;
  final Widget child;
  final VoidCallback? onUnlocked;
  final double height;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          child: Stack(fit: StackFit.expand, children: [
            ExcludeSemantics(
              child: IgnorePointer(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: child,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [qm.background.withValues(alpha: 0.15), qm.background.withValues(alpha: 0.85)],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_outline, color: qm.primary, size: 30),
                  const SizedBox(height: 8),
                  Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: qm.text)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.lock_open),
                    onPressed: () async {
                      final ok = await openPaywall(context, source: '${feature}_locked', note: l.paywallPremiumNote);
                      if (ok) onUnlocked?.call();
                    },
                    label: Text(l.premiumUnlockFull),
                  ),
                  if (AdUnlock.features.contains(feature))
                    FutureBuilder<bool>(
                      future: AdUnlock.available(context, feature),
                      builder: (context, snap) => snap.data != true
                          ? const SizedBox.shrink()
                          : TextButton.icon(
                              icon: const Icon(Icons.play_circle_outline),
                              label: Text(l.adUnlockOnce),
                              onPressed: () async {
                                if (await AdUnlock.watch(context, feature)) onUnlocked?.call();
                              },
                            ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 單行模糊文字（列表中鎖住的欄位，例如擇時的方位）。
class BlurredText extends StatelessWidget {
  const BlurredText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, size: 15, color: context.qm.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: ExcludeSemantics(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Text(text, style: style, maxLines: 1),
            ),
          ),
        ),
      ]);
}

/// 空狀態：圖示＋一句引導＋按鈕。
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action, this.onAction, this.compact = false});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: compact ? 40 : 56, color: qm.primary.withValues(alpha: 0.7)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: qm.textMuted)),
        if (action != null && onAction != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(action!)),
        ],
      ]),
    );
  }
}
