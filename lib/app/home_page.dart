import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../l10n/l10n.dart';

/// 暫時的首頁：顯示目前時盤摘要。盤面 UI（九宮格）見 HANDOFF §12。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _engine = ShiJiaEngine();
  late QimenChart _chart = _compute();

  QimenChart _compute() {
    final now = DateTime.now();
    return _engine.compute(now, settings: TimeSettings(utcOffset: now.timeZoneOffset));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = L10n.language;
    final c = _chart;
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.homeCurrentChart, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l.homePillars('${c.year}', '${c.month}', '${c.day}', '${c.hour}')),
          Text(l.homeJu(c.dun.zh, c.ju, c.yuan.zh)),
          Text(l.homeZhiFu(QimenTerms.star(c.zhiFu, lang))),
          Text(l.homeZhiShi(QimenTerms.door(c.zhiShi, lang))),
          const SizedBox(height: 16),
          for (final p in const [4, 9, 2, 3, 7, 8, 1, 6])
            Text('${c[p].name}$p  ${c[p].stars.map((s) => s.zh).join('/')}  '
                '${c[p].door?.zh ?? ''}  ${c[p].god?.zh ?? ''}'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => setState(() => _chart = _compute()), child: Text(l.homeRefresh)),
          const SizedBox(height: 16),
          Text(l.homeDisclaimer, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
