import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// 羅盤的記憶設定（北方基準、上次磁偏角、是否看過引導）。
class CompassPrefs {
  CompassPrefs._();

  static const _kTrueNorth = 'qm_compass_true_north';
  static const _kDeclination = 'qm_compass_declination';
  static const _kIntroSeen = 'qm_compass_intro_seen';

  static Future<SharedPreferences?> _p() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<({bool trueNorth, double? declination, bool introSeen})> load() async {
    final p = await _p();
    return (
      trueNorth: p?.getBool(_kTrueNorth) ?? false,
      declination: p?.getDouble(_kDeclination),
      introSeen: p?.getBool(_kIntroSeen) ?? false,
    );
  }

  static Future<void> saveNorth(bool trueNorth, double? declination) async {
    final p = await _p();
    await p?.setBool(_kTrueNorth, trueNorth);
    if (declination != null) await p?.setDouble(_kDeclination, declination);
  }

  static Future<void> markIntroSeen() async => (await _p())?.setBool(_kIntroSeen, true);
}

/// 首次進羅盤的 3 頁引導（比照謙卦）；右上 ⓘ 可重看。
Future<void> showCompassIntro(BuildContext context) {
  final l = context.l10n;
  final pages = [
    (Icons.explore, l.compassIntro1Title, l.compassIntro1Body),
    (Icons.screen_rotation_alt, l.compassIntro2Title, l.compassIntro2Body),
    (Icons.near_me, l.compassIntro3Title, l.compassIntro3Body),
  ];
  final controller = PageController();
  var index = 0;
  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final last = index == pages.length - 1;
        return AlertDialog(
          content: SizedBox(
            width: 320,
            height: 260,
            child: PageView(
              controller: controller,
              onPageChanged: (i) => setState(() => index = i),
              children: [
                for (final p in pages)
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(p.$1, size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(p.$2, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(p.$3, textAlign: TextAlign.center),
                  ]),
              ],
            ),
          ),
          actions: [
            Text('${index + 1} / ${pages.length}'),
            FilledButton(
              onPressed: () => last
                  ? Navigator.of(context).pop()
                  : controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              child: Text(last ? l.compassIntroDone : l.compassIntroNext),
            ),
          ],
        );
      },
    ),
  );
}
