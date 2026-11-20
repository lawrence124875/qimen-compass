import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../app/services.dart';
import '../../app/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import 'home_widget_sync.dart';

/// 「我的 → 桌面小工具」：設定小、中、大三種尺寸的預設顯示項目（依勾選順序），可一鍵套用到已放的小工具、加到桌面。
/// 個別小工具在 Android 12 以上長按可改（原生 QimenWidgetConfigActivity）。
class WidgetSettingsPage extends StatefulWidget {
  const WidgetSettingsPage({super.key});

  @override
  State<WidgetSettingsPage> createState() => _WidgetSettingsPageState();
}

class _WidgetSettingsPageState extends State<WidgetSettingsPage> {
  Map<WidgetSize, List<WidgetItem>>? _d;
  bool _canPin = false;

  @override
  void initState() {
    super.initState();
    QimenHomeWidget.defaults().then((d) {
      if (mounted) setState(() => _d = {for (final e in d.entries) e.key: [...e.value]});
    });
    HomeWidget.isRequestPinWidgetSupported().then((v) {
      if (mounted) setState(() => _canPin = v ?? false);
    }, onError: (_) {});
  }

  void _toggle(WidgetSize s, WidgetItem i, bool on) {
    final list = _d![s]!;
    setState(() {
      if (on) {
        if (list.length >= s.max) list.removeAt(0);
        list.add(i);
      } else {
        list.remove(i);
      }
    });
    QimenHomeWidget.saveDefaults(_d!);
  }

  String _sizeTitle(AppLocalizations l, WidgetSize s) => switch (s) {
        WidgetSize.small => l.widgetSizeSmall,
        WidgetSize.medium => l.widgetSizeMedium,
        WidgetSize.large => l.widgetSizeLarge,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final qm = context.qm;
    final text = Theme.of(context).textTheme;
    final premium = AppServices.of(context).isPremium;
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(l.widgetSettingsTitle)),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(l.widgetSettingsHint, style: text.bodyMedium?.copyWith(color: qm.textMuted)),
              ),
              for (final s in WidgetSize.values)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ListTile(
                        title: Text(_sizeTitle(l, s), style: text.titleMedium),
                        subtitle: Text(l.widgetPickHint(s.max)),
                        trailing: _canPin
                            ? TextButton.icon(
                                icon: const Icon(Icons.add_to_home_screen, size: 18),
                                label: Text(l.widgetPin),
                                onPressed: () => HomeWidget.requestPinWidget(qualifiedAndroidName: s.androidName),
                              )
                            : null,
                      ),
                      if (s == WidgetSize.large)
                        ListTile(
                          dense: true,
                          leading: Icon(premium ? Icons.grid_view_rounded : Icons.lock_outline, color: qm.primary),
                          title: Text(l.widgetBoard),
                        ),
                      for (final i in WidgetItem.values)
                        CheckboxListTile(
                          dense: true,
                          value: d[s]!.contains(i),
                          onChanged: (v) => _toggle(s, i, v ?? false),
                          title: Text(d[s]!.contains(i) ? '${d[s]!.indexOf(i) + 1}. ${widgetItemName(l, i)}' : widgetItemName(l, i)),
                          secondary: i.premium && !premium ? Icon(Icons.lock_outline, size: 18, color: qm.textMuted) : null,
                        ),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.sync),
                label: Text(l.widgetApplyAll),
                onPressed: () async {
                  await QimenHomeWidget.saveDefaults(d, resetCustom: true);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.widgetApplied)));
                },
              ),
            ]),
    );
  }
}
