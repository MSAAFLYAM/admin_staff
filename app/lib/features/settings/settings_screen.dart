import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../app.dart';
import '../../core/constants/db_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/query/search_query.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_date.dart';
import '../../core/utils/csv/csv_writer.dart';
import '../../core/widgets/ui_kit.dart';
import '../../models/employee.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../services/security_service.dart';
import 'references_screen.dart';

/// الإعدادات: اللغة، الأمان، البيانات، المراجع، النسخ الاحتياطي، حول.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _locale = 'ar';
  bool _pinEnabled = false;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  bool _autoLock = false;
  int _autoLockMinutes = 5;
  bool _notifications = true;
  bool _ready = false;

  /// إصدار التطبيق (نفس `pubspec.yaml`).
  static const String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SettingsRepository settings = ref.read(settingsRepositoryProvider);
    final SecurityService security = ref.read(securityServiceProvider);
    final List<Object> data = await Future.wait<Object>(<Future<Object>>[
      settings.locale(),
      security.isPinEnabled(),
      security.isBiometricAvailable(),
      security.isBiometricEnabled(),
      security.isAutoLockEnabled(),
      security.autoLockMinutes(),
      settings.notificationsEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      _locale = data[0] as String;
      _pinEnabled = data[1] as bool;
      _bioAvailable = data[2] as bool;
      _bioEnabled = data[3] as bool;
      _autoLock = data[4] as bool;
      _autoLockMinutes = data[5] as int;
      _notifications = data[6] as bool;
      _ready = true;
    });
  }

  // ── اللغة ────────────────────────────────────────────────────

  Future<void> _setLocale(String code) async {
    await ref.read(settingsRepositoryProvider).setLocale(code);
    await ref.read(appLocaleProvider.notifier).setLocale(code);
    if (mounted) setState(() => _locale = code);
  }

  // ── رمز الدخول ──────────────────────────────────────────────

  Future<void> _pinDialog({required bool change}) async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController pin = TextEditingController();
    final TextEditingController confirm = TextEditingController();
    final GlobalKey<FormState> form = GlobalKey<FormState>();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(change ? l10n.changePin : l10n.createPin),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: pin,
                obscureText: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.createPin),
              ),
              TextFormField(
                controller: confirm,
                obscureText: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.confirmPin),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    if (!SecurityService.isValidPin(pin.text)) {
      showAppSnack(context, l10n.pinTooShort, isError: true);
      return;
    }
    if (pin.text.trim() != confirm.text.trim()) {
      showAppSnack(context, l10n.pinMismatch, isError: true);
      return;
    }
    try {
      await ref.read(securityServiceProvider).setPin(pin.text.trim());
      if (mounted) {
        setState(() => _pinEnabled = true);
        showAppSnack(context, l10n.savedSuccessfully);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, l10n), isError: true);
    }
  }

  Future<void> _disablePin() async {
    final AppLocalizations l10n = context.l10n;
    final bool ok = await confirmAction(
      context,
      title: l10n.disablePin,
      message: l10n.confirmDeleteMessage,
      confirmLabel: l10n.confirm,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(securityServiceProvider).clearPin();
    if (mounted) {
      setState(() => _pinEnabled = false);
      showAppSnack(context, l10n.deletedSuccessfully);
    }
  }

  // ── القياسات/Biometric ──────────────────────────────────────

  Future<void> _toggleBiometric(bool on) async {
    final AppLocalizations l10n = context.l10n;
    if (!on) {
      await ref.read(securityServiceProvider).setBiometricEnabled(false);
      if (mounted) setState(() => _bioEnabled = false);
      return;
    }
    final bool ok = await ref
        .read(securityServiceProvider)
        .authenticateBiometric(reason: l10n.biometricEnable);
    if (!ok) {
      if (mounted) setState(() => _bioEnabled = false);
      return;
    }
    await ref.read(securityServiceProvider).setBiometricEnabled(true);
    if (mounted) setState(() => _bioEnabled = true);
  }

  // ── تصدير CSV ───────────────────────────────────────────────

  Future<void> _exportCsv() async {
    final AppLocalizations l10n = context.l10n;
    final String? dir = await FilePicker.getDirectoryPath();
    if (dir == null || !mounted) return;
    try {
      final EmployeePage page =
          await ref.read(employeeRepositoryProvider).search(
                const SearchQuery(limit: 100000, includeInactive: true),
              );
      final List<Employee> items = page.items;
      final String csv = CsvWriter.build(
        headers: <String>[
          'nom_ar',
          'prenom_ar',
          'nom_fr',
          'prenom_fr',
          'matricule',
          'section',
          'fonction',
          'qualite',
          'grade',
          'ppr',
          'telephone_mobile',
          'statut',
        ],
        rows: <List<Object?>>[
          for (final Employee e in items)
            <Object?>[
              e.nomAr,
              e.prenomAr,
              e.nomFr,
              e.prenomFr,
              e.matricule,
              e.sectionName,
              e.functionName,
              e.quality,
              e.gradeName,
              e.ppr,
              e.mobilePhone,
              e.displayStatus,
            ],
        ],
      );
      final String path =
          '$dir${Platform.pathSeparator}employees_${AppDate.format(AppDate.today())}.csv';
      await File(path).writeAsString(csv, flush: true);
      if (mounted) showAppSnack(context, l10n.exportCsv);
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, l10n), isError: true);
    }
  }

  // ── النسخ الاحتياطي ─────────────────────────────────────────

  Future<String?> _passwordDialog(String title) async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController pass = TextEditingController();
    final TextEditingController pass2 = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: pass,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.createBackup),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: pass2,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.confirmPin),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    if (pass.text != pass2.text) {
      if (mounted) showAppSnack(context, l10n.pinMismatch, isError: true);
      return null;
    }
    if (pass.text.trim().isEmpty) {
      if (mounted) showAppSnack(context, l10n.errFieldRequired, isError: true);
      return null;
    }
    return pass.text;
  }

  Future<void> _backup() async {
    final AppLocalizations l10n = context.l10n;
    final String? password = await _passwordDialog(l10n.createBackup);
    if (password == null || !mounted) return;
    final String? dir = await FilePicker.getDirectoryPath();
    if (dir == null || !mounted) return;
    final String path =
        '$dir${Platform.pathSeparator}ADMIN_STAFF_${AppDate.format(AppDate.today())}.asbk';
    try {
      await ref
          .read(backupServiceProvider)
          .create(password: password, destinationPath: path);
      if (mounted) {
        showAppSnack(context, '${l10n.backupCreated}\n$path');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, l10n), isError: true);
    }
  }

  Future<void> _restore() async {
    final AppLocalizations l10n = context.l10n;
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.any,
    );
    final String? path = files.isEmpty ? null : files.first.path;
    if (path == null || !mounted) return;

    final bool ok = await confirmAction(
      context,
      title: l10n.restoreTitle,
      message: l10n.restoreWarning,
      confirmLabel: l10n.confirm,
      destructive: true,
    );
    if (!ok || !mounted) return;

    final String? password = await _passwordDialog(l10n.restoreBackup);
    if (password == null || !mounted) return;

    try {
      await ref
          .read(backupServiceProvider)
          .restore(sourcePath: path, password: password);
      ref.read(dbRevisionProvider.notifier).bump();
      if (mounted) showAppSnack(context, l10n.restoreSucceeded);
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, l10n), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    if (!_ready) return const LoadingView();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: AppSpacing.page,
        children: <Widget>[
          // ── اللغة ──
          SectionCard(
            title: l10n.sectionLanguage,
            children: <Widget>[
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'ar', label: Text(l10n.languageArabic)),
                  ButtonSegment<String>(value: 'fr', label: Text(l10n.languageFrench)),
                ],
                selected: <String>{_locale},
                onSelectionChanged: (Set<String> s) => _setLocale(s.first),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── الأمان ──
          SectionCard(
            title: l10n.sectionSecurity,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.enablePin),
                value: _pinEnabled,
                onChanged: (bool v) {
                  if (v) {
                    _pinDialog(change: false);
                  } else {
                    _disablePin();
                  }
                },
              ),
              if (_pinEnabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(l10n.changePin),
                  onTap: () => _pinDialog(change: true),
                ),
              if (_bioAvailable)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.biometricEnable),
                  subtitle: _pinEnabled ? null : Text(l10n.unlockWithPin),
                  value: _bioEnabled,
                  onChanged: _pinEnabled
                      ? _toggleBiometric
                      : (_) {
                          showAppSnack(context, l10n.enablePin, isError: true);
                        },
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoLock),
                value: _autoLock,
                onChanged: (bool v) async {
                  await ref
                      .read(securityServiceProvider)
                      .setAutoLockEnabled(v);
                  if (mounted) setState(() => _autoLock = v);
                },
              ),
              if (_autoLock)
                DropdownButtonFormField<int>(
                  initialValue: SecurityService.autoLockOptions
                          .contains(_autoLockMinutes)
                      ? _autoLockMinutes
                      : 5,
                  decoration: InputDecoration(labelText: l10n.autoLock),
                  items: <DropdownMenuItem<int>>[
                    for (final int m in SecurityService.autoLockOptions
                        .toList()
                      ..sort())
                      DropdownMenuItem<int>(
                        value: m,
                        child: Text(switch (m) {
                          1 => l10n.autoLock1m,
                          5 => l10n.autoLock5m,
                          _ => l10n.autoLock15m,
                        }),
                      ),
                  ],
                  onChanged: (int? v) async {
                    if (v == null) return;
                    await ref
                        .read(securityServiceProvider)
                        .setAutoLockMinutes(v);
                    if (mounted) setState(() => _autoLockMinutes = v);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── البيانات ──
          SectionCard(
            title: l10n.sectionData,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.ios_share_outlined),
                title: Text(l10n.exportCsv),
                onTap: _exportCsv,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.notificationsEnable),
                value: _notifications,
                onChanged: (bool v) async {
                  await ref
                      .read(settingsRepositoryProvider)
                      .setNotificationsEnabled(v);
                  if (mounted) setState(() => _notifications = v);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_outlined),
                title: Text(l10n.sectionReferences),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReferencesScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── النسخ الاحتياطي ──
          SectionCard(
            title: l10n.sectionBackup,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.save_outlined),
                title: Text(l10n.createBackup),
                subtitle: Text(l10n.backupEncrypted),
                onTap: _backup,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore_outlined),
                title: Text(l10n.restoreBackup),
                subtitle: Text(l10n.restoreWarning),
                onTap: _restore,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── حول ──
          SectionCard(
            title: l10n.sectionAbout,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text('${l10n.version}: $_appVersion'),
                subtitle: Text('${l10n.schemaVersion}: ${Db.schemaVersion}'),
              ),
              Text(l10n.offlineNote, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
