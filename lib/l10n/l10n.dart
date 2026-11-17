import 'package:flutter/widgets.dart';

import 'app_languages.dart';
import 'app_localizations.dart';

export 'app_languages.dart';
export 'app_localizations.dart';
export 'terms.dart';

/// 介面翻譯入口：畫面裡用 `context.l10n.xxx`；沒有 BuildContext 時（通知等）用 `L10n.current.xxx`。
class L10n {
  L10n._();

  static AppLanguage? _language;

  static AppLanguage get language =>
      _language ??= AppLanguages.resolve(WidgetsBinding.instance.platformDispatcher.locales);

  static set language(AppLanguage value) => _language = value;

  static AppLocalizations get current => lookupAppLocalizations(language.locale);
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
