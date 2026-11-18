import 'package:flutter/material.dart';

import '../../app/widgets/hour_window.dart';
import '../../l10n/l10n.dart';
import 'travel_reminders.dart';

/// 吉時推播設定（提前幾分鐘、時段或全天、每天則數）。設定頁與出行訣頁共用；關閉時重排推播。
String travelLeadLabel(AppLocalizations l, int m) => m >= 60 ? l.travelLeadHour : l.travelLeadMinutes(m);

String travelNotifySummary(AppLocalizations l, TravelPrefs p) =>
    l.travelNotifySummary(travelLeadLabel(l, p.leadMinutes), p.window.label(l), p.perDay);

Future<void> showTravelNotifyOptions(BuildContext context, TravelPrefs p, {VoidCallback? onChanged}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
      final l = sheet.l10n;
      Future<void> update(Future<void> Function() f) async {
        await f();
        setSheet(() {});
        onChanged?.call();
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.travelNotifyOptions, style: Theme.of(sheet).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(l.travelLead),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final m in TravelPrefs.leadOptions)
                ChoiceChip(
                  label: Text(travelLeadLabel(l, m)),
                  selected: p.leadMinutes == m,
                  onSelected: (_) => update(() => p.setLeadMinutes(m)),
                ),
            ]),
            const SizedBox(height: 12),
            HourWindowPicker(value: p.window, onChanged: (w) => update(() => p.setWindow(w))),
            if (p.window.from < 6 || p.window.to > 22) Text(l.travelNightHint, style: Theme.of(sheet).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(l.travelPerDay),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final n in TravelPrefs.perDayOptions)
                ChoiceChip(label: Text('$n'), selected: p.perDay == n, onSelected: (_) => update(() => p.setPerDay(n))),
            ]),
            const SizedBox(height: 6),
            Text(l.travelPerDayHint, style: Theme.of(sheet).textTheme.bodySmall),
          ]),
        ),
      );
    }),
  );
  await TravelReminders.reschedule();
}
