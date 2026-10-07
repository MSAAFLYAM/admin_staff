import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/ui_kit.dart';
import '../../services/security_service.dart';

/// بوابة القفل: تعبر بلا شاشة إذا كان الرمز معطّلاً، وإلا تطلب
/// الرمز أو البصمة، وتعيد القفل تلقائياً حسب إعدادات المستخدم.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool? _checking;
  bool _biometricTried = false;
  DateTime _backgroundedAt = DateTime.now();
  Duration _autoLock = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    final SecurityService security = ref.read(securityServiceProvider);
    final bool enabled = await security.isPinEnabled();
    final Duration autoLock =
        enabled ? await security.autoLockDuration() : Duration.zero;
    if (!mounted) return;
    setState(() {
      _checking = enabled;
      _autoLock = autoLock;
    });
    if (enabled) await _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_biometricTried || !mounted) return;
    _biometricTried = true;
    final SecurityService security = ref.read(securityServiceProvider);
    if (!await security.isBiometricEnabled()) return;
    if (!await security.isBiometricAvailable()) return;
    if (!mounted) return;
    final AppLocalizations l10n = context.l10n;
    final bool ok = await security.authenticateBiometric(
      reason: l10n.unlockWithBiometric,
    );
    if (ok && mounted) setState(() => _checking = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed &&
        _checking == false &&
        _autoLock > Duration.zero &&
        DateTime.now().difference(_backgroundedAt) >= _autoLock) {
      setState(() {
        _checking = true;
        _biometricTried = false;
      });
      _tryBiometric();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool? checking = _checking;
    if (checking == null) return const LoadingView();
    if (!checking) return widget.child;
    return _LockScreen(
      onUnlocked: () {
        setState(() => _checking = false);
      },
      canUseBiometric: _biometricTried == false,
      tryBiometric: _tryBiometric,
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({
    required this.onUnlocked,
    required this.canUseBiometric,
    required this.tryBiometric,
  });

  final VoidCallback onUnlocked;
  final bool canUseBiometric;
  final Future<void> Function() tryBiometric;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  final TextEditingController _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    final bool ok = await ref
        .read(securityServiceProvider)
        .verifyPin(_pin.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = l10n.wrongPin;
        _pin.clear();
      }
    });
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(Icons.lock_outline,
                    size: 48, color: AppColors.neon),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.lockedTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.unlockWithPin,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _pin,
                  obscureText: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.unlock,
                    errorText: _error,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _unlock,
                  child: Text(l10n.unlock),
                ),
                if (widget.canUseBiometric) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  TextButton.icon(
                    onPressed: widget.tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l10n.unlockWithBiometric),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.forgotPinHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
