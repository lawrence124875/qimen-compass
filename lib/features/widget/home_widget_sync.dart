import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../app/settings/app_settings.dart';
import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../travel/travel_text.dart';

/// 桌面小工具（HANDOFF §12 P7）：預先算好 7 天每個時辰的「此刻吉門方位」交給原生小工具，
/// 原生端（android_extra/kotlin/QimenWidgetProvider.kt）每 30 分鐘依時間挑選，不需 App 在背景執行。
class QimenHomeWidget {
  QimenHomeWidget._();

  static const androidName = 'com.lclab.qimen_compass.QimenWidgetProvider';

  /// 開 App 時呼叫（失敗不影響 App）。
  static Future<void> sync(AppLocalizations l) async {
    try {
      final s = AppSettings.instance;
      final now = DateTime.now();
      final lang = L10n.language;
      final slots = const ChuXingPlanner()
          .plan(now, TravelEvent.general, settings: s.timeSettingsAt(now), method: s.juMethod, count: 7 * 12);
      final list = [
        for (final x in slots)
          {
            's': x.startUtc.millisecondsSinceEpoch,
            'e': x.endUtc.millisecondsSinceEpoch,
            'a': l.widgetLine(TravelText.direction(l, x.palace), QimenTerms.doorName(x.door, lang)),
            'b': '${TravelText.level(l, x.level)}${l.separator}${TravelText.timeRange(x)}',
          },
      ];
      await HomeWidget.saveWidgetData<String>('qm_widget_slots', jsonEncode(list));
      await HomeWidget.saveWidgetData<String>('qm_widget_title', l.widgetTitle);
      await HomeWidget.saveWidgetData<String>('qm_widget_empty', l.widgetOpenApp);
      await HomeWidget.updateWidget(qualifiedAndroidName: androidName);
    } catch (_) {}
  }
}
