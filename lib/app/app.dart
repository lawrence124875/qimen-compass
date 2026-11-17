import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/l10n.dart';
import 'home_page.dart';

class QimenApp extends StatelessWidget {
  const QimenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8B5A2B), useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF8B5A2B), brightness: Brightness.dark, useMaterial3: true),
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
      home: const HomePage(),
    );
  }
}
