import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/l10n.dart';
import '../services/notifications.dart';
import '../shared/widgets/update_prompt.dart';
import 'main_shell.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';

class QimenApp extends StatelessWidget {
  const QimenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: Notifications.navigatorKey,
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: AppTheme.of(Brightness.light),
        darkTheme: AppTheme.of(Brightness.dark),
        themeMode: AppSettings.instance.themeMode,
        supportedLocales: [for (final l in AppLanguages.enabled) l.locale],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeListResolutionCallback: (locales, supported) {
          final lang = AppLanguages.resolve(locales ?? const []);
          L10n.language = lang;
          return lang.locale;
        },
        home: const UpdatePrompt(child: MainShell()),
      ),
    );
  }
}
