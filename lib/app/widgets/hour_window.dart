import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// 時段（鐘面小時 [from]–[to]，to 可到 24）。0–24＝全天。
class HourWindow {
  const HourWindow(this.from, this.to);

  final int from, to;

  static const day = HourWindow(7, 21);
  static const allDay = HourWindow(0, 24);

  bool get isAllDay => from <= 0 && to >= 24;

  /// 夜間（22–6 點）時辰：推播標示用。
  static bool isNight(int hour) => hour >= 22 || hour < 6;

  String label(AppLocalizations l) => isAllDay ? l.hoursAllDay : l.hoursRange(from, to);

  static HourWindow read(int? from, int? to, {HourWindow fallback = day}) {
    if (from == null || to == null || from < 0 || to > 24 || to - from < 2) return fallback;
    return HourWindow(from, to);
  }
}

/// 時段選擇：滑桿選起訖，或一鍵全天。
class HourWindowPicker extends StatelessWidget {
  const HourWindowPicker({super.key, required this.value, required this.onChanged});

  final HourWindow value;
  final ValueChanged<HourWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${l.hoursWindow}：${value.label(l)}'),
        const Spacer(),
        FilterChip(
          label: Text(l.hoursAllDay),
          selected: value.isAllDay,
          onSelected: (v) => onChanged(v ? HourWindow.allDay : HourWindow.day),
        ),
      ]),
      RangeSlider(
        values: RangeValues(value.from.toDouble(), value.to.toDouble()),
        min: 0,
        max: 24,
        divisions: 24,
        labels: RangeLabels('${value.from}:00', '${value.to}:00'),
        onChanged: (r) {
          final f = r.start.round(), t = r.end.round();
          if (t - f >= 2) onChanged(HourWindow(f, t));
        },
      ),
    ]);
  }
}
