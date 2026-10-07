import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/utils/app_date.dart';
import 'package:admin_staff/models/employee.dart';
import 'package:admin_staff/models/leave.dart';
import 'package:admin_staff/models/permanence_record.dart';
import 'package:admin_staff/repositories/dashboard_repository.dart';
import 'package:admin_staff/repositories/employee_repository.dart';
import 'package:admin_staff/repositories/leave_repository.dart';
import 'package:admin_staff/repositories/permanence_repository.dart';
import 'package:admin_staff/repositories/reference_repository.dart';
import 'package:admin_staff/repositories/status_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ اختبارات مستودع اللوحة على SQLite حقيقي.
///
/// كل اختبار يفتح قاعدة **في الذاكرة جديدة** لأن اللوحة تعدّ
/// عدّاً عامّاً للقاعدة كلها — العدّ المتراكم بين الاختبارات
/// سيُخفي الخطأ بدل أن يكشفه.
///
/// تغطي: قاعدة 17 (لا رقم مُثبَّت — كل الأرقام من الجداول)،
/// قاعدة 44/D-006 (الاشتقاق قبل العدّ)، وقاعدة 45 (التعارض
/// يُعدّ تنبيهاً ولا يُطبَّق).
void main() {
  late Database db;
  late AppDatabase appDb;
  late DashboardRepository repo;
  late StatusRepository statuses;
  late EmployeeRepository employees;
  late LeaveRepository leaves;
  late PermanenceRepository permanence;

  final DateTime today = AppDate.today();
  String iso(DateTime d) => AppDate.format(d);
  String isoAdd(int days) => iso(AppDate.addDays(today, days));

  int seq = 0;

  Future<int> newEmployee({int? statusId, int? sectionId}) async {
    seq++;
    return employees.insert(
      Employee(
        matricule: 'D${seq.toString().padLeft(4, '0')}',
        nomFr: 'EMP$seq',
        currentStatusId: statusId,
        sectionId: sectionId,
      ),
    );
  }

  Future<int> idOf(String table, String column, String value) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      columns: <String>[Db.cId],
      where: '$column = ?',
      whereArgs: <Object?>[value],
      limit: 1,
    );
    return rows.single[Db.cId] as int;
  }

  int sumOf(Map<int, int> tally) =>
      tally.values.fold<int>(0, (int a, int b) => a + b);

  // معرّفات من الـ seed (مُبحث عنها بالاسم لا بالرقم).
  late int stService;
  late int stSuspendu;
  late int stAdmin;
  late int stExceptional;
  late int maladieType;

  setUp(() async {
    await setUpFfi();
    db = await openTestDb();
    appDb = AppDatabase.fromDatabase(db);
    statuses = StatusRepository(appDb);
    repo = DashboardRepository(appDb, statuses);
    employees = EmployeeRepository(appDb);
    leaves = LeaveRepository(appDb, statuses);
    permanence = PermanenceRepository(appDb, statuses);
    seq = 0;

    stService = await idOf(Db.statusTypes, Db.cName, 'في الخدمة');
    stSuspendu = await idOf(Db.statusTypes, Db.cName, 'موقوف');
    stAdmin = await idOf(Db.statusTypes, Db.cName, 'عطلة إدارية');
    stExceptional = await idOf(Db.statusTypes, Db.cName, 'رخصة استثنائية');
    maladieType = await idOf(Db.leaveTypes, Db.cNameAr, 'رخصة مرضية');
  });

  tearDown(() async => closeTestDb(db));

  // ── البداية ──────────────────────────────────────────────────

  group('A1 قاعدة فارغة', () {
    test('لقطة فارغة = كل الأرقام صفر بلا استثناء', () async {
      final DashboardSummary s = await repo.summary(on: iso(today));

      expect(s.date, iso(today));
      expect(s.totalEmployees, 0);
      expect(s.archivedCount, 0);
      expect(s.statusCounts, isEmpty);
      expect(s.ambiguousCount, 0);
      expect(s.todaysPermanence, 0);
      expect(s.unmatchedToday, 0);
      expect(s.leavesEndingToday, 0);
      expect(s.leavesEndingTomorrow, 0);
      expect(s.leavesEndingIn3Days, 0);
      expect(s.returningToday, 0);
      expect(s.alerts, 0);
      expect(s.hasNoPermanenceToday, isTrue);
      expect(s.hasNoAlerts, isTrue);
    });

    test('summary() بلا تاريخ = اليوم', () async {
      expect((await repo.summary()).date, iso(today));
    });
  });

  // ── الموظفون ─────────────────────────────────────────────────

  group('B1 الموظفون', () {
    test('النشطون والمعطَّلون من الاستعلام نفسه', () async {
      await newEmployee();
      await newEmployee();
      await newEmployee();
      final int archived = await newEmployee();
      await employees.deactivate(archived);

      final DashboardSummary s = await repo.summary(on: iso(today));
      expect(s.totalEmployees, 3);
      expect(s.archivedCount, 1, reason: 'المعطَّل معدود ولا يظهر في التفاصيل');
    });
  });

  // ── الوضعيات المشتقة ─────────────────────────────────────────

  group('C1 الوضعيات المشتقة', () {
    test('التجميع يغطي كل النشطين ولا يدخل المعطَّلين', () async {
      await newEmployee(statusId: stService);
      await newEmployee(statusId: stService);
      await newEmployee(statusId: stSuspendu);
      await newEmployee(); // بلا وضعية إطلاقاً
      final int archived = await newEmployee(statusId: stService);
      await employees.deactivate(archived);

      final DashboardSummary s = await repo.summary(on: iso(today));

      expect(s.totalEmployees, 4);
      expect(s.statusCounts[stService], 2);
      expect(s.statusCounts[stSuspendu], 1);
      expect(s.statusCounts[0], 1, reason: 'بلا وضعية = المفتاح 0');
      expect(sumOf(s.statusCounts), 4,
          reason: 'الاشتقاق والتجميع والتغطية كلها للعدد نفسه');
      expect(s.ambiguousCount, 0);
    });

    test('topStatuses ترتيب من البيانات وothersCount يكمل المجموع', () async {
      await newEmployee(statusId: stService);
      await newEmployee(statusId: stService);
      await newEmployee(statusId: stSuspendu);
      await newEmployee(); // بلا وضعية

      final DashboardSummary s = await repo.summary(on: iso(today));

      final List<MapEntry<int, int>> top = s.topStatuses(1);
      expect(top.single.key, stService, reason: 'الأكثر عدداً أولاً');
      expect(top.single.value, 2);
      expect(s.othersCount(1), 2);
      expect(s.othersCount(10), 0, reason: 'كل الوضعيات داخل القائمة');

      // تعادل العدد → رقم الوضعية الصغير أولاً (ثابت لا عشوائي).
      expect(
        s.topStatuses(4).map((MapEntry<int, int> e) => e.key).toList(),
        <int>[stService, 0, stSuspendu],
      );
    });

    test('اشتقاق يوم آخر لا يختلط باشتقاق اليوم', () async {
      final int e = await newEmployee();
      await statuses.add(
        employeeId: e,
        statusTypeId: stService,
        startDate: isoAdd(-10),
        endDate: isoAdd(-2),
      );
      await statuses.add(
        employeeId: e,
        statusTypeId: stSuspendu,
        startDate: isoAdd(-1),
        endDate: null,
      );

      final DashboardSummary past =
          await repo.summary(on: isoAdd(-5));
      final DashboardSummary now = await repo.summary(on: iso(today));

      expect(past.statusCounts[stService], 1,
          reason: 'سابقاً كان في الخدمة');
      expect(now.statusCounts[stSuspendu], 1, reason: 'اليوم موقوف');
      expect(now.statusCounts[stService], isNull);
    });
  });

  // ── التنبيهات (قاعدة 45) ─────────────────────────────────────

  group('D1 التنبيهات', () {
    test('تعادل أولوية داخل المصدر نفسه → تنبيه بلا تطبيق', () async {
      final int e = await newEmployee();
      // العددان متساويان (20) وبنفس المصدر → تعادل مقصود.
      await statuses.add(
        employeeId: e,
        statusTypeId: stAdmin,
        startDate: isoAdd(-10),
      );
      await statuses.add(
        employeeId: e,
        statusTypeId: stExceptional,
        startDate: isoAdd(-10),
      );

      final DashboardSummary s = await repo.summary(on: iso(today));

      expect(s.ambiguousCount, 1);
      expect(s.alerts, 1);
      expect(sumOf(s.statusCounts), 1,
          reason: 'المعضوم يُحسب مرة واحدة لا مرتين');
    });

    test('مداومة غير مربوطة تنضاف إلى التنبيهات', () async {
      await permanence.insert(
        PermanenceRecord(date: iso(today), matricule: '88888'),
      );

      final DashboardSummary s = await repo.summary(on: iso(today));

      expect(s.todaysPermanence, 1);
      expect(s.unmatchedToday, 1);
      expect(s.ambiguousCount, 0);
      expect(s.alerts, 1);
      expect(s.hasNoAlerts, isFalse);
    });
  });

  // ── المداومة ─────────────────────────────────────────────────

  group('E1 المداومة', () {
    test('عدّ اليوم لا يشمل الأيام الأخرى', () async {
      final int e = await newEmployee();
      await permanence.insert(
        PermanenceRecord(
          date: iso(today),
          matricule: 'D0001',
          employeeId: e,
          startTime: '08:00',
        ),
      );
      await permanence.insert(
        PermanenceRecord(
          date: isoAdd(1),
          matricule: 'D0001',
          employeeId: e,
          startTime: '08:00',
        ),
      );
      await permanence.insert(
        PermanenceRecord(
          date: isoAdd(-1),
          matricule: '77777',
          startTime: '08:00',
        ),
      );

      final DashboardSummary s = await repo.summary(on: iso(today));
      expect(s.todaysPermanence, 1);
      expect(s.unmatchedToday, 0, reason: 'غير المربوط ليس من اليوم');
      expect(s.hasNoPermanenceToday, isFalse);
    });
  });

  // ── الرخص ────────────────────────────────────────────────────

  group('F1 الرخص', () {
    test('الرخص المنتهية اليوم/غداً/بعد 3 أيام في لقطة واحدة', () async {
      final int e1 = await newEmployee();
      final int e2 = await newEmployee();
      final int e3 = await newEmployee();

      // كل رخصة منفردة بموظفها — لا تعارض بينها.
      await leaves.create(
        employeeId: e1,
        leaveTypeId: maladieType,
        startDate: isoAdd(-4), // تنتهي اليوم
        duration: 5,
      );
      await leaves.create(
        employeeId: e2,
        leaveTypeId: maladieType,
        startDate: isoAdd(-3), // تنتهي غداً
        duration: 5,
      );
      await leaves.create(
        employeeId: e3,
        leaveTypeId: maladieType,
        startDate: isoAdd(-1), // تنتهي بعد 3 أيام
        duration: 5,
      );

      final DashboardSummary s = await repo.summary(on: iso(today));
      expect(s.leavesEndingToday, 1);
      expect(s.leavesEndingTomorrow, 1);
      expect(s.leavesEndingIn3Days, 1);
    });

    test('الرخص الملغاة لا تُعدّ إطلاقاً', () async {
      final int e = await newEmployee();
      final Leave l = await leaves.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: isoAdd(-4),
        duration: 5,
      );
      await leaves.cancel(l.id!, reason: 'مسودة');

      final DashboardSummary s = await repo.summary(on: iso(today));
      expect(s.leavesEndingToday, 0);
      expect(s.returningToday, 0);
    });

    test('return_date = اليوم تُعدّ مهما كان يوم الأسبوع', () async {
      final int e = await newEmployee();
      final Leave l = await leaves.create(
        employeeId: e,
        leaveTypeId: maladieType,
        startDate: isoAdd(-4),
        duration: 5,
      );
      expect(l.endDate, iso(today), reason: '5 أيام تقويمياً من تاريخ البداية');

      // حساب تاريخ العودة مُختبر في leave_repository_test؛ هنا نضبط
      // القيمة لأن «اليوم» قد يقع في عطلة نهاية الأسبوع فلا يمكن
      // أن يكون «أول يوم عمل».
      await db.update(
        Db.leaves,
        <String, Object?>{Db.cReturnDate: iso(today)},
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[l.id],
      );

      final DashboardSummary s = await repo.summary(on: iso(today));
      expect(s.returningToday, 1);
      expect(s.leavesEndingToday, 1, reason: 'نفس الرخصة تنتهي اليوم أيضاً');
    });
  });

  // ── التجميع حسب القسم ────────────────────────────────────────

  group('G1 bySection', () {
    test('تجميع حسب القسم يستبعد المعطَّلين ويراعي «بلا قسم»', () async {
      // الـ seed لا يزرع أقساماً — هي بيانات المديرية الحقيقية
      // التي تصل بالـ CSV — فننشئها هنا كما تنشئها الواجهة.
      final ReferenceRepository refs = ReferenceRepository(appDb);
      final int s1 = await refs.createEntry(
        Db.sections,
        'RH',
        nameAr: 'الموارد البشرية',
      );
      final int s2 = await refs.createEntry(
        Db.sections,
        'FIN',
        nameAr: 'المالية',
      );
      expect(s1, isNot(s2), reason: 'قسمان مختلفان فعلاً');

      await newEmployee(sectionId: s1);
      await newEmployee(sectionId: s1);
      await newEmployee(sectionId: s2);
      await newEmployee(); // بلا قسم
      final int archived = await newEmployee(sectionId: s2);
      await employees.deactivate(archived);

      final List<({int? sectionId, String name, int count})> byActive =
          await repo.bySection();

      expect(byActive, hasLength(3), reason: 'قسمان + بلا قسم');
      expect(byActive.first.sectionId, s1);
      expect(byActive.first.count, 2, reason: 'الأكثر عدداً أولاً');
      expect(
        byActive.map((({int? sectionId, String name, int count}) r) => r.count),
        <int>[2, 1, 1],
        reason: 'المعطَّل خارج العدّ',
      );
      expect(
        byActive.any((({int? sectionId, String name, int count}) r) =>
            r.sectionId == s1),
        isTrue,
      );
      expect(
        byActive.where((({int? sectionId, String name, int count}) r) => r.count == 0),
        isEmpty,
        reason: 'القسم بلا موظفين نشطين لا يظهر',
      );

      final List<({int? sectionId, String name, int count})> all =
          await repo.bySection(activeOnly: false);
      expect(
        all.firstWhere((({int? sectionId, String name, int count}) r) =>
                r.sectionId == s2)
            .count,
        2,
        reason: 'التقرير التاريخي يعدّ الجميع حين يُطلب',
      );
    });
  });
}
