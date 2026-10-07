import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ اختبارات مستودع الإعدادات على SQLite حقيقي.
///
/// تغطي: الافتراضيات المزروعة (لا رقم في الكود)، قيود الأمان
/// (اللغة وزمن القفل)، والتعامل مع قيم تالفة بلا استثناءات خام.
void main() {
  late Database db;
  late SettingsRepository repo;

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    repo = SettingsRepository(AppDatabase.fromDatabase(db));
  });

  tearDownAll(() async => closeTestDb(db));

  group('A1 الافتراضيات المزروعة', () {
    test('كل المفاتيح الافتراضية مقروءة من القاعدة لا من الكود', () async {
      expect(await repo.locale(), 'ar');
      expect(await repo.pinEnabled(), isFalse);
      expect(await repo.biometricEnabled(), isFalse);
      expect(await repo.notificationsEnabled(), isTrue);
      expect(await repo.autoLockMinutes(), 5);
    });

    test('read لمفتاح غير موجود → null، وreadOr → القيمة البديلة', () async {
      expect(await repo.read('does_not_exist'), isNull);
      expect(await repo.readOr('does_not_exist', 'fallback'), 'fallback');
    });

    test('readOr لا يلغي قيمة مكتوبة صراحةً بـ فراغ', () async {
      await repo.write('empty_key', '');
      expect(await repo.read('empty_key'), '');
      expect(await repo.readOr('empty_key', 'fallback'), '',
          reason: 'القيمة موجودة فعلاً');
      expect(await repo.readOr('missing_key', 'fallback'), 'fallback');
    });
  });

  group('B1 الكتابة والقراءة', () {
    test('write ينشئ ويستبدل ويحدّث updated_at', () async {
      await repo.write('theme', 'dark');
      expect(await repo.read('theme'), 'dark');
      final String first =
          (await db.query(Db.settings, where: '${Db.cKey} = ?', whereArgs: <Object?>['theme']))
              .single[Db.cUpdatedAt] as String;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.write('theme', 'darker');

      expect(await repo.read('theme'), 'darker');
      final String second =
          (await db.query(Db.settings, where: '${Db.cKey} = ?', whereArgs: <Object?>['theme']))
              .single[Db.cUpdatedAt] as String;
      expect(second.compareTo(first), greaterThanOrEqualTo(0));
    });

    test('writeMany يكتب كل المفاتيح معاً', () async {
      await repo.writeMany(<String, String>{'k1': 'a', 'k2': 'b', 'k3': 'c'});
      expect(await repo.read('k1'), 'a');
      expect(await repo.read('k2'), 'b');
      expect(await repo.read('k3'), 'c');

      await repo.writeMany(<String, String>{});
      expect(await repo.read('k4'), isNull, reason: 'خريطة فارغة لا شيء');
    });

    test('delete يعيد القراءة إلى البديل', () async {
      await repo.write('temp', 'x');
      expect(await repo.read('temp'), 'x');
      await repo.delete('temp');
      expect(await repo.read('temp'), isNull);
      expect(await repo.readOr('temp', 'fb'), 'fb');
    });

    test('all() ترجع كل ما كُتب', () async {
      final Map<String, String> all = await repo.all();
      expect(all[Db.keyLocale], 'ar');
      expect(all[Db.keyAutoLockMinutes], '5');
      expect(all.containsKey('temp'), isFalse, reason: 'محذوف');
    });

    test('deleteMany يحذف عدة مفاتيح', () async {
      await repo.writeMany(<String, String>{'d1': '1', 'd2': '2', 'd3': '3'});
      await repo.deleteMany(<String>['d1', 'd2']);
      expect(await repo.read('d1'), isNull);
      expect(await repo.read('d2'), isNull);
      expect(await repo.read('d3'), '3');
      await repo.deleteMany(<String>[]);
      expect(await repo.read('d3'), '3');
    });
  });

  group('C1 اللغة والأعلام', () {
    test('setLocale يقبل العربية والفرنسية ويرفض غيرهما', () async {
      await repo.setLocale('fr');
      expect(await repo.locale(), 'fr');
      await repo.setLocale('ar');
      expect(await repo.locale(), 'ar');

      await expectLater(
        repo.setLocale('de'),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('لغة غير مدعومة'),
          ),
        ),
      );
      expect(await repo.locale(), 'ar', reason: 'الرفض بلا تغيير');
    });

    test('الأعلام تُكتب 1/0 وتُقرأ ثنائية', () async {
      await repo.setPinEnabled(true);
      expect(await repo.pinEnabled(), isTrue);
      await repo.setPinEnabled(false);
      expect(await repo.pinEnabled(), isFalse);

      await repo.setBiometricEnabled(true);
      expect(await repo.biometricEnabled(), isTrue);

      await repo.setNotificationsEnabled(false);
      expect(await repo.notificationsEnabled(), isFalse);
      await repo.setNotificationsEnabled(true);
      expect(await repo.notificationsEnabled(), isTrue);
    });

    test('قيمة مفتاح ثنائي غير منطقية → مطفأ لا انهيار', () async {
      await repo.write(Db.keyBiometricEnabled, 'yes');
      expect(await repo.biometricEnabled(), isFalse);
      await repo.setBiometricEnabled(false);
      expect(await repo.biometricEnabled(), isFalse);
    });
  });

  group('D1 زمن القفل التلقائي', () {
    test('كتابة 1 و5 و15 تُقرأ كما هي', () async {
      for (final int m in <int>[1, 5, 15]) {
        await repo.setAutoLockMinutes(m);
        expect(await repo.autoLockMinutes(), m);
      }
    });

    test('قيمة غير صالحة عند الكتابة → عربية', () async {
      for (final int bad in <int>[0, -3, 61]) {
        await expectLater(
          repo.setAutoLockMinutes(bad),
          throwsA(isA<AppException>().having((AppException x) => x.userMessage, 'm', contains('دقيقة'))),
        );
      }
      expect(await repo.autoLockMinutes(), 15, reason: 'لم يتغيّر شيء');
    });

    test('قيمة تالفة مخزَّنة → الافتراضي لا استثناء', () async {
      await repo.write(Db.keyAutoLockMinutes, 'abc');
      expect(await repo.autoLockMinutes(), 5);
      await repo.write(Db.keyAutoLockMinutes, '0');
      expect(await repo.autoLockMinutes(), 5);
      await repo.write(Db.keyAutoLockMinutes, '');
      expect(await repo.autoLockMinutes(), 5);
      await repo.setAutoLockMinutes(5);
    });

    test('حذف المفتاح → الافتراضي', () async {
      await repo.setAutoLockMinutes(15);
      await repo.delete(Db.keyAutoLockMinutes);
      expect(await repo.autoLockMinutes(), 5);
    });
  });

  group('E1 القيم المركّبة JSON', () {
    test('كتابة وقراءة خريطة', () async {
      await repo.writeJson(
        Db.keyImportMappingEmployees,
        <String, Object?>{'name': 1, 'matricule': 2},
      );
      final Object? v = await repo.readJson(Db.keyImportMappingEmployees);
      expect(v, isA<Map<String, dynamic>>());
      expect((v as Map<String, dynamic>)['matricule'], 2);
    });

    test('JSON تالف → null لا FormatException', () async {
      await repo.write('broken', '{not json');
      expect(await repo.readJson('broken'), isNull);
      expect(await repo.read('broken'), '{not json',
          reason: 'النص التالف يبقى للتشخيص ولا يُمسح');
    });

    test('مفتاح فارغ أو غائب → null', () async {
      await repo.write('blank', '   ');
      expect(await repo.readJson('blank'), isNull);
      expect(await repo.readJson('never_written'), isNull);
    });

    test('مسح أسرار الـ PIN عند إلغائه', () async {
      await repo.writeMany(<String, String>{
        Db.keyPinHash: 'hash',
        Db.keyPinSalt: 'salt',
      });
      expect(await repo.read(Db.keyPinHash), 'hash');
      expect(await repo.read(Db.keyPinSalt), 'salt');

      await repo.clearPinSecrets();
      expect(await repo.read(Db.keyPinHash), isNull);
      expect(await repo.read(Db.keyPinSalt), isNull);
      expect(await repo.pinEnabled(), isFalse, reason: 'المفتاح الآخر باقٍ');
    });
  });
}
