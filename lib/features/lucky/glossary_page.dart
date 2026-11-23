import 'package:flutter/material.dart' hide Element;

import '../../app/theme/app_theme.dart';
import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../meaning/meaning_content.dart';

/// 圖鑑（免費）：八門宜忌、五行速查、十二長生、神煞。內容在 qimen-content `app/meaning`（鍵 `bm:`、`wx:`、`cs:`、`ss:`）。
/// 入口：入門課頁、盤面宮位詳情。
const List<String> shenShaKeys = ['驛馬', '空亡', '擊刑', '入墓', '門迫', '伏吟', '反吟', '五不遇時', '天乙貴人', '桃花'];

/// 五行速查的列（內容鍵 `wx:`）。
const List<String> wuXingKeys = ['九宮', '八門', '九星', '天干', '生剋'];

const Map<String, String> _hans = {
  '長生': '长生', '冠帶': '冠带', '臨官': '临官', '絕': '绝', '養': '养', //
  '驛馬': '驿马', '九宮': '九宫', '八門': '八门', '九星': '九星', '天干': '天干', '生剋': '生克', //
   '擊刑': '击刑', '門迫': '门迫', '五不遇時': '五不遇时', '天乙貴人': '天乙贵人',
};

/// 術語漢字（簡中介面轉簡體）。
String glossaryHanzi(String zh) => L10n.language == AppLanguages.zhHans ? (_hans[zh] ?? zh) : zh;

/// 宮位詳情用：某天干在此宮各地支的長生狀態，例如「丑墓・寅絕」。
String changShengText(int stem, int palace) => [
      for (final b in palaceBranches[palace] ?? const <int>[]) '${branchNames[b]}${glossaryHanzi(changShengOf(stem, b).zh)}',
    ].join('・');

class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key});

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  MeaningContent? _m = MeaningContent.cached;

  @override
  void initState() {
    super.initState();
    MeaningContent.load(L10n.language).then((m) {
      if (mounted && m != null) setState(() => _m = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    Widget item(String zh, String? body, {Color? color, bool raw = false}) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(raw ? zh : glossaryHanzi(zh), style: serif(text.titleMedium).copyWith(color: color ?? qm.primary)),
          subtitle: body == null ? null : Text(body, style: text.bodyMedium?.copyWith(color: qm.text)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.glossaryTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          Text(l.glossaryBm, style: text.titleLarge),
          for (final d in Door.values)
            item(QimenTerms.door(d, L10n.language), _m?.lookup('bm', d.zh)?.split(RegExp(r'\s*[｜|]\s*')).join('\n'), color: qm.luck(d.luck), raw: true),
          const Divider(height: 28),
          Text(l.glossaryWx, style: text.titleLarge),
          const SizedBox(height: 4),
          Text(l.glossaryWxNote, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          for (final k in wuXingKeys) item(k, _m?.lookup('wx', k)),
          const Divider(height: 28),
          Text(l.glossaryCs, style: text.titleLarge),
          const SizedBox(height: 4),
          Text(l.glossaryCsNote, style: text.bodySmall?.copyWith(color: qm.textMuted)),
          for (final c in ChangSheng.values) item(c.zh, _m?.lookup('cs', c.zh), color: c.strong ? qm.good : qm.textMuted),
          const Divider(height: 28),
          Text(l.glossarySs, style: text.titleLarge),
          for (final k in shenShaKeys) item(k, _m?.lookup('ss', k)),
        ]),
      ),
    );
  }
}
