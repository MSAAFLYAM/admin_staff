import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/shell_screen.dart';
import 'localization/app_localizations_x.dart';

/// جذر التطبيق: Theme + Localization + الاتجاه (RTL/LTR).
class AdminStaffApp extends ConsumerWidget {
  const AdminStaffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // لغة التطبيق — تُدار من خلال settings لاحقاً.
    final Locale locale = ref.watch(appLocaleProvider);

    return MaterialApp(
      title: 'ADMIN STAFF',
      debugShowCheckedModeBanner: false,

      // ── Theme (Dark Administrative UI) ──────────────────────
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      // ── Localization (Rule 4) ───────────────────────────────
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // RTL تلقائي للعربية، LTR للفرنسية.
      builder: (context, child) => Directionality(
        textDirection: locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),

      home: const ShellScreen(),
    );
  }
}

/// مزوّد لغة التطبيق (يُستبدل لاحقاً بقراءة من `settings`).
final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(
  AppLocaleNotifier.new,
);

class AppLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('ar');

  Future<void> setLocale(String code) async {
    state = Locale(code);
  }
}
