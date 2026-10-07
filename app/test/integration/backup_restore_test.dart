import 'dart:convert';
import 'dart:io';

import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/core/query/search_query.dart';
import 'package:admin_staff/models/employee.dart';
import 'package:admin_staff/models/permanence_record.dart';
import 'package:admin_staff/models/saved_filter.dart';
import 'package:admin_staff/repositories/audit_repository.dart';
import 'package:admin_staff/repositories/employee_repository.dart';
import 'package:admin_staff/repositories/filter_repository.dart';
import 'package:admin_staff/repositories/leave_repository.dart';
import 'package:admin_staff/repositories/permanence_repository.dart';
import 'package:admin_staff/repositories/reference_repository.dart';
import 'package:admin_staff/repositories/settings_repository.dart';
import 'package:admin_staff/repositories/status_repository.dart';
import 'package:admin_staff/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ اختبارات النسخ الاحتياطي والاستعادة (D-012).
///
/// تغطي: التشفير فعلياً (لا نص صريح في الملف)، البصمة SHA-256
/// قبل فك التشفير، رفض الصيغ التالفة والمخططات غير المطابقة،
/// **الذرّية** (فشل صفّ واحد = لا تغيير)، وسياسة settings
/// (الجهازي لا يعود أبداً).
void main() {
  late Database db;
  late AppDatabase appDb;
  late BackupService backup;
  late EmployeeRepository employees;
  late LeaveRepository leaves;
  late PermanenceRepository permanence;
  late ReferenceRepository refs;
  late SettingsRepository settings;
  late FilterRepository filters;
  late AuditRepository audit;
  late Directory tmp;

  const String pw = 'S3cret-باس';

  String fileOf(String name) => '${tmp.path}/$name.asbk';

  Future<int> countOf(String table) async {
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) c FROM $table');
    return rows.first['c'] as int;
  }

  Future<Map<String, Object?>> rowOf(
    String table,
    String where,
    List<Object?> args,
  ) async {
    final List<Map<String, Object?>> rows =
        await db.query(table, where: where, whereArgs: args, limit: 1);
    return rows.single;
  }

  /// يلتقط أي استثناء ويعيده للفحص — `catchError` على `Future<T>`
  /// يفرض أن يعيد الحالة نفسها، فلا يصلح لالتقاط الخطأ.
  Future<Object?> caught(Future<Object> op) async {
    try {
      await op;
      return null;
    } catch (e) {
      return e;
    }
  }

  bool containsBytes(List<int> hay, List<int> needle) {
    if (needle.isEmpty || hay.length < needle.length) return false;
    for (int i = 0; i <= hay.length - needle.length; i++) {
      bool ok = true;
      for (int j = 0; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  /// معطّلات ثابتة: زرع + قسم + موظفان + رخصة + مداومة + فلتر
  /// + مفتاح استيراد — كل اختبار يبدأ منها فلا يتأثر بما قبله.
  Future<void> baseline() async {
    for (final String t in BackupService.tables.reversed) {
      await db.delete(t);
    }
    await db.delete(Db.settings);
    await AppDatabase.seed(db);

    final int sectionId =
        await refs.createEntry(Db.sections, 'Finance', nameAr: 'المالية');
    await employees.insert(
      Employee(
        matricule: '000123',
        nomAr: 'أحمد',
        prenomAr: 'بن عمر',
        nomFr: 'AHMED',
        prenomFr: 'BENAMAR',
        sectionId: sectionId,
        ppr: '900111',
        mobilePhone: '0661234567',
        notes: 'ملاحظة "بعلامات" \'وخاصة\'',
      ),
    );
    await employees.insert(
      Employee(
        matricule: '000456',
        nomFr: 'KARIM',
        sectionId: sectionId,
        isActive: false,
      ),
    );

    final List<Map<String, Object?>> lts = await db.query(
      Db.leaveTypes,
      columns: <String>[Db.cId],
      where: '${Db.cNameAr} = ?',
      whereArgs: <Object?>['عطلة إدارية'],
      limit: 1,
    );
    final List<Map<String, Object?>> emps = await db.query(
      Db.employees,
      columns: <String>[Db.cId],
      where: '${Db.cMatricule} = ?',
      whereArgs: <Object?>['000123'],
      limit: 1,
    );
    final int e1 = emps.single[Db.cId] as int;

    await leaves.create(
      employeeId: e1,
      leaveTypeId: lts.single[Db.cId] as int,
      startDate: '2026-10-01',
      notes: 'سبب المغادرة',
    );
    await permanence.insert(
      PermanenceRecord(
        date: '2026-10-05',
        matricule: '000123',
        employeeId: e1,
        startTime: '08:00',
        endTime: '12:00',
        section: 'المالية',
      ),
    );
    await filters.add(
      name: 'الأعضاء',
      kind: SavedFilterKind.employees,
      query: const SearchQuery(text: 'ahmed'),
    );
    await settings.write(Db.keyImportMappingEmployees, '{"matricule":"M"}');
  }

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    appDb = AppDatabase.fromDatabase(db);
    backup = BackupService(appDb);
    employees = EmployeeRepository(appDb);
    refs = ReferenceRepository(appDb);
    settings = SettingsRepository(appDb);
    filters = FilterRepository(appDb);
    audit = AuditRepository(appDb);
    final StatusRepository statuses = StatusRepository(appDb);
    leaves = LeaveRepository(appDb, statuses);
    permanence = PermanenceRepository(appDb, statuses);
    tmp = await Directory.systemTemp.createTemp('admin_staff_backup');
  });

  tearDownAll(() async {
    await closeTestDb(db);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  // ── الإنشاء ─────────────────────────────────────────────────

  group('A1 الإنشاء', () {
    test('ملف مشفّر بترويسة تُقرأ بلا كلمة مرور', () async {
      await baseline();
      final String path = fileOf('a1');
      final BackupInfo info =
          await backup.create(password: pw, destinationPath: path);

      expect(info.employeeCount, 2);
      expect(info.schemaVersion, Db.schemaVersion);
      expect(info.totalRows, greaterThan(2));
      expect(info.checksum, hasLength(64), reason: 'SHA-256 = 64 hex');

      final List<int> raw = await File(path).readAsBytes();
      expect(String.fromCharCodes(raw.sublist(0, 4)), 'ASBK');
      expect(raw[4], 1, reason: 'إصدار صيغة الملف');

      final BackupInfo shown = await backup.preview(path);
      expect(shown.createdAt, info.createdAt);
      expect(shown.rowCounts, info.rowCounts);
      expect(shown.checksum, info.checksum);
      expect(shown.fileBytes, raw.length);
      expect(shown.employeeCount, 2);
    });

    test('لا نصّ صريح من البيانات ولا كلمة المرور في الملف', () async {
      await baseline();
      final String path = fileOf('a2');
      await backup.create(password: pw, destinationPath: path);

      final List<int> raw = await File(path).readAsBytes();
      final String asLatin1 = String.fromCharCodes(raw);

      for (final String marker in <String>[
        '000123',
        '000456',
        'AHMED',
        '900111',
        '0661234567',
        '2026-10-01',
        pw,
      ]) {
        expect(asLatin1.contains(marker), isFalse,
            reason: 'العلامة "$marker" يجب ألا تظهر غير مشفّرة');
      }
      expect(containsBytes(raw, utf8.encode('أحمد')), isFalse);
      expect(containsBytes(raw, utf8.encode('المالية')), isFalse);
    });

    test('كلمة مرور قصيرة تُرفض ولا يُكتب ملف', () async {
      await baseline();
      final String path = fileOf('a3');

      await expectLater(
        backup.create(password: 'abc', destinationPath: path),
        throwsA(isA<AppException>()),
      );
      expect(await File(path).exists(), isFalse);
    });
  });

  // ── رفض الملفات التالفة ─────────────────────────────────────

  group('B1 ملفات غير صالحة', () {
    test('غير موجود → رسالة عربية باسم الملف', () async {
      final Object? err = await caught(backup.preview(fileOf('لا-ملف')));
      expect(err, isA<AppException>());
      expect((err! as AppException).userMessage, contains('غير موجود'));
    });

    test('محتوى عشوائي ليس نسخة احتياطية', () async {
      final String path = fileOf('b2');
      final List<int> junk = List<int>.generate(200, (int i) => (i * 7) % 256);
      await File(path).writeAsBytes(junk);

      await expectLater(
        backup.preview(path),
        throwsA(isA<AppException>()),
      );
    });

    test('ملف أقصر من الترويسة', () async {
      final String path = fileOf('b3');
      await File(path).writeAsBytes(<int>[0x41, 0x53, 0x42]);

      await expectLater(
        backup.restore(sourcePath: path, password: pw),
        throwsA(isA<AppException>()),
      );
    });

    test('إصدار صيغة غير مدعوم', () async {
      final String path = fileOf('b4');
      await File(path).writeAsBytes(<int>[
        0x41, 0x53, 0x42, 0x4B, // ASBK
        9, // إصدار غير مدعوم
        0, 0, 0, 0,
      ]);

      final Object? err = await caught(backup.preview(path));
      expect(err, isA<AppException>());
      expect((err! as AppException).userMessage, contains('غير مدعوم'));
    });
  });

  // ── الاستعادة ───────────────────────────────────────────────

  group('C1 الاستعادة', () {
    test('تعيد الحالة كما كانت بعد الدمار', () async {
      await baseline();
      final String path = fileOf('c1');
      final BackupInfo info =
          await backup.create(password: pw, destinationPath: path);

      // دمار: كل الموظفين والسجلات + إضافة ما ليس في النسخة.
      await db.delete(Db.permanence);
      await db.delete(Db.leaves);
      await db.delete(Db.employees);
      await refs.createEntry(Db.sections, 'Extra', nameAr: 'زائدة');
      await settings.write(Db.keyImportMappingEmployees, 'CHANGED');
      expect(await countOf(Db.employees), 0);

      final RestoreReport report =
          await backup.restore(sourcePath: path, password: pw);

      expect(await countOf(Db.employees), 2);
      expect(report.employeeCount, 2);
      expect(report.rowCounts[Db.employees], 2);
      expect(report.restoredSettingsKeys,
          contains(Db.keyImportMappingEmployees));

      // النصوص بدقّتها — ولا سيّما البدء بصفر (نوع TEXT).
      final Map<String, Object?> a =
          await rowOf(Db.employees, '${Db.cMatricule} = ?', <Object?>['000123']);
      expect(a[Db.cNomAr], 'أحمد');
      expect(a[Db.cPrenomAr], 'بن عمر');
      expect(a[Db.cNomFr], 'AHMED');
      expect(a[Db.cPpr], '900111');
      expect(a[Db.cPhone], '0661234567');
      expect(a[Db.cIsActive], 1);
      expect(a[Db.cNotes], 'ملاحظة "بعلامات" \'وخاصة\'');

      final Map<String, Object?> b =
          await rowOf(Db.employees, '${Db.cMatricule} = ?', <Object?>['000456']);
      expect(b[Db.cIsActive], 0, reason: 'الموظف المعطَّل يعود معطَّلاً');

      expect(await countOf(Db.leaves), 1);
      expect(await countOf(Db.permanence), 1);
      expect(await filters.count(), 1);
      expect(await settings.read(Db.keyImportMappingEmployees),
          '{"matricule":"M"}',
          reason: 'المفتاح المسموح يعود من النسخة');

      final List<Map<String, Object?>> sections = await db.query(
        Db.sections,
        columns: <String>[Db.cName],
      );
      expect(sections.map((Map<String, Object?> r) => r[Db.cName]),
          isNot(contains('Extra')),
          reason: 'ما أُضيف بعد النسخ لا يبقى');
      expect(info.totalRows, greaterThan(5));
    });

    test('كلمة مرور خاطئة تُرفض ولا تتغيّر البيانات', () async {
      await baseline();
      final String path = fileOf('c2');
      await backup.create(password: pw, destinationPath: path);

      await db.delete(Db.permanence);
      await db.delete(Db.leaves);
      await db.delete(Db.employees);
      expect(await countOf(Db.employees), 0);

      await expectLater(
        backup.restore(sourcePath: path, password: 'كلمة-أخرى-هنا'),
        throwsA(isA<AppException>()),
      );
      expect(await countOf(Db.employees), 0,
          reason: 'لا نصف تطبيق بعد فشل التشفير');
      expect(await countOf(Db.statusTypes), 9, reason: 'ولا المراجع');
    });

    test('تغيير بايت في الشيفرة → البصمة ترفضه', () async {
      await baseline();
      final String path = fileOf('c3');
      await backup.create(password: pw, destinationPath: path);

      final List<int> raw = await File(path).readAsBytes();
      raw[raw.length - 1] = raw[raw.length - 1] ^ 0xFF;
      await File(path).writeAsBytes(raw);

      final Object? err =
          await caught(backup.restore(sourcePath: path, password: pw));
      expect(err, isA<AppException>());
      expect((err! as AppException).userMessage, contains('تالف'));
      expect(await countOf(Db.employees), 2, reason: 'البيانات كما كانت');
    });

    test('تغيير بايت في الترويسة → خطأ عربي لا استثناء خام', () async {
      await baseline();
      final String path = fileOf('c4');
      await backup.create(password: pw, destinationPath: path);

      final List<int> raw = await File(path).readAsBytes();
      raw[14] = raw[14] ^ 0x55; // داخل JSON الترويسة
      await File(path).writeAsBytes(raw);

      final Object? err =
          await caught(backup.restore(sourcePath: path, password: pw));
      expect(err, isA<AppException>());
      expect((err! as AppException).userMessage, isNot(contains('Exception')));
      expect(await countOf(Db.employees), 2);
    });

    test('ملف مبتور من المنتصف', () async {
      await baseline();
      final String path = fileOf('c5');
      await backup.create(password: pw, destinationPath: path);

      final List<int> raw = await File(path).readAsBytes();
      await File(path).writeAsBytes(raw.sublist(0, raw.length ~/ 2));

      await expectLater(
        backup.restore(sourcePath: path, password: pw),
        throwsA(isA<AppException>()),
      );
      expect(await countOf(Db.employees), 2);
    });
  });

  // ── settings وسجل التدقيق ──────────────────────────────────

  group('D1 الإعدادات والسجل', () {
    test('المسموح يستعاد والجهازي/الأمني لا', () async {
      await baseline();
      final String path = fileOf('d1');
      await backup.create(password: pw, destinationPath: path);

      // تغييرات بعد النسخ: مفتاح مسموح + مفاتيح جهازية وأمنية.
      await settings.write(Db.keyImportMappingEmployees, 'بعد النسخة');
      await settings.setLocale('fr');
      await settings.write(Db.keyPinHash, 'سر-جديد');
      await settings.write(Db.keyAutoLockMinutes, '15');

      await backup.restore(sourcePath: path, password: pw);

      expect(await settings.read(Db.keyImportMappingEmployees),
          '{"matricule":"M"}');
      expect(await settings.locale(), 'fr',
          reason: 'لغة الجهاز تبقى كما اختارها المستخدم');
      expect(await settings.read(Db.keyPinHash), 'سر-جديد',
          reason: 'ملف PIN من نسخة أخرى كان سيقفل المستخدم');
      expect(await settings.autoLockMinutes(), 15);
    });

    test('كل مفتاح الاستيراد الظاهر في الملف منائبه فقط', () async {
      expect(
        BackupService.restorableSettingsKeys.toSet(),
        <String>{
          Db.keyImportMappingEmployees,
          Db.keyImportMappingPermanence,
          Db.keySavedDelimiterEmployees,
          Db.keySavedDelimiterPermanence,
        },
        reason: 'قائمة بيضاء — جديد لا يدخل تلقائياً',
      );
    });

    test('قيد backup ثم قيد restore في السجل', () async {
      await baseline();
      final String path = fileOf('d3');
      await backup.create(password: pw, destinationPath: path);
      expect(await audit.byAction('backup'), isNotEmpty);

      await backup.restore(sourcePath: path, password: pw);
      final List<dynamic> restores = await audit.byAction('restore');
      expect(restores, isNotEmpty,
          reason: 'الاستعادة تُدوَّن دائماً بعد التطبيق');
      expect(await audit.byAction('backup'), isEmpty,
          reason: 'السجل عاد بنسخة النسخة (قبل قيد الاستعادة)');
    });
  });

  // ── صيغ خاطئة عبر writeFile ─────────────────────────────────

  group('E1 المخطط والذرّية', () {
    Map<String, Object?> crafted({
      int version = Db.schemaVersion,
      Map<String, Object?>? tables,
    }) =>
        <String, Object?>{
          'format': 'admin_staff_backup',
          'schema_version': version,
          'created_at': '2026-01-01T00:00:00.000',
          'tables': tables ??
              <String, Object?>{
                for (final String t in BackupService.tables)
                  t: <Map<String, Object?>>[],
              },
          'settings': <Map<String, Object?>>[],
        };

    test('مخطط أقدم/أحدث يُرفض قبل أي كتابة', () async {
      await baseline();

      for (final int v in <int>[0, Db.schemaVersion + 1]) {
        final String path = fileOf('e1_$v');
        await backup.writeFile(path: path, password: pw, payload: crafted(version: v));

        final Object? err =
            await caught(backup.restore(sourcePath: path, password: pw));
        expect(err, isA<AppException>(), reason: 'الإصدار $v');
        expect(await countOf(Db.statusTypes), 9,
            reason: 'لم يُمسّ شيء للإصدار $v');
        expect(await countOf(Db.employees), 2);
      }
    });

    test('جدول مجهول في الملف يُرفض', () async {
      await baseline();
      final String path = fileOf('e2');
      await backup.writeFile(
        path: path,
        password: pw,
        payload: crafted(
          tables: <String, Object?>{
            for (final String t in BackupService.tables)
              t: <Map<String, Object?>>[],
            'ghost_table': <Map<String, Object?>>[],
          },
        ),
      );

      final Object? err =
          await caught(backup.restore(sourcePath: path, password: pw));
      expect(err, isA<AppException>());
      expect((err! as AppException).userMessage, contains('غير معروف'));
      expect(await countOf(Db.employees), 2);
    });

    test('عمود غير موجود في المخطط يُرفض قبل المعاملة', () async {
      await baseline();
      final String path = fileOf('e3');
      await backup.writeFile(
        path: path,
        password: pw,
        payload: crafted(
          tables: <String, Object?>{
            for (final String t in BackupService.tables)
              t: <Map<String, Object?>>[],
            Db.employees: <Map<String, Object?>>[
              <String, Object?>{
                Db.cMatricule: 'ZZZ',
                'عمود_غير_موجود': 1,
                Db.cCreatedAt: 'x',
                Db.cUpdatedAt: 'x',
              },
            ],
          },
        ),
      );

      final Object? err =
          await caught(backup.restore(sourcePath: path, password: pw));
      expect(err, isA<AppException>());
      expect((err! as AppException).userMessage, contains('عمود'));
      expect(await countOf(Db.statusTypes), 9,
          reason: 'الرفض قبل المعاملة = لا حذف');
      expect(await countOf(Db.employees), 2);
    });

    test('صفّ فاشل واحد = تراجع كامل (لا نصف حالة)', () async {
      await baseline();
      final String path = fileOf('e4');
      await backup.writeFile(
        path: path,
        password: pw,
        payload: crafted(
          tables: <String, Object?>{
            for (final String t in BackupService.tables)
              t: <Map<String, Object?>>[],
            Db.employees: <Map<String, Object?>>[
              <String, Object?>{
                Db.cMatricule: 'DUP',
                Db.cCreatedAt: 'x',
                Db.cUpdatedAt: 'x',
              },
              <String, Object?>{
                Db.cMatricule: 'DUP', // نفس الرقم → UNIQUE
                Db.cCreatedAt: 'x',
                Db.cUpdatedAt: 'x',
              },
            ],
          },
        ),
      );

      final Object? err =
          await caught(backup.restore(sourcePath: path, password: pw));
      expect(err, isA<AppException>(),
          reason: 'خطأ القاعدة يُلفّ برسالة عربية');
      expect((err! as AppException).userMessage, isNot(contains('UNIQUE')));

      expect(await countOf(Db.employees), 2, reason: 'لا شيء حُذف');
      expect(await countOf(Db.statusTypes), 9, reason: 'ولا المراجع');
      expect(await countOf(Db.leaves), 1, reason: 'ولا الرخص');
    });
  });
}
