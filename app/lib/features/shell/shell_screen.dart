import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../app.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/ui_kit.dart';
import '../dashboard/dashboard_screen.dart';
import '../employees/employees_screen.dart';
import '../leaves/leaves_screen.dart';
import '../lock/lock_gate.dart';
import '../permanence/permanence_screen.dart';
import '../settings/settings_screen.dart';

/// الهيكل الرئيسي مع التنقل السفلي (قاعدة 6).
///
/// 1. ينتظر جاهزية القاعدة (تحميل/خطأ بزر إعادة محاولة).
/// 2. يمرّر الواجهة عبر [LockGate] (رمز الدخول/البصمة).
/// 3. يستخدم `IndexedStack` لحفظ حالة كل وجهة (قاعدة 68).
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(appDatabaseProvider).when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (Object e, StackTrace _) => Scaffold(
            body: ErrorView(error: e),
          ),
          data: (_) => const LockGate(child: _ShellBody()),
        );
  }
}

class _ShellBody extends ConsumerStatefulWidget {
  const _ShellBody();

  @override
  ConsumerState<_ShellBody> createState() => _ShellBodyState();
}

class _ShellBodyState extends ConsumerState<_ShellBody> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _syncLocale();
  }

  /// اللغة المحفوظة في القاعدة هي المرجع عند كل تشغيل.
  Future<void> _syncLocale() async {
    try {
      final String code = await ref.read(settingsRepositoryProvider).locale();
      final Locale current = ref.read(appLocaleProvider);
      if (current.languageCode != code) {
        await ref.read(appLocaleProvider.notifier).setLocale(code);
      }
    } catch (_) {
      // فشل القراءة لا يمنع تشغيل التطبيق — الافتراضي عربي.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          DashboardScreen(),
          EmployeesScreen(),
          PermanenceScreen(),
          LeavesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l10n.navEmployees,
          ),
          NavigationDestination(
            icon: const Icon(Icons.schedule_outlined),
            selectedIcon: const Icon(Icons.schedule),
            label: l10n.navPermanence,
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_available_outlined),
            selectedIcon: const Icon(Icons.event_available),
            label: l10n.navLeaves,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
