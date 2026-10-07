import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:local_auth/local_auth.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';
import '../repositories/audit_repository.dart';
import '../repositories/settings_repository.dart';

/// واجهة المصادقة البيومترية — منفصلة عن المنصّة **ليُختبَر بلا
/// موبايل** (يحقن التطبيق اختباراً وهمياً بدل استدعاء قناة منصّة).
abstract class BiometricAuth {
  /// هل يدعم الجهاز البصمة أصلاً (العتاد + نظام)?
  Future<bool> isDeviceSupported();

  /// هل هناك بصمة مسجّلة فعلاً (لا حساب خاطئ)؟
  Future<bool> canCheckBiometrics();

  /// يعيد `true` إذا نجح التعرّف. السبب [localizedReason] يمرّر من
  /// الواجهة بترجمتها (لا نصّ مُضمَّن هنا — قاعدة التوطين).
  Future<bool> authenticate({required String localizedReason});
}

/// التنفيذ الحقيقي عبر `local_auth` — أي خطأ منصّة يُقرأ `false`
/// لا استثناء يصل إلى المستخدم (قاعدة 49).
class LocalAuthBiometric implements BiometricAuth {
  LocalAuthBiometric() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }
}

/// ★ خدمة الأمان — رمز الدخول، البصمة، والقفل التلقائي (D-012).
///
/// **الرمز مُجزَّأ لا مخزَّن:** PBKDF2-HMAC-SHA256 بـ 120 ألف
/// تكرار وملحّ عشوائي 16 بايت لكل عملية تغيير، والمخرَّج يُكتب
/// base64 في `settings`. لا رمز ولا مفتاح يظهر في الكود أو في
/// سجل التدقيق أو في رسالة خطأ.
///
/// **لا استثناء خام عند التحقّق:** إدخال غير صالح يعيد `false`
/// (المستخدم يعيد المحاولة) أمّا `setPin` فيرفض برسالة عربية
/// قبل أي كتابة.
///
/// القفل التلقائي يخزَّن «معطّل» في مفتاح مستقل — لأن
/// `auto_lock_minutes = 0` تُعامَل قاعدة الإعدادات كقيمة غير
/// منطقية لا كإطفاء.
class SecurityService {
  SecurityService(
    this._database, {
    BiometricAuth? biometric,
    AuditRepository? audit,
  })  : _biometric = biometric ?? LocalAuthBiometric(),
        _audit = audit ?? AuditRepository(_database);

  final AppDatabase _database;
  final BiometricAuth _biometric;
  final AuditRepository _audit;

  late final SettingsRepository _settings = SettingsRepository(_database);

  // ── الثوابت (لا أرقام مُثبَّتة في الواجهة) ──────────────────

  /// تكرارات PBKDF2 — نفس قيمة PIN في D-012.
  static const int kdfIterations = 120000;

  /// طول الملحّ بالبايت.
  static const int saltBytes = 16;

  static const int minPinLength = 4;
  static const int maxPinLength = 6;

  /// خيارات الواجهة للقفل التلقائي (تظهر بترجمتها من ARB).
  static const Set<int> autoLockOptions = <int>{1, 5, 15};

  // ── رمز الدخول ──────────────────────────────────────────────

  Future<bool> isPinEnabled() => _settings.pinEnabled();

  /// صالح للاستعمال في الواجهة (تمكين زر الحفظ) — **لا يكتب شيئاً**.
  static bool isValidPin(String pin) {
    final String p = pin.trim();
    if (p.length < minPinLength || p.length > maxPinLength) return false;
    return RegExp(r'^[0-9]+$').hasMatch(p);
  }

  /// ينشئ الرمز أو يغيّره — كتابة ذرّية واحدة ثم قيد تدقيق.
  Future<void> setPin(String pin) async {
    final String clean = pin.trim();
    _validatePin(clean);

    final bool existed = await _settings.pinEnabled();
    final ({String hash, String salt}) h = await hashPin(clean);

    await _settings.writeMany(<String, String>{
      Db.keyPinHash: h.hash,
      Db.keyPinSalt: h.salt,
      Db.keyPinEnabled: '1',
    });
    await _audit.logSecurity(
      existed ? 'تغيير رمز الدخول' : 'إنشاء رمز الدخول',
    );
  }

  /// التحقّق — **لا يرمي أبداً**: غير مفعّل، مفقود، أو إدخال
  /// غير صالح كلّها `false`.
  Future<bool> verifyPin(String pin) async {
    if (!await _settings.pinEnabled()) return false;

    final String? storedHash = await _settings.read(Db.keyPinHash);
    final String? storedSalt = await _settings.read(Db.keyPinSalt);
    if (storedHash == null || storedSalt == null) return false;

    final String clean = pin.trim();
    if (!isValidPin(clean)) return false;

    final ({String hash, String salt}) h =
        await hashPin(clean, saltBase64: storedSalt);
    if (_constantTimeEquals(h.hash, storedHash)) return true;

    await _audit.logSecurity('محاولة دخول برمز غير صحيح');
    return false;
  }

  /// إلغاء الرمز — يُطفئ أولاً حتى تتعطّل القراءة فوراً.
  Future<void> clearPin() async {
    await _settings.setPinEnabled(false);
    await _settings.clearPinSecrets();
    await _audit.logSecurity('إلغاء رمز الدخول');
  }

  /// مشتق المفتاح (static ليُختبَر بلا قاعدة وليبقى قابلاً
  /// لإعادة استعماله في أي طبقة أخرى).
  static Future<({String hash, String salt})> hashPin(
    String pin, {
    String? saltBase64,
  }) async {
    final List<int> salt =
        saltBase64 == null ? _randomSalt() : base64Decode(saltBase64);

    final SecretKey key = await Pbkdf2.hmacSha256(
      iterations: kdfIterations,
      bits: 256,
    ).deriveKeyFromPassword(password: pin, nonce: salt);

    final List<int> bytes = await key.extractBytes();
    return (hash: base64Encode(bytes), salt: base64Encode(salt));
  }

  static void _validatePin(String pin) {
    if (pin.length < minPinLength) {
      throw AppException(
        'يجب أن يتكون رمز الدخول من $minPinLength أرقام على الأقل.',
      );
    }
    if (pin.length > maxPinLength) {
      throw AppException(
        'يجب ألا يتجاوز رمز الدخول $maxPinLength أرقام.',
      );
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      throw const AppException('رمز الدخول أرقام فقط — لا حروف ولا رموز.');
    }
  }

  static final Random _rnd = Random.secure();

  static List<int> _randomSalt() => List<int>.generate(
        saltBytes,
        (_) => _rnd.nextInt(256),
      );

  /// مقارنة بزمن ثابت — لا تسرّب طول المخرَّج في التوقيت.
  static bool _constantTimeEquals(String a, String b) {
    final List<int> x = base64Decode(a);
    final List<int> y = base64Decode(b);
    final int len = x.length > y.length ? x.length : y.length;
    int diff = x.length ^ y.length;
    for (int i = 0; i < len; i++) {
      diff |= (i < x.length ? x[i] : 0) ^ (i < y.length ? y[i] : 0);
    }
    return diff == 0;
  }

  // ── البصمة ──────────────────────────────────────────────────

  Future<bool> isBiometricAvailable() async {
    try {
      return await _biometric.isDeviceSupported() &&
          await _biometric.canCheckBiometrics();
    } on Exception {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() => _settings.biometricEnabled();

  /// التفعيل يتطلب جهازاً فعلاً يدعم البصمة مسجّلة.
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled && !await isBiometricAvailable()) {
      throw const AppException('البصمة غير متاحة على هذا الجهاز');
    }
    await _settings.setBiometricEnabled(enabled);
    await _audit.logSecurity(
      enabled ? 'تفعيل البصمة' : 'تعطيل البصمة',
    );
  }

  /// لا شيء يحدث إلا إذا كانت البصمة مفعّلة ومتوفرة؛ أي فشل من
  /// المنصّة يعود `false` لا استثناء.
  Future<bool> authenticateBiometric({required String reason}) async {
    if (!await _settings.biometricEnabled()) return false;
    if (!await isBiometricAvailable()) return false;
    try {
      return await _biometric.authenticate(localizedReason: reason);
    } on Exception {
      return false;
    }
  }

  // ── القفل التلقائي ──────────────────────────────────────────

  Future<bool> isAutoLockEnabled() => _settings.autoLockEnabled();

  Future<int> autoLockMinutes() => _settings.autoLockMinutes();

  /// مدة القفل — `Duration.zero` تعني **لا قفل تلقائي إطلاقاً**.
  Future<Duration> autoLockDuration() async {
    if (!await isAutoLockEnabled()) return Duration.zero;
    return Duration(minutes: await autoLockMinutes());
  }

  Future<void> setAutoLockEnabled(bool on) async {
    await _settings.setAutoLockEnabled(on);
    await _audit.logSecurity(
      on ? 'تفعيل القفل التلقائي' : 'تعطيل القفل التلقائي',
    );
  }

  /// الاختيار من {1, 5, 15} وحدها، **وإعادة تفعيل** القفل إن كان
  /// معطّلاً (اختيار زمن بلا معنى إن لم يكن مفعّلاً).
  Future<void> setAutoLockMinutes(int minutes) async {
    if (!autoLockOptions.contains(minutes)) {
      throw const AppException(
        'زمن القفل التلقائي يجب أن يكون دقيقة واحدة أو 5 أو 15 دقيقة.',
      );
    }
    await _settings.writeMany(<String, String>{
      Db.keyAutoLockMinutes: '$minutes',
      Db.keyAutoLockEnabled: '1',
    });
    await _audit.logSecurity('تغيير زمن القفل التلقائي إلى $minutes دقيقة');
  }
}
