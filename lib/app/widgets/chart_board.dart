import 'package:flutter/material.dart';

import '../../shared/widgets/result_card.dart' show toneOfLuck, ToneStyle;
import '../../features/lucky/glossary_page.dart';
import '../../features/meaning/meaning_content.dart';

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
    // 盤面字級已依格子大小計算，再套系統字級放大會擠壓重疊，所以盤內固定不跟系統放大。
    return MediaQuery.withNoTextScaling(
      child: AspectRatio(
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
    ),
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
                fit(Text(pc.god == null ? '' : QimenTerms.godName(pc.god!, L10n.language), style: st(0.12, qm.textMuted))),
                const Spacer(),
                fit(Text(stemsText(pc.heavenStems), style: st(0.15, qm.primary, w: FontWeight.w700))),
              ]),
              // 中段整體縮放到可用高度內：標記多（空、馬、迫、刑、墓）時不再溢出蓋到下方宮名、地盤干。
              Expanded(
                child: ClipRect(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(starsText(pc.stars), style: st(0.13, qm.text)),
                        // 門的吉平凶：顏色外加小圖示（色弱可辨）
                        if (door != null)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(toneOfLuck(door.luck).icon, size: s * 0.11, color: qm.luck(door.luck)),
                            SizedBox(width: s * 0.015),
                            Text(QimenTerms.doorName(door, L10n.language), style: st(0.17, qm.luck(door.luck), w: FontWeight.w700)),
                          ]),
                        if (marks.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: s * 0.02),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              for (final m in marks) _MarkChip(text: QimenTerms.markShort(m, L10n.language), size: s),
                            ]),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                fit(Text('${pc.name}${pc.palace}', style: st(0.1, qm.textMuted))),
                // 方位與宮五行（測試等沒有語系時只顯示五行）；空間不夠時縮小
                Flexible(child: fit(Text(
                    <String?>[
                      '',
                      Localizations.of<AppLocalizations>(context, AppLocalizations)?.palaceDirection(pc.palace),
                      palaceElement[pc.palace]!.zh,
                    ].whereType<String>().join('·'),
                    style: st(0.09, qm.textMuted)))),
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
          Text('${QimenTerms.dunName(chart.dun, L10n.language)}${chart.ju}局', style: st(0.14, qm.primary, w: FontWeight.w700)),
          Text(QimenTerms.yuanName(chart.yuan, L10n.language), style: st(0.11, qm.textMuted)),
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

class PalaceDetail extends StatefulWidget {
  const PalaceDetail({super.key, required this.chart, required this.palace});

  final QimenChart chart;
  final int palace;

  @override
  State<PalaceDetail> createState() => _PalaceDetailState();
}

class _PalaceDetailState extends State<PalaceDetail> {
  MeaningContent? _meaning = MeaningContent.cached;

  @override
  void initState() {
    super.initState();
    if (_meaning == null) {
      MeaningContent.load(L10n.language).then((m) {
        if (mounted && m != null) setState(() => _meaning = m);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final palace = widget.palace;
    final mean = _meaning;
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
    // 點盤面元素的解說：術語下方一行小字
    Widget vm(String s, List<String?> notes, {Color? color}) {
      final n = notes.whereType<String>().toList();
      if (n.isEmpty) return v(s, color: color);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        v(s, color: color),
        for (final x in n) Text(x, style: text.bodySmall?.copyWith(color: qm.textMuted)),
      ]);
    }

    List<String?> stemNotes(List<int> st) => [for (final i in st) mean?.lookup('stem', stemNames[i]) == null ? null : '${stemNames[i]}  ${mean!.lookup('stem', stemNames[i])}'];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${QimenTerms.palace(palace, lang)} · ${dir[0].toUpperCase()}${dir.substring(1)}',
              style: serif(text.titleLarge).copyWith(color: qm.primary)),
          const SizedBox(height: 8),
          if (pc.god != null) row(l.labelGod, vm(QimenTerms.god(pc.god!, lang), [mean?.lookup('god', pc.god!.zh)])),
          for (final st in pc.stars) row(l.labelStar, vm(QimenTerms.star(st, lang), [mean?.lookup('star', st.zh)])),
          if (door != null)
            row(l.labelDoor,
                vm('${QimenTerms.door(door, lang)}  ${l.luck(door.luck)}', [mean?.lookup('door', door.zh)], color: qm.luck(door.luck))),
          row(l.labelHeaven, vm(stemsText(pc.heavenStems), stemNotes(pc.heavenStems))),
          row(l.labelEarth, vm(stemsText(pc.earthStems), stemNotes(pc.earthStems))),
          if (palace != 5 && pc.heavenStems.isNotEmpty)
            row(
              l.labelChangSheng,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final st in pc.heavenStems) v('${stemNames[st]}  ${changShengText(st, palace)}'),
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GlossaryPage())),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${l.glossaryOpen} ›', style: text.bodySmall?.copyWith(color: qm.primary)),
                  ),
                ),
              ]),
            ),
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
