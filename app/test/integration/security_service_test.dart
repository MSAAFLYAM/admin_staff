import 'dart:convert';

import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/models/audit_log_entry.dart';
import 'package:admin_staff/repositories/audit_repository.dart';
import 'package:admin_staff/repositories/settings_repository.dart';
import 'package:admin_staff/services/security_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// مزوّد بصمة وهمي — بلا منصّة ولا قناة، فيُختبَر المنطق كاملاً
/// على سطح المكتب.
class _FakeBiometric implements BiometricAuth {
  bool supported = true;
  bool enrolled = true;
  bool outcome = true;
  bool throwPlatform = false;
  int authenticateCalls = 0;
  String? lastReason;

  void reset() {
    supported = true;
    enrolled = true;
    outcome = true;
    throwPlatform = false;
    authenticateCalls = 0;
    lastReason = null;
  }

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> canCheckBiometrics() async => enrolled;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalls++;
    lastReason = localizedReason;
    if (throwPlatform) {
      throw Exception('channel error');
    }
    return outcome;
  }
}

/// ★ اختبارات خدمة الأمان — رمز الدخول (PBKDF2 120k)، البصمة،
/// القفل التلقائي، وسجل التدقيق (D-012).
///
/// لا يُكتب رمز صريح إلى قاعدة البيانات أبداً، ولا يظهر في سجل
/// التدقيق أو في أي رسالة خطأ.
void main() {
  late Database db;
  late AppDatabase appDb;
  late SecurityService security;
  late SettingsRepository settings;
  late AuditRepository audit;
  late _FakeBiometric bio;

  /// تصفير الحالة قبل كل اختبار — لا اعتماد على ترتيب المجموعات.
  Future<void> resetState() async {
    bio.reset();
    await settings.setPinEnabled(false);
    await settings.clearPinSecrets();
    await settings.setAutoLockEnabled(true);
    await settings.setAutoLockMinutes(5);
    await settings.setBiometricEnabled(false);
    await db.delete(Db.auditLogs);
  }

  /// يلتقط `AppException` العربية ويُفشل الاختبار إن لم تُرمَ
  /// (رمي خطأ هنا يُسجَّل فشلاً في الاختبار).
  Future<AppException> caughtApp(Future<void> future) async {
    try {
      await future;
    } on AppException catch (e) {
      return e;
    } catch (e) {
      throw StateError('كان يُتوقَّع AppException ورمي بدلاً منها: $e');
    }
    throw StateError('لم يُرمَ أي استثناء');
  }

  Future<List<String>> securityLogs() async =>
      (await audit.byAction('security'))
          .map((AuditLogEntry e) => e.description ?? '')
          .toList();

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    appDb = AppDatabase.fromDatabase(db);
    settings = SettingsRepository(appDb);
    audit = AuditRepository(appDb);
    bio = _FakeBiometric();
    security = SecurityService(appDb, biometric: bio);
  });

  setUp(resetState);

  tearDownAll(() async => closeTestDb(db));

  group('A1 الحالة الأولية', () {
    test('لا رمز ولا بصمة بعد الزرع، والتحقّق لا يرمي', () async {
      expect(await security.isPinEnabled(), isFalse);
      expect(await security.verifyPin('1234'), isFalse);
      expect(await settings.read(Db.keyPinHash), isNull);
      expect(await settings.read(Db.keyPinSalt), isNull);
      expect(await security.isBiometricEnabled(), isFalse);
    });

    test('isValidPin يحكم على الشكل بلا كتابة في القاعدة', () {
      expect(SecurityService.isValidPin('1234'), isTrue);
      expect(SecurityService.isValidPin(' 5678 '), isTrue);
      expect(SecurityService.isValidPin('123456'), isTrue);
      expect(SecurityService.isValidPin('123'), isFalse);
      expect(SecurityService.isValidPin('1234567'), isFalse);
      expect(SecurityService.isValidPin('12a4'), isFalse);
      expect(SecurityService.isValidPin(''), isFalse);
      // أرقام عربية-هندية ليست ASCII — الشكل واحد قاعدة واحدة.
      expect(SecurityService.isValidPin('١٢٣٤'), isFalse);
    });
  });

  group('A2 إنشاء الرمز والتحقّق', () {
    test('setPin يخزّن مجزّأة لا الرمز نفسه', () async {
      await security.setPin('1234');

      expect(await security.isPinEnabled(), isTrue);

      final String hash = (await settings.read(Db.keyPinHash)) ?? '';
      expect(hash, isNotEmpty);
      expect(hash, isNot('1234'));
      expect(hash.contains('1234'), isFalse);

      final List<int> salt = base64Decode(
        (await settings.read(Db.keyPinSalt)) ?? '',
      );
      expect(salt, hasLength(SecurityService.saltBytes));

      expect(await security.verifyPin('1234'), isTrue);
      expect(await security.verifyPin('9999'), isFalse);
    });

    test('الملحّ عشوائي — نفس الرمز يعطي مخرجاً مختلفاً', () async {
      await security.setPin('1234');
      final String first = (await settings.read(Db.keyPinHash)) ?? '';

      await security.setPin('1234');
      final String second = (await settings.read(Db.keyPinHash)) ?? '';

      expect(second, isNot(first));
      expect(await security.verifyPin('1234'), isTrue);
    });

    test('الرمز يبقى عبر مثيل جديد من الخدمة', () async {
      await security.setPin('1234');
      final SecurityService fresh = SecurityService(appDb, biometric: bio);
      expect(await fresh.verifyPin('1234'), isTrue);
    });

    test('hashPin ثابتة مع ملحّ معلوم — نفس المدخل نفس المخرج', () async {
      final String salt = base64Encode(List<int>.filled(16, 7));
      final ({String hash, String salt}) a =
          await SecurityService.hashPin('1234', saltBase64: salt);
      final ({String hash, String salt}) b =
          await SecurityService.hashPin('1234', saltBase64: salt);
      final ({String hash, String salt}) c =
          await SecurityService.hashPin('4321', saltBase64: salt);

      expect(a.hash, b.hash);
      expect(a.salt, salt);
      expect(c.hash, isNot(a.hash));
    });
  });

  group('B1 رفض الإدخال', () {
    test('قيم غير صالحة تُرمَي ولا تُكتب أي مفتاح', () async {
      for (final String bad in <String>['123', '1234567', '12a4', '']) {
        final AppException e = await caughtApp(security.setPin(bad));
        expect(e.userMessage, isNotEmpty);
      }

      expect(await security.isPinEnabled(), isFalse);
      expect(await settings.read(Db.keyPinHash), isNull);
      expect(await settings.read(Db.keyPinSalt), isNull);
    });

    test('رسالة الرمز القصير تذكر 4 أرقام', () async {
      final AppException e = await caughtApp(security.setPin('123'));
      expect(e.userMessage, contains('4'));
      expect(e.userMessage, contains('أقل'));
    });

    test('verifyPin بإدخال غير صالح يعود false لا استثناء', () async {
      await security.setPin('1234');
      for (final String bad in <String>['', 'abc', '123', '1234567']) {
        expect(await security.verifyPin(bad), isFalse);
      }
      expect(await security.verifyPin('1234'), isTrue);
    });
  });

  group('C1 التغيير والإلغاء', () {
    test('تغيير الرمز يبطل القديم', () async {
      await security.setPin('1234');
      await security.setPin('5678');

      expect(await security.verifyPin('1234'), isFalse);
      expect(await security.verifyPin('5678'), isTrue);
      expect(await security.isPinEnabled(), isTrue);
    });

    test('clearPin يطفئ ثم يمحو المفاتيح', () async {
      await security.setPin('1234');
      await security.clearPin();

      expect(await security.isPinEnabled(), isFalse);
      expect(await settings.read(Db.keyPinHash), isNull);
      expect(await settings.read(Db.keyPinSalt), isNull);
      expect(await security.verifyPin('1234'), isFalse);
    });

    test('محاولة خاطئة تُدوَّن، والصحيحة لا تضيف فشلاً', () async {
      await security.setPin('1234');
      await db.delete(Db.auditLogs);

      expect(await security.verifyPin('0000'), isFalse);
      final List<String> afterFail = await securityLogs();
      expect(afterFail, hasLength(1));
      expect(afterFail.single, contains('غير صحيح'));

      expect(await security.verifyPin('1234'), isTrue);
      expect(await securityLogs(), hasLength(1));
    });
  });

  group('D1 القفل التلقائي', () {
    test('الافتراضي 5 دقائق ومفعّل', () async {
      expect(await security.isAutoLockEnabled(), isTrue);
      expect(await security.autoLockMinutes(), 5);
      expect(
        await security.autoLockDuration(),
        const Duration(minutes: 5),
      );
    });

    test('الخيارات 1/5/15 وحدها مقبولة', () async {
      await security.setAutoLockMinutes(15);
      expect(await security.autoLockMinutes(), 15);

      await security.setAutoLockMinutes(1);
      expect(await security.autoLockMinutes(), 1);
    });

    test('قيم خارج الخيارات تُرمَي ولا تغيّر المخزَّن', () async {
      await security.setAutoLockMinutes(15);

      for (final int bad in <int>[0, 3, 60, -5]) {
        final AppException e =
            await caughtApp(security.setAutoLockMinutes(bad));
        expect(e.userMessage, contains('القفل التلقائي'));
      }

      expect(await security.autoLockMinutes(), 15);
    });

    test('إطفاء = صفر، واختيار زمن يعيد التفعيل', () async {
      await security.setAutoLockEnabled(false);
      expect(await security.isAutoLockEnabled(), isFalse);
      expect(await security.autoLockDuration(), Duration.zero);

      // اختيار زمن بلا معنى إن لم يكن القفل مفعّلاً.
      await security.setAutoLockMinutes(1);
      expect(await security.isAutoLockEnabled(), isTrue);
      expect(
        await security.autoLockDuration(),
        const Duration(minutes: 1),
      );
    });
  });

  group('E1 البصمة', () {
    test('جهاز بلا بصمة يرفض التفعيل', () async {
      bio.supported = false;

      expect(await security.isBiometricAvailable(), isFalse);
      final AppException e =
          await caughtApp(security.setBiometricEnabled(true));
      expect(e.userMessage, contains('البصمة'));
      expect(await security.isBiometricEnabled(), isFalse);
    });

    test('جهاز بلا بصمة مسجّلة غير متاح', () async {
      bio.enrolled = false;
      expect(await security.isBiometricAvailable(), isFalse);
    });

    test('التفعيل والاستعمال يمرّران سبب الترجمة', () async {
      await security.setBiometricEnabled(true);
      expect(await security.isBiometricEnabled(), isTrue);

      expect(
        await security.authenticateBiometric(reason: 'فتح التطبيق'),
        isTrue,
      );
      expect(bio.authenticateCalls, 1);
      expect(bio.lastReason, 'فتح التطبيق');
    });

    test('غير مفعّل → لا استدعاء للمزوّد إطلاقاً', () async {
      expect(await security.authenticateBiometric(reason: 'سبب'), isFalse);
      expect(bio.authenticateCalls, 0);
    });

    test('إخفاق المنصّة يعود false لا استثناء', () async {
      await security.setBiometricEnabled(true);

      bio.outcome = false;
      expect(await security.authenticateBiometric(reason: 'سبب'), isFalse);

      bio.throwPlatform = true;
      expect(await security.authenticateBiometric(reason: 'سبب'), isFalse);
    });

    test('تعطيل البصمة ممكن وإن كان الجهاز يدعمها', () async {
      await security.setBiometricEnabled(true);
      await security.setBiometricEnabled(false);
      expect(await security.isBiometricEnabled(), isFalse);
    });
  });

  group('F1 سجل التدقيق', () {
    test('كل عملية أمنية تُدوَّن ولا رمز في الأوصاف', () async {
      await security.setPin('1234');
      await security.setPin('5678');
      await security.setBiometricEnabled(true);
      await security.setAutoLockMinutes(15);
      await security.setAutoLockEnabled(false);
      await security.clearPin();

      final List<String> logs = await securityLogs();
      expect(logs, isNotEmpty);

      final String joined = logs.join('\n');
      expect(joined, contains('رمز الدخول'));
      expect(joined, isNot(contains('1234')));
      expect(joined, isNot(contains('5678')));
      expect(joined, isNot(contains('pin')));
    });

    test('إنشاء الرمز وتعطيله يختلفان في الوصف', () async {
      await security.setPin('1234');
      expect(await securityLogs(), <String>['إنشاء رمز الدخول']);

      await security.setPin('4321');
      expect(await securityLogs(), <String>[
        'تغيير رمز الدخول',
        'إنشاء رمز الدخول',
      ]);
    });
  });
}
