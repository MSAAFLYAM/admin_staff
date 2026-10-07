import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/models/employee.dart';
import 'package:admin_staff/models/leave.dart';
import 'package:admin_staff/models/status_type.dart';
import 'package:admin_staff/repositories/employee_repository.dart';
import 'package:admin_staff/repositories/status_repository.dart';
import 'package:admin_staff/services/status_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ اختبارات مستودع الوضعيات على SQLite حقيقي.
///
/// تغطي: قاعدة 14 (لا حذف فيزيائي)، قاعدة 44/D-006 (ترتيب الاشتقاق)،
/// قاعدة 84 (الأولوية من الجدول لا من الكود)، وقواعد التقييد بالتاريخ.
void main() {
  late Database db;
  late AppDatabase appDb;
  late StatusRepository repo;
  late EmployeeRepository employees;

  // معرّفات الوضعيات من الـ seed.
  late int stService;
  late int stAdmin;
  late int stExceptional;
  late int stMaladie;
  late int stSuspendu;
  late int stRetraite;

  /// معرّف نوع الرخصة «رخصة مرضية» (مرتبط بوضعيته في الـ seed).
  late int leaveMaladieType;

  int seq = 0;

  Future<int> newEmployee({int? statusId}) async {
    seq++;
    return employees.insert(
      Employee(
        matricule: '9${seq.toString().padLeft(4, '0')}',
        nomFr: 'EMP$seq',
        currentStatusId: statusId,
      ),
    );
  }

  Future<void> addLeave(
    int employeeId, {
    required String start,
    required String end,
    bool cancelled = false,
  }) async {
    final String now = DateTime.now().toIso8601String();
    await db.insert(
      Db.leaves,
      Leave(
        employeeId: employeeId,
        leaveTypeId: leaveMaladieType,
        startDate: start,
        endDate: end,
        isCancelled: cancelled,
        createdAt: now,
        updatedAt: now,
      ).toInsertMap(),
    );
  }

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    appDb = AppDatabase.fromDatabase(db);
    repo = StatusRepository(appDb);
    employees = EmployeeRepository(appDb);

    final Map<String, int> byName = <String, int>{};
    final List<Map<String, Object?>> sts = await db.query(
      Db.statusTypes,
      columns: <String>[Db.cId, Db.cName],
    );
    for (final Map<String, Object?> s in sts) {
      byName[s[Db.cName] as String] = s[Db.cId] as int;
    }
    stService = byName['في الخدمة']!;
    stAdmin = byName['عطلة إدارية']!;
    stExceptional = byName['رخصة استثنائية']!;
    stMaladie = byName['رخصة مرضية']!;
    stSuspendu = byName['موقوف']!;
    stRetraite = byName['التقاعد']!;

    final List<Map<String, Object?>> lts = await db.query(
      Db.leaveTypes,
      columns: <String>[Db.cId, Db.cNameAr],
      where: '${Db.cNameAr} = ?',
      whereArgs: <Object?>['رخصة مرضية'],
    );
    leaveMaladieType = lts.single[Db.cId] as int;
  });

  tearDownAll(() async => closeTestDb(db));

  // ── الكتابة والقراءة ────────────────────────────────────────

  group('A1 الإضافة والجلب', () {
    test('add يُرجع السجل مع أسماء الوضعية من الـ JOIN', () async {
      final int e = await newEmployee(statusId: stService);
      final StatusHistoryEntry r = await repo.add(
        employeeId: e,
        statusTypeId: stSuspendu,
        startDate: '2026-10-01',
        endDate: '2026-10-05',
        notes: 'عقوبة',
      );

      expect(r.id, isNotNull);
      expect(r.statusName, 'موقوف');
      expect(r.statusPriority, 90, reason: 'priority يأتي من status_types');
      expect(r.startDate, '2026-10-01');
      expect(r.endDate, '2026-10-05');
      expect(r.notes, 'عقوبة');
      expect(r.isOpen, isFalse);
      expect(r.createdAt, isNotNull);

      final List<StatusHistoryEntry> h = await repo.history(e);
      expect(h, hasLength(1));
      expect(h.single.id, r.id);
    });

    test('آخر سجل يظهر أولاً (الأحدث أولاً)', () async {
      final int e = await newEmployee();
      await repo.add(
        employeeId: e,
        statusTypeId: stService,
        startDate: '2026-01-01',
        endDate: '2026-02-01',
      );
      await repo.add(
        employeeId: e,
        statusTypeId: stMaladie,
        startDate: '2026-03-01',
        endDate: '2026-04-01',
      );

      final List<StatusHistoryEntry> h = await repo.history(e);
      expect(h, hasLength(2));
      expect(h.first.startDate, '2026-03-01');
      expect(h.last.startDate, '2026-01-01');
    });
  });

  group('A2 التواريخ والقيود', () {
    test('تاريخ DD/MM/YYYY يُوحَّد إلى YYYY-MM-DD', () async {
      final int e = await newEmployee();
      final StatusHistoryEntry r = await repo.add(
        employeeId: e,
        statusTypeId: stService,
        startDate: '05/11/2026',
        endDate: '07/11/2026',
      );
      expect(r.startDate, '2026-11-05');
      expect(r.endDate, '2026-11-07');
    });

    test('نهاية قبل بداية → AppException برسالة عربية', () async {
      final int e = await newEmployee();
      await expectLater(
        repo.add(
          employeeId: e,
          statusTypeId: stService,
          startDate: '2026-10-10',
          endDate: '2026-10-01',
        ),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('تاريخ النهاية قبل تاريخ البداية'),
          ),
        ),
      );
    });

    test('تاريخ غير صالح → رسالة عربية لا خطأ SQLite', () async {
      final int e = await newEmployee();
      await expectLater(
        repo.add(
          employeeId: e,
          statusTypeId: stService,
          startDate: '31/02/2026',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('موظف غير موجود → رسالة واضحة', () async {
      await expectLater(
        repo.add(
          employeeId: 999999,
          statusTypeId: stService,
          startDate: '2026-10-01',
        ),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('الموظف غير موجود'),
          ),
        ),
      );
    });

    test('وضعية غير موجودة → رسالة واضحة', () async {
      final int e = await newEmployee();
      await expectLater(
        repo.add(
          employeeId: e,
          statusTypeId: 999999,
          startDate: '2026-10-01',
        ),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('الوضعية غير موجودة'),
          ),
        ),
      );
    });
  });

  group('A3 الإغلاق بلا حذف (قاعدة 14 / D-008)', () {
    test('openEntry → endOpenEntry يغلق ولا يحذف', () async {
      final int e = await newEmployee();
      await repo.add(
        employeeId: e,
        statusTypeId: stMaladie,
        startDate: '2026-10-01',
      );

      final StatusHistoryEntry? open = await repo.openEntry(e);
      expect(open, isNotNull);
      expect(open!.isOpen, isTrue);

      expect(await repo.endOpenEntry(e, '2026-10-20'), isTrue);
      expect(await repo.openEntry(e), isNull, reason: 'لم يعد هناك سجل مفتوح');

      final List<StatusHistoryEntry> h = await repo.history(e);
      expect(h, hasLength(1), reason: 'الإغلاق ليس حذفاً');
      expect(h.single.endDate, '2026-10-20');
      expect(h.single.isOpen, isFalse);
    });

    test('endOpenEntry بلا سجل مفتوح → false لا خطأ', () async {
      final int e = await newEmployee();
      expect(await repo.endOpenEntry(e, '2026-10-20'), isFalse);
    });

    test('closeEntry يرفض نهاية قبل بداية السجل', () async {
      final int e = await newEmployee();
      final StatusHistoryEntry r = await repo.add(
        employeeId: e,
        statusTypeId: stService,
        startDate: '2026-10-01',
      );
      await expectLater(
        repo.closeEntry(r.id!, '2025-01-01'),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('تاريخ النهاية قبل تاريخ البداية'),
          ),
        ),
      );
      final StatusHistoryEntry after = await repo.byId(r.id!);
      expect(after.endDate, isNull, reason: 'لم يتغيّر شيء');
    });

    test('updateEntry يعدّل بلا حذف، ويرفض سجلاً غير محفوظ', () async {
      final int e = await newEmployee();
      final StatusHistoryEntry r = await repo.add(
        employeeId: e,
        statusTypeId: stService,
        startDate: '2026-10-01',
        endDate: '2026-10-05',
      );

      await repo.updateEntry(
        r.copyWith(statusTypeId: stSuspendu, endDate: '2026-10-09', notes: 'م'),
      );
      final StatusHistoryEntry after = await repo.byId(r.id!);
      expect(after.statusTypeId, stSuspendu);
      expect(after.statusName, 'موقوف');
      expect(after.endDate, '2026-10-09');
      expect(after.notes, 'م');
      expect(after.startDate, '2026-10-01', reason: 'created_at/البداية ثابتة');

      await expectLater(
        repo.updateEntry(
          StatusHistoryEntry(
            employeeId: e,
            statusTypeId: stService,
            startDate: '2026-10-01',
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('غير محفوظ'),
          ),
        ),
      );
    });
  });

  // ── الاشتقاق (D-006 / قاعدة 44) ────────────────────────────

  group('B1 مصدر الاشتقاق', () {
    test('لا سجل ولا رخصة → الوضعية المسجَّلة للموظف', () async {
      final int e = await newEmployee(statusId: stService);
      final ResolvedStatus r = await repo.derived(e, on: '2026-10-01');
      expect(r.winner?.source, StatusSource.employeeDefault);
      expect(r.label, 'في الخدمة');
      expect(r.sourceLabel, 'الوضعية المسجَّلة');
      expect(r.isAmbiguous, isFalse);
    });

    test('لا وضعية مسجَّلة أصلاً → فارغ لا خطأ', () async {
      final int e = await newEmployee();
      final ResolvedStatus r = await repo.derived(e, on: '2026-10-01');
      expect(r.isEmpty, isTrue);
      expect(r.statusTypeId, 0);
      expect(r.label, '');
    });

    test('سجل الوضعيات يسبق المسجَّلة ولو كانت أولويتها 100', () async {
      // الوضعية المسجَّلة = التقاعد (100)، والسجل = في الخدمة (0).
      final int e = await newEmployee(statusId: stRetraite);
      await repo.add(
        employeeId: e,
        statusTypeId: stService,
        startDate: '2026-10-01',
      );

      final ResolvedStatus r = await repo.derived(e, on: '2026-10-02');
      expect(r.winner?.source, StatusSource.statusHistory);
      expect(r.label, 'في الخدمة');
      expect(r.sourceLabel, 'سجل الوضعيات');
    });

    test('خارج فترة السجل → نعود للمسجَّلة', () async {
      final int e = await newEmployee(statusId: stRetraite);
      await repo.add(
        employeeId: e,
        statusTypeId: stService,
        startDate: '2026-10-01',
        endDate: '2026-10-05',
      );

      final ResolvedStatus r = await repo.derived(e, on: '2026-10-20');
      expect(r.winner?.source, StatusSource.employeeDefault);
      expect(r.label, 'التقاعد');
    });

    test('رخصة جارية → وضعيتها عبر leave_types.status_type_id', () async {
      final int e = await newEmployee(statusId: stService);
      await addLeave(e, start: '2026-10-01', end: '2026-10-05');

      final ResolvedStatus r = await repo.derived(e, on: '2026-10-03');
      expect(r.winner?.source, StatusSource.leave);
      expect(r.label, 'رخصة مرضية');
      expect(r.sourceLabel, 'رخصة جارية');
      expect(r.winner?.originLabel, contains('01/10/2026'));
    });

    test('الرخصة الملغاة لا تُنتج وضعية', () async {
      final int e = await newEmployee(statusId: stService);
      await addLeave(e, start: '2026-10-01', end: '2026-10-05', cancelled: true);

      final ResolvedStatus r = await repo.derived(e, on: '2026-10-03');
      expect(r.winner?.source, StatusSource.employeeDefault);
      expect(r.label, 'في الخدمة');
    });

    test('سجل الوضعيات يسبق الرخصة الجارية', () async {
      final int e = await newEmployee(statusId: stService);
      await addLeave(e, start: '2026-10-01', end: '2026-10-05');
      await repo.add(
        employeeId: e,
        statusTypeId: stSuspendu,
        startDate: '2026-10-02',
      );

      final ResolvedStatus r = await repo.derived(e, on: '2026-10-03');
      expect(r.winner?.source, StatusSource.statusHistory);
      expect(r.label, 'موقوف');
    });
  });

  group('B2 الأولوية والغموض (قواعد 84 و45)', () {
    test('الأولوية الأعلى تغلب داخل السجل', () async {
      final int e = await newEmployee();
      await repo.add(
        employeeId: e,
        statusTypeId: stService,
        startDate: '2026-10-01',
      );
      await repo.add(
        employeeId: e,
        statusTypeId: stSuspendu,
        startDate: '2026-10-02',
      );

      final ResolvedStatus r = await repo.derived(e, on: '2026-10-03');
      expect(r.label, 'موقوف', reason: '90 فوق 0');
      expect(r.isAmbiguous, isFalse);
    });

    test('أولويتان متساويتان → isAmbiguous ولا تطبيق تلقائي', () async {
      final int e = await newEmployee();
      // «عطلة إدارية» و«رخصة استثنائية» كلاهما priority 20 في الـ seed.
      await repo.add(employeeId: e, statusTypeId: stAdmin, startDate: '2026-10-01');
      await repo.add(
        employeeId: e,
        statusTypeId: stExceptional,
        startDate: '2026-10-01',
      );

      final ResolvedStatus r = await repo.derived(e, on: '2026-10-02');
      expect(r.isAmbiguous, isTrue, reason: 'قاعدة 45: يُعرض لا يُطبَّق');
      expect(r.candidates.where((StatusCandidate c) => c.priority == 20),
          hasLength(2));
      expect(r.label, anyOf('عطلة إدارية', 'رخصة استثنائية'));
    });

    test('الأولوية من الجدول لا من الكود — تعديلها يغيّر الفائز', () async {
      final int e = await newEmployee();
      await repo.add(employeeId: e, statusTypeId: stAdmin, startDate: '2026-10-01');
      await repo.add(
        employeeId: e,
        statusTypeId: stSuspendu,
        startDate: '2026-10-01',
      );
      expect((await repo.derived(e, on: '2026-10-02')).label, 'موقوف');

      // رفَعنا أولوية «عطلة إدارية» إلى 95 → تتغلب فوراً.
      await db.update(
        Db.statusTypes,
        <String, Object?>{Db.cPriority: 95},
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[stAdmin],
      );
      expect(
        (await repo.derived(e, on: '2026-10-02')).label,
        'عطلة إدارية',
        reason: 'قاعدة 13: الأولوية قابلة للتعديل من الواجهة',
      );
      await db.update(
        Db.statusTypes,
        <String, Object?>{Db.cPriority: 20},
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[stAdmin],
      );
    });
  });

  // ── التقييد والتجميع ────────────────────────────────────────

  group('C1 التقييد بالتاريخ', () {
    test('activeOn تعيد السجلات التي تغطي التاريخ فقط', () async {
      final int e = await newEmployee();
      await repo.add(
        employeeId: e,
        statusTypeId: stMaladie,
        startDate: '2026-10-01',
        endDate: '2026-10-05',
      );

      expect(await repo.activeOn(e, '2026-10-03'), hasLength(1));
      expect(await repo.activeOn(e, '2026-10-01'), hasLength(1), reason: 'البداية');
      expect(await repo.activeOn(e, '2026-10-05'), hasLength(1), reason: 'النهاية');
      expect(await repo.activeOn(e, '2026-10-06'), isEmpty);
      expect(await repo.activeOn(e, '2026-09-30'), isEmpty);
    });

    test('activeOnly يستبعد السجلات المغلقة', () async {
      final int e = await newEmployee();
      await repo.add(
        employeeId: e,
        statusTypeId: stMaladie,
        startDate: '2026-01-01',
        endDate: '2026-02-01',
      );
      await repo.add(employeeId: e, statusTypeId: stService, startDate: '2026-03-01');

      expect(await repo.history(e, activeOnly: true), hasLength(1));
      expect((await repo.history(e, activeOnly: true)).single.isOpen, isTrue);
      expect(await repo.history(e), hasLength(2));
    });

    test('سجل مفتوح يغطي أي تاريخ لاحق', () async {
      final int e = await newEmployee();
      await repo.add(employeeId: e, statusTypeId: stService, startDate: '2026-10-01');
      expect(await repo.activeOn(e, '2099-12-31'), hasLength(1));
    });
  });

  group('C2 الاشتقاق الدفعي (بلا N+1)', () {
    test('derivedForAll يوافق derived للموظف الواحد', () async {
      final int e1 = await newEmployee(statusId: stService);
      final int e2 = await newEmployee(statusId: stRetraite);
      await repo.add(
        employeeId: e2,
        statusTypeId: stSuspendu,
        startDate: '2026-10-01',
      );
      await addLeave(e1, start: '2026-10-01', end: '2026-10-05');

      final Map<int, ResolvedStatus> all =
          await repo.derivedForAll(on: '2026-10-03');

      expect(all[e1]?.label, 'رخصة مرضية');
      expect(all[e2]?.label, 'موقوف');
      expect(all[e1]?.label, (await repo.derived(e1, on: '2026-10-03')).label);
      expect(all[e2]?.label, (await repo.derived(e2, on: '2026-10-03')).label);
      expect(all.length, greaterThanOrEqualTo(2));
    });

    test('الموظف المعطَّل صاحب سجل تاريخي يبقى في النتائج', () async {
      final int e = await newEmployee(statusId: stService);
      await repo.add(employeeId: e, statusTypeId: stMaladie, startDate: '2026-10-01');
      await employees.deactivate(e);

      final Map<int, ResolvedStatus> all =
          await repo.derivedForAll(on: '2026-10-03');
      expect(all.containsKey(e), isTrue, reason: 'التاريخ لا يُمحى بالتعطيل');
      expect(all[e]?.winner?.source, StatusSource.statusHistory);
    });

    test('موظف معطَّل بلا سجل لا يظهر في الدفعة', () async {
      final int e = await newEmployee(statusId: stService);
      await employees.deactivate(e);

      final Map<int, ResolvedStatus> all =
          await repo.derivedForAll(on: '2026-10-03');
      expect(all.containsKey(e), isFalse);
    });

    test('حالة غير نشطة في status_types لا تُشتق', () async {
      final int e = await newEmployee(statusId: stService);
      await repo.add(employeeId: e, statusTypeId: stMaladie, startDate: '2026-10-01');
      expect((await repo.derived(e, on: '2026-10-03')).label, 'رخصة مرضية');

      await db.update(
        Db.statusTypes,
        <String, Object?>{Db.cIsActive: 0},
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[stMaladie],
      );
      expect(
        (await repo.derived(e, on: '2026-10-03')).label,
        'في الخدمة',
        reason: 'تعود للوضعية المسجَّلة بدل استعمال وضعية ملغاة',
      );
      await db.update(
        Db.statusTypes,
        <String, Object?>{Db.cIsActive: 1},
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[stMaladie],
      );
    });
  });
}
