import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../app/settings/app_settings.dart';
import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../travel/travel_text.dart';

/// Wear OS 手錶羅盤（HANDOFF §12 1.3.0）：手機預先算好 3 天每個時辰八宮的門與吉凶，經 Wearable Data Layer
/// （原生 `android_extra/kotlin/MainActivity.kt`，頻道 `qm/wear`）送到手錶；手錶只依時間挑選、配合指南針顯示，
/// 轉到吉方會震動（手錶端在 `android_extra/wear/`）。只有 Android；iOS、沒有 Play 服務時什麼都不做。
class WearSync {
  WearSync._();

  static const _channel = MethodChannel('qm/wear');

  /// 八宮順序（與手錶端一致）：北、東北、東、東南、南、西南、西、西北。
  static const order = [1, 8, 3, 4, 9, 2, 7, 6];

  /// 送出資料；回傳已連線的手錶數（-1＝失敗或不支援）。[locked]＝手錶羅盤需訂閱而使用者沒訂閱。
  static Future<int> sync(AppLocalizations l, {required bool locked}) async {
    if (!Platform.isAndroid) return -1;
    try {
      final data = jsonEncode(build(l, DateTime.now(), locked: locked));
      return await _channel.invokeMethod<int>('sync', {'data': data}) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// 手錶資料（純資料，測試用）。
  static Map<String, Object?> build(AppLocalizations l, DateTime now, {required bool locked, int hours = 36}) {
    final s = AppSettings.instance;
    final lang = L10n.language;
    const engine = ShiJiaEngine();
    const planner = ChuXingPlanner();
    final travel = planner.plan(now, TravelEvent.general, settings: s.timeSettingsAt(now), method: s.juMethod, count: hours);
    final slots = <Map<String, Object?>>[];
    if (!locked) {
      for (final t in travel) {
        final mid = t.startUtc.add(const Duration(hours: 1));
        final chart = engine.compute(mid, settings: s.timeSettingsAt(mid), method: s.juMethod);
        final p = <List<int>>[];
        for (final palace in order) {
          final v = DirectionPlanner.judge(chart, palace);
          p.add([chart[palace].door?.index ?? -1, v.recommended ? 1 : (v.score >= 3 ? 0 : -1)]);
        }
        slots.add({
          's': t.startUtc.millisecondsSinceEpoch,
          'e': t.endUtc.millisecondsSinceEpoch,
          'p': p,
          'b': t.recommended ? order.indexOf(t.palace) : -1,
          'r': TravelText.timeRange(t),
        });
      }
    }
    return {
      'v': 1,
      'locked': locked,
      'str': {
        'title': l.wearTitle,
        'front': l.wearFront,
        'open': l.wearOpenPhone,
        'locked': l.wearLocked,
        'calib': l.wearCalib,
        'good': l.luckGood,
        'neutral': l.luckNeutral,
        'bad': l.luckBad,
      },
      'doors': [for (final d in Door.values) QimenTerms.doorName(d, lang)],
      'dirs': [for (final p in order) TravelText.direction(l, p)],
      'slots': slots,
    };
  }
}
