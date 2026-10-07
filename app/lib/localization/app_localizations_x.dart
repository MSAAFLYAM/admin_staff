import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart' show AppLocalizations;

/// امتداد راحة للوصول إلى الترجمات من أي `BuildContext`.
///
/// الاستخدام:
/// ```dart
/// Text(context.l10n.totalEmployees)
/// ```
extension AppLocalizationsX on BuildContext {
  /// ترجمات التطبيق للغة الحالية.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// قائمة اللغات المدعومة (قاعدة 4).
enum AppLocale {
  ar('ar', 'العربية'),
  fr('fr', 'Français');

  const AppLocale(this.code, this.label);

  final String code;
  final String label;

  /// يحوّل كود لغة مخزّن في `settings` إلى [AppLocale].
  static AppLocale fromCode(String? code) => AppLocale.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLocale.ar,
      );
}

/// جميع locales التي يولّدها gen-l10n.
List<Locale> get supportedAppLocales => AppLocalizations.supportedLocales;
