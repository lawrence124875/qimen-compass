import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../engine/engine.dart' hide Element;
import '../../l10n/l10n.dart';
import '../settings/app_settings.dart';
import '../settings/solar_city_picker.dart';
import '../theme/app_theme.dart';
import '../../features/feedback/feedback_page.dart';
import '../../features/records/record_actions.dart';
import '../../features/reminders/daily_reminder.dart';
import '../../features/share/share.dart';
import '../../features/travel/travel_notify_options.dart';
import '../../features/travel/travel_reminders.dart';
import '../../shared/premium/ad_banner.dart';
import '../../shared/premium/paywall_page.dart';
import '../links.dart';
import '../services.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = AppSettings.instance;
    final lang = L10n.language.code;
    final sv = AppServices.of(context);
    final usage = sv.usage;
    final qm = context.qm;
    Widget header(String t) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.qm.primary)),
        );
    Widget sub(String t) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(t, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.qm.textMuted)),
        );
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t, style: Theme.of(context).textTheme.bodyMedium),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      bottomNavigationBar: const AdBanner(),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            header(l.settingsAppearance),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(l.appearanceSystem)),
                ButtonSegment(value: ThemeMode.light, label: Text(l.appearanceLight)),
                ButtonSegment(value: ThemeMode.dark, label: Text(l.appearanceDark)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.themeMode = v.first,
            ),
            header(l.settingsChart),
            label(l.settingsJuMethod),
            SegmentedButton<JuMethod>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: JuMethod.chaiBu, label: Text(l.juChaiBu)),
                ButtonSegment(value: JuMethod.zhiRun, label: Text(l.juZhiRun)),
              ],
              selected: {s.juMethod},
              onSelectionChanged: (v) => s.juMethod = v.first,
            ),
            sub(s.juMethod == JuMethod.chaiBu ? l.juChaiBuHint : l.juZhiRunHint),
            label(l.settingsZiHour),
            SegmentedButton<ZiHourMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ZiHourMode.nextDay, label: Text(l.ziNextDay)),
                ButtonSegment(value: ZiHourMode.lateZi, label: Text(l.ziLate)),
              ],
              selected: {s.ziHour},
              onSelectionChanged: (v) => s.ziHour = v.first,
            ),
            sub(s.ziHour == ZiHourMode.nextDay ? l.ziNextDayHint : l.ziLateHint),
            label(l.settingsSolarTime),
            OutlinedButton(
              style: OutlinedButton.styleFrom(alignment: AlignmentDirectional.centerStart, padding: const EdgeInsets.all(14)),
              onPressed: () => showSolarCityPicker(context),
              child: Row(children: [
                Icon(s.solarCityIndex == AppSettings.solarGps ? Icons.my_location : Icons.location_city, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(solarLabel(l, s, lang))),
                const Icon(Icons.search, size: 18),
              ]),
            ),
            sub(l.solarTimeHint),
            header(l.settingsGeneral),
              ValueListenableBuilder<bool>(
                valueListenable: sv.premium.isPremium,
                builder: (context, premium, _) => premium
                    ? const SizedBox.shrink()
                    : ListTile(
                        leading: Icon(Icons.workspace_premium_outlined, color: qm.primary),
                        title: Text(l.menuPremium),
                        onTap: () => openPaywall(context, source: 'menu'),
                      ),
              ),
              ListTile(
                leading: Icon(Icons.phonelink_setup_outlined, color: qm.primary),
                title: Text(l.menuBackupMove),
                subtitle: Text(l.menuBackupMoveHint),
                onTap: () => _backupSheet(context),
              ),
              ListTile(
                leading: Icon(Icons.ios_share, color: qm.primary),
                title: Text(l.menuShareApp),
                onTap: () => shareApp(context),
              ),
              if (sv.feedback != null)
                ListTile(
                  leading: Icon(Icons.mail_outline, color: qm.primary),
                  title: Text(l.menuFeedback),
                  onTap: () => openFeedback(context),
                ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.notifications_none, color: qm.primary),
                title: Text(l.dailyReminder),
                subtitle: Text(l.dailyReminderHint),
                onTap: () => showDailyReminderDialog(context),
              ),
              const _TravelNotifyTile(),
              if (usage != null)
                ValueListenableBuilder<bool>(
                  valueListenable: usage.enabled,
                  builder: (context, on, _) => SwitchListTile(
                    secondary: Icon(Icons.insights_outlined, color: qm.primary),
                    title: Text(l.menuShareUsage),
                    value: on,
                    onChanged: (v) => usage.set(v),
                  ),
                ),
              if (sv.ads.privacyOptionsRequired && !sv.isPremium)
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: qm.primary),
                  title: Text(l.menuAdPrivacy),
                  onTap: () => sv.ads.showPrivacyOptions(),
                ),
              ListTile(
                leading: Icon(Icons.policy_outlined, color: qm.primary),
                title: Text(l.menuPrivacyPolicy),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
              ),
              ListTile(
                leading: Icon(Icons.description_outlined, color: qm.primary),
                title: Text(l.termsOfUse),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(Uri.parse(termsOfServiceUrl), mode: LaunchMode.externalApplication),
              ),
              header(l.otherAppsTitle),
              _OtherAppTile(app: otherAppQiangua, name: l.otherAppQianguaName, desc: l.otherAppQianguaDesc),
              _OtherAppTile(app: otherAppTarot, name: l.otherAppTarotName, desc: l.otherAppTarotDesc),
          ],
        ),
      ),
    );
  }
}
/// 吉時推播開關＋設定（提前時間、時段、每天則數）。
class _TravelNotifyTile extends StatefulWidget {
  const _TravelNotifyTile();

  @override
  State<_TravelNotifyTile> createState() => _TravelNotifyTileState();
}

class _TravelNotifyTileState extends State<_TravelNotifyTile> {
  TravelPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    TravelPrefs.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _prefs;
    final on = p?.notify ?? true;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SwitchListTile(
        secondary: Icon(Icons.schedule, color: context.qm.primary),
        title: Text(l.travelNotifySetting),
        subtitle: p == null ? null : Text(_summary(l, p)),
        value: on,
        onChanged: p == null
            ? null
            : (v) async {
                await p.setNotify(v);
                setState(() {});
                await TravelReminders.reschedule();
              },
      ),
      if (p != null && on)
        ListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 72, end: 16),
          title: Text(l.travelNotifyOptions),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openOptions(p),
        ),
    ]);
  }

  String _summary(AppLocalizations l, TravelPrefs p) => travelNotifySummary(l, p);

  Future<void> _openOptions(TravelPrefs p) => showTravelNotifyOptions(context, p, onChanged: () {
        if (mounted) setState(() {});
      });
}

void _backupSheet(BuildContext context) {
  final l = context.l10n;
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: Text(l.recordBackup),
          onTap: () {
            Navigator.pop(sheet);
            RecordBackupActions.backup(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(l.recordRestore),
          onTap: () {
            Navigator.pop(sheet);
            RecordBackupActions.restore(context);
          },
        ),
      ]),
    ),
  );
}

class _OtherAppTile extends StatelessWidget {
  const _OtherAppTile({required this.app, required this.name, required this.desc});

  final OtherApp app;
  final String name;
  final String desc;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(app.icon,
              width: 44, height: 44, errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44, child: Icon(Icons.apps))),
        ),
        title: Text(name),
        subtitle: Text(desc),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => launchUrl(Uri.parse(app.url), mode: LaunchMode.externalApplication),
      );
}
