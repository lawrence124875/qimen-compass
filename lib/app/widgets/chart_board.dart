import 'package:flutter/material.dart';

import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// 九宮格排列（上南下北，傳統盤面方向）：巽離坤／震中兌／艮坎乾。
const List<List<int>> kBoardLayout = [
  [4, 9, 2],
  [3, 5, 7],
  [8, 1, 6],
];

/// 一宮的標記（空亡、馬星、門迫、擊刑、入墓）。
List<ChartMark> marksOf(PalaceChart p) => [
      if (p.kongWang) ChartMark.kongWang,
      if (p.horse) ChartMark.horse,
      if (p.menPo) ChartMark.menPo,
      if (p.jiXing.isNotEmpty) ChartMark.jiXing,
      if (p.ruMu.isNotEmpty) ChartMark.ruMu,
    ];

String stemsText(List<int> stems) => stems.map((s) => stemNames[s]).join();

/// 九星文字：寄宮時「天芮禽」。
String starsText(List<Star> stars) =>
    stars.isEmpty ? '' : stars.first.zh + stars.skip(1).map((s) => s.zh.substring(1)).join();

/// 時盤九宮格。共用元件：羅盤、出行訣等畫面可直接嵌入。
///
/// - [highlight]：要加框強調的宮（例如羅盤前方所在宮、出行訣的吉方）。
/// - [onTapPalace]：點宮的回呼；預設開啟宮位詳情（[showPalaceSheet]）。
class ChartBoard extends StatelessWidget {
  const ChartBoard({super.key, required this.chart, this.highlight = const {}, this.onTapPalace});

  final QimenChart chart;
  final Set<int> highlight;
  final void Function(int palace)? onTapPalace;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) {
        final cell = box.maxWidth / 3;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: qm.border, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Column(children: [
              for (final row in kBoardLayout)
                Expanded(
                  child: Row(children: [
                    for (final p in row)
                      Expanded(
                        child: p == 5
                            ? _CenterCell(chart: chart, size: cell)
                            : PalaceCell(
                                chart: chart,
                                palace: p,
                                size: cell,
                                highlighted: highlight.contains(p),
                                onTap: () => onTapPalace != null ? onTapPalace!(p) : showPalaceSheet(context, chart, p),
                              ),
                      ),
                  ]),
                ),
            ]),
          ),
        );
      }),
    );
  }
}

/// 一宮：左上八神、右上天盤干、中間九星／八門／標記、左下宮名、右下地盤干。
class PalaceCell extends StatelessWidget {
  const PalaceCell({super.key, required this.chart, required this.palace, required this.size, this.highlighted = false, this.onTap});

  final QimenChart chart;
  final int palace;
  final double size;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    final pc = chart[palace];
    final door = pc.door;
    final s = size;
    TextStyle st(double f, Color c, {FontWeight w = FontWeight.w400}) =>
        serif(TextStyle(fontSize: s * f, color: c, fontWeight: w, height: 1.15));
    Widget fit(Widget w) => FittedBox(fit: BoxFit.scaleDown, child: w);
    final marks = marksOf(pc);

    return Semantics(
      button: true,
      label: '${pc.name}${pc.palace} ${pc.god?.zh ?? ''} ${starsText(pc.stars)} ${door?.zh ?? ''}',
      child: Material(
        color: highlighted ? qm.primary.withValues(alpha: 0.14) : qm.card,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: highlighted ? qm.primary : qm.border.withValues(alpha: 0.45), width: highlighted ? 2 : 0.5),
            ),
            padding: EdgeInsets.all(s * 0.045),
            child: Column(children: [
              Row(children: [
                fit(Text(pc.god?.zh ?? '', style: st(0.12, qm.textMuted))),
                const Spacer(),
                fit(Text(stemsText(pc.heavenStems), style: st(0.15, qm.primary, w: FontWeight.w700))),
              ]),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  fit(Text(starsText(pc.stars), style: st(0.13, qm.text))),
                  if (door != null)
                    fit(Text(door.zh, style: st(0.17, qm.luck(door.luck), w: FontWeight.w700))),
                  if (marks.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: s * 0.02),
                      child: fit(Row(mainAxisSize: MainAxisSize.min, children: [
                        for (final m in marks) _MarkChip(text: QimenTerms.markShort(m), size: s),
                      ])),
                    ),
                ]),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                fit(Text('${pc.name}${pc.palace}', style: st(0.1, qm.textMuted))),
                const Spacer(),
                fit(Text(stemsText(pc.earthStems), style: st(0.13, qm.textMuted))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MarkChip extends StatelessWidget {
  const _MarkChip({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size * 0.008),
      padding: EdgeInsets.symmetric(horizontal: size * 0.018),
      decoration: BoxDecoration(
        border: Border.all(color: qm.bad.withValues(alpha: 0.7), width: 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: serif(TextStyle(fontSize: size * 0.095, color: qm.bad, height: 1.2))),
    );
  }
}

/// 中五宮：地盤干、局數。
class _CenterCell extends StatelessWidget {
  const _CenterCell({required this.chart, required this.size});

  final QimenChart chart;
  final double size;

  @override
  Widget build(BuildContext context) {
    final qm = context.qm;
    final s = size;
    TextStyle st(double f, Color c, {FontWeight w = FontWeight.w400}) =>
        serif(TextStyle(fontSize: s * f, color: c, fontWeight: w, height: 1.2));
    return Container(
      decoration: BoxDecoration(
        color: qm.background,
        border: Border.all(color: qm.border.withValues(alpha: 0.45), width: 0.5),
      ),
      padding: EdgeInsets.all(s * 0.06),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${chart.dun.zh}${chart.ju}局', style: st(0.14, qm.primary, w: FontWeight.w700)),
          Text(chart.yuan.zh, style: st(0.11, qm.textMuted)),
          SizedBox(height: s * 0.04),
          Text('中5  ${stemsText(chart[5].earthStems)}', style: st(0.12, qm.textMuted)),
        ]),
      ),
    );
  }
}

/// 宮位詳情（底部面板）：完整術語（非中文介面含拼音與意譯）、天地盤、標記說明。
Future<void> showPalaceSheet(BuildContext context, QimenChart chart, int palace) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => PalaceDetail(chart: chart, palace: palace),
  );
}

class PalaceDetail extends StatelessWidget {
  const PalaceDetail({super.key, required this.chart, required this.palace});

  final QimenChart chart;
  final int palace;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final qm = context.qm;
    final pc = chart[palace];
    final door = pc.door;
    final text = Theme.of(context).textTheme;
    final dir = l.palaceDirection(palace);

    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 72, child: Text(label, style: text.bodyMedium?.copyWith(color: qm.textMuted))),
            Expanded(child: value),
          ]),
        );
    Text v(String s, {Color? color}) => Text(s, style: text.bodyLarge?.copyWith(color: color ?? qm.text));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${QimenTerms.palace(palace, lang)} · ${dir[0].toUpperCase()}${dir.substring(1)}',
              style: serif(text.titleLarge).copyWith(color: qm.primary)),
          const SizedBox(height: 8),
          if (pc.god != null) row(l.labelGod, v(QimenTerms.god(pc.god!, lang))),
          if (pc.stars.isNotEmpty) row(l.labelStar, v(pc.stars.map((s) => QimenTerms.star(s, lang)).join('\n'))),
          if (door != null) row(l.labelDoor, v('${QimenTerms.door(door, lang)}  ${l.luck(door.luck)}', color: qm.luck(door.luck))),
          row(l.labelHeaven, v(stemsText(pc.heavenStems))),
          row(l.labelEarth, v(stemsText(pc.earthStems))),
          row(
            l.labelMarks,
            marksOf(pc).isEmpty
                ? v(l.marksNone, color: qm.textMuted)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final m in marksOf(pc))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: QimenTerms.mark(m, lang), style: TextStyle(color: qm.bad, fontWeight: FontWeight.w600)),
                          TextSpan(text: '  ${l.markHint(m)}', style: TextStyle(color: qm.textMuted)),
                        ]), style: text.bodyMedium),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
