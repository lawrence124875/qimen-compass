import 'package:flutter/material.dart';

import '../../features/course/course_page.dart';
import '../../features/house/house_page.dart';
import '../../features/map/move_page.dart';
import '../../features/personal/personal_page.dart';
import '../../features/personal/synastry_page.dart';
import '../../features/records/record_list_page.dart';
import '../../l10n/l10n.dart';
import '../../shared/premium/usage_gate.dart';
import '../services.dart';
import '../theme/app_theme.dart';
import 'settings_page.dart';

/// 「我的」分頁：宅盤、盤記、課程、設定（之後的個人化功能也放這裡）。
class MePage extends StatelessWidget {
  const MePage({super.key});

  /// 開啟訂閱功能：免費版完整體驗一次，之後開訂閱頁（沒訂閱就不開）。
  static Future<void> openPremium(BuildContext context, String feature, WidgetBuilder builder) async {
    final access = await requirePremium(context, feature: feature);
    if (access == PremiumAccess.titleOnly || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  static Future<void> open(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = AppServices.of(context);
    final qm = context.qm;
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap) => Card(
          child: ListTile(
            leading: Icon(icon, color: qm.primary),
            title: Text(title),
            subtitle: Text(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.tabMe)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 16), children: [
          if (s.featureEnabled('personal'))
            tile(Icons.person_pin_circle_outlined, l.personalTitle, l.personalSub,
                () => openPremium(context, 'personal', (_) => const PersonalPage())),
          if (s.featureEnabled('synastry'))
            tile(Icons.people_outline, l.synTitle, l.synSub, () => openPremium(context, 'synastry', (_) => const SynastryPage())),
          if (s.featureEnabled('move'))
            tile(Icons.local_shipping_outlined, l.moveTitle, l.moveSub, () => openPremium(context, 'move', (_) => const MovePage())),
          if (s.featureEnabled('house'))
            tile(Icons.home_work_outlined, l.homeHouse, l.meHouseSub,
                () => openPremium(context, 'house', (_) => const HousePage())),
          if (s.featureEnabled('records'))
            tile(Icons.bookmarks_outlined, l.recordsTitle, l.meRecordsSub, () => open(context, (_) => const RecordListPage())),
          if (s.featureEnabled('course'))
            tile(Icons.school_outlined, l.homeCourse, l.meCourseSub, () => open(context, (_) => const CoursePage())),
          tile(Icons.settings_outlined, l.settingsTitle, l.meSettingsSub, () => open(context, (_) => const SettingsPage())),
        ]),
      ),
    );
  }
}
