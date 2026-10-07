import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/core/utils/app_date.dart';
import 'package:admin_staff/models/employee.dart';
import 'package:admin_staff/models/leave.dart';
import 'package:admin_staff/repositories/employee_repository.dart';
import 'package:admin_staff/repositories/leave_repository.dart';
import 'package:admin_staff/repositories/status_repository.dart';
import 'package:admin_staff/services/conflict_detector.dart';
import 'package:admin_staff/services/leave_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ اختبارات مستودع الرخص على SQLite حقيقي.
///
/// تغطي: قاعدة 17 (لا رقم مُثبَّت)، قاعدة 18 (المحرّك المستقل)،
/// قاعدة 31/D-008 (إلغاء منطقي لا حذف)، قاعدة 45 (التعارض قبل
/// الكتابة وبلا تطبيق تلقائي)، وقاعدة 61 (البحث المُصفّى والترقيم).
void main() {
  late Database db;
  late AppDatabase appDb;
  late LeaveRepository repo;
  late StatusRepository statuses;
  late EmployeeRepository employees;

  // أنواع الرخص من الـ seed (مُبحث عنها بالاسم لا بالرقم).
  late int adminType; // عطلة إدارية — 30 يوماً تقويمياً
  late int maladieType; // رخصة مرضية — 30 يوماً
  late int hoursType; // رخصة 48 ساعة — 48 ساعة
  late int retraiteType; // التقاعد — مدة 0 (ترفض)
  late int stSuspendu; // وضعية «موقوف» لاختبار تعارض الوضعيات

  int seq = 0;

  Future<int> newEmployee() async {
    seq++;
    return employees.insert(
      Employee(matricule: 'L${seq.toString().padLeft(4, '0')}', nomFr: 'EMP$seq'),
    );
  }

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    appDb = AppDatabase.fromDatabase(db);
    statuses = StatusRepository(appDb);
    repo = LeaveRepository(appDb, statuses);
    employees = EmployeeRepository(appDb);

    final List<Map<String, Object?>> lts = await db.query(
      Db.leaveTypes,
      columns: <String>[Db.cId, Db.cNameAr],
    );
    final Map<String, int> byAr = <String, int>{
      for (final Map<String, Object?> m in lts)
        m[Db.cNameAr] as String: m[Db.cId] as int,
    };
    adminType = byAr['عطلة إدارية']!;
    maladieType = byAr['رخصة مرضية']!;
    hoursType = byAr['رخصة 48 ساعة']!;
    retraiteType = byAr['التقاعد']!;

    final List<Map<String, Object?>> sts = await db.query(
      Db.statusTypes,
      columns: <String>[Db.cId, Db.cName],
    );
    stSuspendu = sts
        .firstWhere((Map<String, Object?> m) => m[Db.cName] == 'موقوف')[Db.cId]
        as int;
  });

  tearDownAll(() async => closeTestDb(db));

  // ── الحساب قبل الكتابة (قواعد 17 و18) ──────────────────────

  group('A1 المحرّك المستقل', () {
    test('preview يحسب النهاية والعودة ولا يكتب صفّاً', () async {
      final int e = await newEmployee();
      final LeaveCalculationResult r = await repo.preview(
        leaveTypeId: adminType,
        startDate: DateTime(2026, 10, 1),
      );

      expect(AppDate.format(r.endDate), '2026-10-30',
          reason: '30 يوماً تقويمياً محسوبة من الجدول لا من الكود');
      expect(AppDate.format(r.returnDate), '2026-11-01',
          reason: 'النهاية الجمعة → السبت عطلة → الأحد يوم عمل');
      expect(r.countedDuration, 30);
      expect(r.unit, DurationUnit.days);

      final LeavePage page = await repo.search(LeaveFilter(employeeId: e));
      expect(page.total, 0, reason: 'المعاينة لا تكتب في القاعدة');
    });

    test('وحدة الساعات: 48h تنتهي بعد يومين وraw_duration صحيحة', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: hoursType,
        startDate: '2026-10-01',
      );

      expect(l.duration, 48, reason: 'المدة تبقى بالساعات لا تُحوَّل');
      expect(l.durationUnit, Db.unitHours);
      expect(l.rawDuration, '48h');
      expect(l.endDate, '2026-10-02', reason: 'ceil(48/24) = يومان');
      expect(l.returnDate, '2026-10-04', reason: 'السبت عطلة → الأحد');
    });

    test('مدة مُدخلة تغيّر النتيجة (لا قيمة ثابتة في الكود)', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
        duration: 5,
      );

      expect(l.duration, 5);
      expect(l.endDate, '2026-10-05');
      expect(l.returnDate, '2026-10-06');
      expect(l.rawDuration, '5d');
    });

    test('create يملأ JOIN النوع والموظف مع created_at', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-01',
        duration: 3,
        notes: 'شهادة طبية',
      );

      expect(l.id, isNotNull);
      expect(l.leaveTypeName, 'رخصة مرضية');
      expect(l.leaveTypeNameFr, 'Congé maladie');
      expect(l.employeeMatricule, 'L${seq.toString().padLeft(4, '0')}');
      expect(l.employeeName, 'EMP$seq');
      expect(l.notes, 'شهادة طبية');
      expect(l.isCancelled, isFalse);
      expect(l.createdAt, isNotNull);
      expect(l.updatedAt, isNotNull);
    });
  });

  group('A2 رسائل الخطأ (قاعدة 49)', () {
    test('موظف غير موجود → عربية لا خطأ SQLite', () async {
      await expectLater(
        repo.create(employeeId: 999999, leaveTypeId: adminType, startDate: '2026-10-01'),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('الموظف غير موجود'),
          ),
        ),
      );
    });

    test('نوع رخصة غير موجود → عربية', () async {
      final int e = await newEmployee();
      await expectLater(
        repo.create(employeeId: e, leaveTypeId: 999999, startDate: '2026-10-01'),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('نوع الرخصة غير موجود'),
          ),
        ),
      );
    });

    test('مدة صفرية (التقاعد) → رسالة المحرّك لا انهيار', () async {
      final int e = await newEmployee();
      await expectLater(
        repo.create(employeeId: e, leaveTypeId: retraiteType, startDate: '2026-10-01'),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('أكبر من صفر'),
          ),
        ),
      );
    });

    test('تاريخ غير صالح → رسالة عربية', () async {
      final int e = await newEmployee();
      await expectLater(
        repo.create(employeeId: e, leaveTypeId: adminType, startDate: '31/02/2026'),
        throwsA(isA<AppException>()),
      );
    });

    test('فشل الحساب لا يترك نصف صف', () async {
      final int e = await newEmployee();
      await expectLater(
        repo.create(employeeId: e, leaveTypeId: retraiteType, startDate: '2026-10-01'),
        throwsA(isA<AppException>()),
      );
      final LeavePage page = await repo.search(LeaveFilter(employeeId: e));
      expect(page.total, 0);
    });
  });

  // ── التعارض (قاعدة 45 / D-007) ─────────────────────────────

  group('B1 التعارض قبل الكتابة', () {
    test('تداخل رخصتين → ConflictException بقائمة التعارضات', () async {
      final int e = await newEmployee();
      await repo.create(employeeId: e, leaveTypeId: adminType, startDate: '2026-10-01');

      try {
        await repo.create(
          employeeId: e,
          leaveTypeId: maladieType,
          startDate: '2026-10-20',
        );
        fail('كان يجب أن يرفض الحفظ');
      } on ConflictException catch (ex) {
        expect(ex.conflicts, hasLength(1));
        expect(ex.conflicts.first.kind, ConflictKind.leaveVsLeave);
        expect(ex.conflicts.first.overlapStart, '2026-10-20');
        expect(ex.conflicts.first.overlapEnd, '2026-10-30');
        expect(ex.userMessage, contains('Conflict Detected'));
        expect(ex.conflicts.first.message, contains('تعارض'));
      }

      final LeavePage page = await repo.search(LeaveFilter(employeeId: e));
      expect(page.total, 1, reason: 'الرفض يعني بلا كتابة إطلاقاً');
    });

    test('conflictsFor لا يكتب في القاعدة', () async {
      final int e = await newEmployee();
      await repo.create(employeeId: e, leaveTypeId: adminType, startDate: '2026-10-01');

      final LeavePage before = await repo.search(LeaveFilter(employeeId: e));
      final List<DetectedConflict> c = await repo.conflictsFor(
        Leave(employeeId: e, leaveTypeId: maladieType, startDate: '2026-10-25', endDate: '2026-11-05'),
      );
      expect(c, hasLength(1));
      final LeavePage after = await repo.search(LeaveFilter(employeeId: e));
      expect(after.total, before.total, reason: 'الفحص بلا كتابة');
    });

    test('تعارض بلا تداخل → فارغة', () async {
      final int e = await newEmployee();
      await repo.create(employeeId: e, leaveTypeId: adminType, startDate: '2026-10-01');

      final List<DetectedConflict> c = await repo.conflictsFor(
        Leave(employeeId: e, leaveTypeId: maladieType, startDate: '2026-12-01', endDate: '2026-12-20'),
      );
      expect(c, isEmpty);
    });

    test('الموافقة الصريحة تسمح بالحفظ (لا تطبيق تلقائي)', () async {
      final int e = await newEmployee();
      await repo.create(employeeId: e, leaveTypeId: adminType, startDate: '2026-10-01');

      final Leave second = await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-20',
        userConfirmed: true,
      );
      expect(second.id, isNotNull);
      expect(
        (await repo.search(LeaveFilter(employeeId: e))).total,
        2,
        reason: 'القرار للمستخدم بعد قراءة الرسالة',
      );
    });

    test('الرخصة الملغاة لا تُنتج تعارضاً', () async {
      final int e = await newEmployee();
      final Leave l1 = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
      );
      await repo.cancel(l1.id!, reason: 'مسودة');

      final Leave l2 = await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-15',
      );
      expect(l2.id, isNotNull);
    });

    test('رخصة تتداخل مع سجل الوضعيات → leaveVsStatus', () async {
      final int e = await newEmployee();
      await statuses.add(
        employeeId: e,
        statusTypeId: stSuspendu,
        startDate: '2026-11-01',
        endDate: '2026-11-10',
      );

      try {
        await repo.create(
          employeeId: e,
          leaveTypeId: adminType,
          startDate: '2026-11-05',
        );
        fail('كان يجب أن يرفض الحفظ');
      } on ConflictException catch (ex) {
        expect(ex.conflicts.single.kind, ConflictKind.leaveVsStatus);
        expect(ex.conflicts.single.overlapStart, '2026-11-05');
        expect(ex.conflicts.single.overlapEnd, '2026-11-10');
      }
      expect((await repo.search(LeaveFilter(employeeId: e))).total, 0);
    });

    test('التلامس في يوم واحد = تداخل (شمولية)', () async {
      final int e = await newEmployee();
      await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
        duration: 5,
      );

      await expectLater(
        repo.create(employeeId: e, leaveTypeId: maladieType, startDate: '2026-10-05'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('فترتان متجاورتان بلا تداخل → تُحفظ', () async {
      final int e = await newEmployee();
      await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
        duration: 5,
      );
      final Leave b = await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-06',
        duration: 3,
      );
      expect(b.id, isNotNull);
      expect((await repo.search(LeaveFilter(employeeId: e))).total, 2);
    });
  });

  // ── الإلغاء بلا حذف (قاعدة 31 / D-008) ─────────────────────

  group('C1 الإلغاء المنطقي', () {
    test('cancel يُلغِ ولا يحذف — العدد ثابت', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
      );

      await repo.cancel(l.id!, reason: 'استقالة');

      final LeavePage all = await repo.search(
        LeaveFilter(employeeId: e, includeCancelled: true),
      );
      expect(all.total, 1, reason: 'لا DELETE في هذا الملف إطلاقاً');
      final Leave after = (await repo.forEmployee(e, includeCancelled: true)).single;
      expect(after.isCancelled, isTrue);
      expect(after.notes, 'استقالة');
      expect(after.createdAt, l.createdAt, reason: 'التاريخ الأصلي محفوظ');
    });

    test('الملغاة خارج النتائج افتراضياً وداخلها صراحةً', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
      );
      await repo.cancel(l.id!);

      expect((await repo.search(LeaveFilter(employeeId: e))).total, 0);
      expect(
        (await repo.search(LeaveFilter(employeeId: e, includeCancelled: true))).total,
        1,
      );
      expect(await repo.forEmployee(e), isEmpty);
      expect(await repo.forEmployee(e, includeCancelled: true), hasLength(1));
    });

    test('إلغاء مكرر لا يغيّر السبب الأول', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
      );
      await repo.cancel(l.id!, reason: 'الأول');
      await repo.cancel(l.id!, reason: 'الثاني');

      final Leave after = (await repo.forEmployee(e, includeCancelled: true)).single;
      expect(after.notes, 'الأول');
    });

    test('uncancel يعيد الحالة كما كانت', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
      );
      await repo.cancel(l.id!);
      await repo.uncancel(l.id!);

      final Leave after = (await repo.forEmployee(e)).single;
      expect(after.isCancelled, isFalse);
      expect((await repo.search(LeaveFilter(employeeId: e))).total, 1);
    });

    test('cancel لسجل غير موجود → رسالة عربية', () async {
      await expectLater(
        repo.cancel(999999),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('غير موجود'),
          ),
        ),
      );
    });
  });

  // ── التحديث مع إعادة الحساب ─────────────────────────────────

  group('D1 التحديث', () {
    test('تغيير المدة يعيد حساب النهاية والعودة', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
      );
      expect(l.endDate, '2026-10-30');

      final Leave u = await repo.update(l.copyWith(duration: 5));

      expect(u.id, l.id);
      expect(u.duration, 5);
      expect(u.endDate, '2026-10-05', reason: 'المحرّك هو مصدر الحقيقة');
      expect(u.returnDate, '2026-10-06');
      expect(u.createdAt, l.createdAt, reason: 'created_at لا يُستبدل');
    });

    test('التحديث لا ينقل الرخصة لموظف آخر', () async {
      final int e = await newEmployee();
      final Leave l = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
      );

      final Leave u = await repo.update(l.copyWith(employeeId: 999999));
      expect(u.employeeId, e, reason: 'الرخصة مملوكة لموظفها');
      expect(u.employeeMatricule, l.employeeMatricule);
    });

    test('تحديث يجعل الفترة متعارضة → يرفض', () async {
      final int e = await newEmployee();
      await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
        duration: 5,
      );
      final Leave second = await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-20',
        duration: 3,
      );

      await expectLater(
        repo.update(second.copyWith(startDate: '2026-10-03')),
        throwsA(isA<ConflictException>()),
      );
      final Leave? untouched = await repo.byId(second.id!);
      expect(untouched?.startDate, '2026-10-20', reason: 'الرفض بلا كتابة');
    });

    test('تحديث سجل غير محفوظ → رسالة عربية', () async {
      await expectLater(
        repo.update(
          const Leave(
            employeeId: 1,
            leaveTypeId: 1,
            startDate: '2026-10-01',
            endDate: '2026-10-05',
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

  // ── البحث والترقيم (قاعدة 61) ───────────────────────────────

  group('E1 البحث والترقيم', () {
    test('limit/offset/total/hasMore تُحسب في SQL', () async {
      final int e = await newEmployee();
      for (final String d in <String>[
        '2026-10-01',
        '2026-10-10',
        '2026-10-20',
        '2026-11-01',
        '2026-11-10',
      ]) {
        await repo.create(
          employeeId: e,
          leaveTypeId: maladieType,
          startDate: d,
          duration: 5,
        );
      }

      final LeavePage p1 = await repo.search(
        LeaveFilter(employeeId: e),
        limit: 2,
      );
      expect(p1.total, 5);
      expect(p1.items, hasLength(2));
      expect(p1.hasMore, isTrue);
      expect(p1.pageCount, 3);
      expect(p1.items.first.startDate, '2026-11-10', reason: 'الأحدث أولاً');

      final LeavePage p2 = await repo.search(
        LeaveFilter(employeeId: e),
        limit: 2,
        offset: 2,
      );
      expect(p2.items.map((Leave l) => l.startDate).toList(),
          <String>['2026-10-20', '2026-10-10']);

      final LeavePage p3 = await repo.search(
        LeaveFilter(employeeId: e),
        limit: 2,
        offset: 4,
      );
      expect(p3.items, hasLength(1));
      expect(p3.hasMore, isFalse);
    });

    test('فلتر الفترة = التداخل مع النطاق لا البداية بعده', () async {
      final int e = await newEmployee();
      await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-01',
        duration: 5,
      );
      await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-20',
        duration: 5,
      );

      final LeavePage hit = await repo.search(
        LeaveFilter(employeeId: e, from: '2026-10-04', to: '2026-10-06'),
      );
      expect(hit.total, 1, reason: 'التي تنتهي قبل النطاق لا تدخل');
      expect(hit.items.single.startDate, '2026-10-01');

      final LeavePage both = await repo.search(
        LeaveFilter(employeeId: e, from: '2026-10-01', to: '2026-10-31'),
      );
      expect(both.total, 2);
    });

    test('نص حرّ يجد الموظف عبر search_text المطبَّع', () async {
      final int e = await newEmployee();
      await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-01',
        duration: 3,
      );

      final LeavePage hit = await repo.search(
        LeaveFilter(employeeId: e, text: 'emp'),
      );
      expect(hit.total, 1);

      final LeavePage miss = await repo.search(
        LeaveFilter(employeeId: e, text: 'zzzz'),
      );
      expect(miss.total, 0);
    });

    test('نص حرّ يجد ملاحظات الرخصة', () async {
      final int e = await newEmployee();
      await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-01',
        duration: 3,
        notes: 'مرفق محضر المدير العام',
      );
      await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-11-01',
        duration: 3,
      );

      expect(
        (await repo.search(LeaveFilter(employeeId: e, text: 'محضر'))).total,
        1,
      );
      expect(
        (await repo.search(LeaveFilter(employeeId: e, text: 'غيرموجودهنا'))).total,
        0,
        reason: 'لا تطابق جزئي خارج الكلمة',
      );
    });

    test('فلتر النوع والحالة الملغاة معاً', () async {
      final int e = await newEmployee();
      final Leave a = await repo.create(
        employeeId: e,
        leaveTypeId: adminType,
        startDate: '2026-10-01',
        duration: 3,
      );
      await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-11-01',
        duration: 3,
      );
      await repo.cancel(a.id!);

      final LeavePage onlyMaladie = await repo.search(
        LeaveFilter(employeeId: e, leaveTypeId: maladieType),
      );
      expect(onlyMaladie.total, 1);

      final LeavePage withCancelled = await repo.search(
        LeaveFilter(
          employeeId: e,
          leaveTypeId: adminType,
          includeCancelled: true,
        ),
      );
      expect(withCancelled.total, 1);
      expect(withCancelled.items.single.isCancelled, isTrue);
    });

    test('حقل تاريخ غير صالح في الفلتر = بلا قيد لا خطأ', () async {
      final int e = await newEmployee();
      await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-01',
        duration: 3,
      );

      final LeavePage p = await repo.search(
        LeaveFilter(employeeId: e, from: 'ليس تاريخاً', to: '…'),
      );
      expect(p.total, 1, reason: 'مدخل فلتر خاطئ لا يوقف القراءة');
    });
  });

  // ── البيانات المرتبطة ───────────────────────────────────────

  group('F1 العطل والتقييد بالتاريخ', () {
    test('holidays() تعيد النشطة فقط', () async {
      await db.insert(Db.holidays, <String, Object?>{
        Db.cDate: '2026-11-01',
        Db.cNameAr: 'عيد نشط',
        Db.cIsActive: 1,
        Db.cCreatedAt: '2026-01-01T00:00:00.000',
      });
      await db.insert(Db.holidays, <String, Object?>{
        Db.cDate: '2026-11-02',
        Db.cNameAr: 'عيد ملغى',
        Db.cIsActive: 0,
        Db.cCreatedAt: '2026-01-01T00:00:00.000',
      });

      final List<String> dates =
          (await repo.holidays()).map(AppDate.format).toList();
      expect(dates, contains('2026-11-01'));
      expect(dates, isNot(contains('2026-11-02')));
    });

    test('covering تعيد الرخص السارية في التاريخ', () async {
      final int e = await newEmployee();
      await repo.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: '2026-10-01',
        duration: 5,
      );

      expect(await repo.covering(e, '2026-10-01'), hasLength(1), reason: 'البداية');
      expect(await repo.covering(e, '2026-10-05'), hasLength(1), reason: 'النهاية');
      expect(await repo.covering(e, '2026-10-06'), isEmpty);
    });

    test('byId يرجع null لسجل غير موجود', () async {
      expect(await repo.byId(999999), isNull);
    });
  });
}
