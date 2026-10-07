import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/models/employee.dart';
import 'package:admin_staff/models/permanence_record.dart';
import 'package:admin_staff/repositories/employee_repository.dart';
import 'package:admin_staff/repositories/permanence_repository.dart';
import 'package:admin_staff/repositories/status_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ اختبارات مستودع المداومة على SQLite حقيقي.
///
/// تغطي: قاعدة 10 / D-010 (المفتاح الفريد التاريخ + الموظف +
/// الفترة)، قاعدة الاستيراد (لا إنشاء موظفين أبداً)، قاعدة 49
/// (رسائل عربية)، وقاعدة 61 (البحث والترقيم داخل SQL).
void main() {
  late Database db;
  late AppDatabase appDb;
  late PermanenceRepository repo;
  late StatusRepository statuses;
  late EmployeeRepository employees;

  int seq = 0;

  Future<int> newEmployee({String? matricule, int? statusId}) async {
    seq++;
    return employees.insert(
      Employee(
        matricule: matricule ?? 'P${seq.toString().padLeft(4, '0')}',
        nomFr: 'KACEM$seq',
        currentStatusId: statusId,
      ),
    );
  }

  Future<int> employeeCount() async {
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM ${Db.employees}');
    return rows.first['c'] as int;
  }

  PermanenceRecord record({
    String date = '2026-10-05',
    String matricule = '999999',
    int? employeeId,
    String? start = '08:00',
    String? end,
    String timeSlot = '',
    String? permanencier,
    String? section,
  }) =>
      PermanenceRecord(
        date: date,
        matricule: matricule,
        employeeId: employeeId,
        startTime: start,
        endTime: end,
        timeSlot: timeSlot,
        permanencier: permanencier,
        section: section,
      );

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    appDb = AppDatabase.fromDatabase(db);
    statuses = StatusRepository(appDb);
    repo = PermanenceRepository(appDb, statuses);
    employees = EmployeeRepository(appDb);
  });

  tearDownAll(() async => closeTestDb(db));

  // ── الإدراج والربط بالمعرّف ─────────────────────────────────

  group('A1 الإدراج والربط', () {
    test('رقم معروف → يرتبط تلقائياً بموظف موجود', () async {
      final int e = await newEmployee(matricule: '10001');

      final PermanenceRecord saved = await repo.insert(
        record(matricule: '10001', employeeId: null),
      );

      expect(saved.employeeId, e, reason: 'المطابقة بالمعرّف لا بالاسم');
      expect(saved.isLinked, isTrue);
      expect(saved.displayName, 'KACEM$seq');
      expect(saved.sectionId, isNull);
    });

    test('رقم مجهول → يبقى غير مطابَق ولا ينشئ موظفاً', () async {
      final int before = await employeeCount();

      final PermanenceRecord saved = await repo.insert(
        record(matricule: '88888', start: '09:00'),
      );

      expect(saved.employeeId, isNull, reason: 'قاعدة الاستيراد: لا إنشاء');
      expect(saved.isLinked, isFalse);
      expect(saved.displayName, '88888', reason: 'يعرض الرقم حتى يُربط');
      expect(await employeeCount(), before, reason: 'عدد الموظفين لم يتغيّر');
      expect(saved.timeSlot, '09:00', reason: 'المفتاح يأتي من start_time');
    });

    test('رقم ترقيم فارغ → رسالة عربية', () async {
      await expectLater(
        repo.insert(record(matricule: '   ')),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('matricule'),
          ),
        ),
      );
    });

    test('تاريخ غير صالح → رسالة عربية لا خطأ SQLite', () async {
      await expectLater(
        repo.insert(record(date: '31/02/2026')),
        throwsA(isA<AppException>()),
      );
    });

    test('تاريخ DD/MM/YYYY يُوحَّد إلى YYYY-MM-DD', () async {
      final PermanenceRecord saved =
          await repo.insert(record(date: '05/11/2026'));
      expect(saved.date, '2026-11-05');
    });

    test('نفس المفتاح مرتين → قيد فريد برسالة مفهومة', () async {
      final int e = await newEmployee(matricule: '10002');
      await repo.insert(
        record(matricule: '10002', employeeId: e, start: '08:00'),
      );

      await expectLater(
        repo.insert(record(matricule: '10002', employeeId: e, start: '08:00')),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('يوجد سجل مداومة'),
          ),
        ),
      );
    });
  });

  // ── المفتاح الفريد D-010 ────────────────────────────────────

  group('B1 المفتاح (التاريخ + الموظف + الفترة)', () {
    test('فترتان مختلفتان لنفس الموظف في اليوم → سجلان', () async {
      final int e = await newEmployee(matricule: '10003');
      await repo.insert(record(matricule: '10003', start: '08:00'));
      await repo.insert(record(matricule: '10003', start: '14:00'));

      final List<PermanenceRecord> all = await repo.forEmployee(e);
      expect(all, hasLength(2), reason: 'الفترة جزء من المفتاح');
      expect(
        all.map((PermanenceRecord r) => r.timeSlot).toSet(),
        <String>{'08:00', '14:00'},
      );
    });

    test('نفس اليوم والفترة لموظفين → سجلان (الفريد على الموظف)', () async {
      final int a = await newEmployee(matricule: '10004');
      final int b = await newEmployee(matricule: '10005');
      await repo.insert(record(matricule: '10004', employeeId: a));
      await repo.insert(record(matricule: '10005', employeeId: b));

      expect(
        (await repo.search(PermanenceFilter(employeeId: a))).total,
        1,
        reason: 'الفريد يُحسب على الموظف لا على اليوم وحده',
      );
      expect((await repo.search(PermanenceFilter(employeeId: b))).total, 1);
    });

    test('upsert مفتاح جديد → created = true', () async {
      final int e = await newEmployee(matricule: '10006');
      final ({int id, bool created}) r = await repo.upsert(
        record(matricule: '10006', employeeId: e, start: '08:30'),
      );
      expect(r.created, isTrue);
      expect(await repo.byId(r.id), isNotNull);
    });

    test('upsert مفتاح موجود → created = false ويحدّث القيم', () async {
      final int e = await newEmployee(matricule: '10007');
      final ({int id, bool created}) first = await repo.upsert(
        record(matricule: '10007', employeeId: e, start: '08:00', section: 'الموارد البشرية'),
      );

      final ({int id, bool created}) second = await repo.upsert(
        record(matricule: '10007', employeeId: e, start: '08:00', section: 'المالية'),
      );

      expect(second.created, isFalse, reason: 'استبدال لا تكرار');
      expect(second.id, first.id, reason: 'نفس السجل يُحدَّث');
      final PermanenceRecord after = (await repo.byId(second.id))!;
      expect(after.section, 'المالية');
      expect(
        (await repo.search(PermanenceFilter(employeeId: e))).total,
        1,
        reason: 'لم يُضاف صف ثانٍ',
      );
    });

    test('upsert غير مطابَق بالمعرّف لا بالمفتاح المحجوز للموظف', () async {
      final int e = await newEmployee(matricule: '10008');
      await repo.insert(record(matricule: '10008', employeeId: e, start: '08:00'));

      // رقم مجهول لنفس التاريخ والفترة → يُدرج ولا يمسّ سجل الموظف.
      final ({int id, bool created}) other = await repo.upsert(
        record(matricule: '77777', start: '08:00'),
      );
      expect(other.created, isTrue);
      expect(
        (await repo.unmatched())
            .any((PermanenceRecord r) => r.matricule == '77777'),
        isTrue,
        reason: 'دخل القائمة دون لمس سجل الموظف',
      );
      expect((await repo.search(PermanenceFilter(employeeId: e))).total, 1);
    });
  });

  // ── الربط اليدوي من شاشة «غير مطابِق» ──────────────────────

  group('C1 الربط اليدوي', () {
    test('link يربط سجلاً غير مطابَق بموظف', () async {
      final PermanenceRecord open = await repo.insert(
        record(matricule: '66666', start: '10:00'),
      );
      expect(open.employeeId, isNull);

      final int e = await newEmployee(matricule: '10009');
      await repo.link(open.id!, e);

      final PermanenceRecord after = (await repo.byId(open.id!))!;
      expect(after.employeeId, e);
      expect(after.isLinked, isTrue);
      expect(
        (await repo.unmatched()).any((PermanenceRecord r) => r.matricule == '66666'),
        isFalse,
        reason: 'خرج من القائمة',
      );
    });

    test('link إلى اليوم والفترة المحجوز لموظف آخر → رسالة تشرح', () async {
      final int a = await newEmployee(matricule: '10010');
      await repo.insert(record(matricule: '10010', employeeId: a, start: '08:00'));

      final PermanenceRecord open = await repo.insert(
        record(matricule: '55555', start: '08:00'),
      );
      // اليوم والفترة محجوزان لـ a — الربط يجب أن يُرفض.
      await expectLater(
        repo.link(open.id!, a),
        throwsA(
          isA<AppException>().having(
            (AppException x) => x.userMessage,
            'userMessage',
            contains('محجوزان'),
          ),
        ),
      );
      expect(
        (await repo.byId(open.id!))?.employeeId,
        isNull,
        reason: 'الرفض بلا تغيير',
      );
    });

    test('link لسجل غير موجود أو موظف غير موجود → عربية', () async {
      final int e = await newEmployee(matricule: '10012');
      await expectLater(
        repo.link(999999, e),
        throwsA(isA<AppException>().having((AppException x) => x.userMessage, 'm', contains('غير موجود'))),
      );
      await expectLater(
        repo.link(1, 999999),
        throwsA(isA<AppException>().having((AppException x) => x.userMessage, 'm', contains('الموظف غير موجود'))),
      );
    });

    test('unlink يفكّ الارتباط ولا يحذف السجل', () async {
      final int e = await newEmployee(matricule: '10013');
      final PermanenceRecord saved = await repo.insert(
        record(matricule: '10013', employeeId: e, start: '11:00'),
      );

      await repo.unlink(saved.id!);

      final PermanenceRecord after = (await repo.byId(saved.id!))!;
      expect(after.employeeId, isNull);
      expect(after.matricule, '10013', reason: 'الرقم الأصلي محفوظ');
      expect(
        (await repo.unmatched())
            .any((PermanenceRecord r) => r.matricule == '10013'),
        isTrue,
      );

      await expectLater(
        repo.unlink(999999),
        throwsA(isA<AppException>()),
      );
    });
  });

  // ── الحذف (مخصص بجدول المواعيد) ────────────────────────────

  group('D1 الحذف واستبدال الفترة', () {
    test('remove يحذف سجلاً واحداً وغير موجود → عربية', () async {
      final PermanenceRecord saved =
          await repo.insert(record(matricule: '44444', start: '12:00'));
      await repo.remove(saved.id!);

      expect(await repo.byId(saved.id!), isNull);
      await expectLater(
        repo.remove(saved.id!),
        throwsA(
          isA<AppException>().having((AppException x) => x.userMessage, 'm', contains('غير موجود')),
        ),
      );
    });

    test('deleteRange يحذف الفترة المحددة فقط ويرجع العدد', () async {
      await repo.insert(record(date: '2026-12-01', matricule: '33331', start: '08:00'));
      await repo.insert(record(date: '2026-12-02', matricule: '33332', start: '08:00'));
      await repo.insert(record(date: '2027-01-15', matricule: '33333', start: '08:00'));

      final int n = await repo.deleteRange('2026-12-01', '2026-12-31');
      expect(n, 2, reason: 'الحذف محصور في الفترة');
      expect(
        (await repo.search(const PermanenceFilter(from: '2027-01-01'))).total,
        1,
        reason: 'ما بعدها سليم',
      );
    });

    test('deleteRange نهاية قبل بداية → عربية بلا حذف', () async {
      await expectLater(
        repo.deleteRange('2026-12-31', '2026-12-01'),
        throwsA(
          isA<AppException>().having((AppException x) => x.userMessage, 'm', contains('تاريخ النهاية')),
        ),
      );
    });
  });

  // ── البحث (قاعدة 61) ────────────────────────────────────────

  group('E1 البحث والترقيم', () {
    test('الترتيب زمني تصاعدي والترقيم داخل SQL', () async {
      final int e = await newEmployee(matricule: '10020');
      for (final String d in <String>['2026-10-03', '2026-10-01', '2026-10-02']) {
        await repo.insert(record(date: d, matricule: '10020', employeeId: e, start: '08:00'));
      }

      final PermanencePage p1 = await repo.search(
        PermanenceFilter(employeeId: e),
        limit: 2,
      );
      expect(p1.total, 3);
      expect(p1.items.map((PermanenceRecord r) => r.date).toList(),
          <String>['2026-10-01', '2026-10-02']);
      expect(p1.hasMore, isTrue);
      expect(p1.pageCount, 2);

      final PermanencePage p2 = await repo.search(
        PermanenceFilter(employeeId: e),
        limit: 2,
        offset: 2,
      );
      expect(p2.items.single.date, '2026-10-03');
      expect(p2.hasMore, isFalse);
    });

    test('فلتر الفترة شمولي على الطرفين', () async {
      await repo.insert(record(date: '2028-03-05', matricule: '20001', start: '08:00'));
      await repo.insert(record(date: '2028-03-06', matricule: '20002', start: '08:00'));
      await repo.insert(record(date: '2028-03-07', matricule: '20003', start: '08:00'));

      final PermanencePage p = await repo.search(
        const PermanenceFilter(from: '2028-03-06', to: '2028-03-06'),
      );
      expect(p.total, 1, reason: 'الطرفان محتسبان ولا شيء خارج النطاق');
      expect(p.items.single.matricule, '20002');
    });

    test('unmatchedOnly يعيد غير المربوطين فقط', () async {
      await repo.insert(record(matricule: '20004', start: '07:00'));
      final int e = await newEmployee(matricule: '10021');
      await repo.insert(record(matricule: '10021', employeeId: e, start: '07:00'));

      final List<PermanenceRecord> open = await repo.unmatched();
      expect(
        open.every((PermanenceRecord r) => r.employeeId == null),
        isTrue,
      );
      expect(
        open.any((PermanenceRecord r) => r.matricule == '20004'),
        isTrue,
      );
      expect(
        open.any((PermanenceRecord r) => r.matricule == '10021'),
        isFalse,
      );
    });

    test('فلتر matricule حرفياً وفلتر section', () async {
      final int e = await newEmployee(matricule: '10022');
      await repo.insert(
        record(matricule: '10022', employeeId: e, start: '08:00', section: 'المحاسبة'),
      );
      await repo.insert(record(matricule: '20005', start: '08:00'));

      final PermanencePage byMat = await repo.search(
        const PermanenceFilter(matricule: '10022'),
      );
      expect(byMat.total, 1);

      final PermanencePage bySec = await repo.search(
        const PermanenceFilter(section: 'المحاسبة'),
      );
      expect(bySec.total, 1);
      expect(bySec.items.single.sectionId, isNull);
    });

    test('نص حرّ يجد الموظف المطبَّع', () async {
      final int e = await newEmployee(matricule: '10023');
      await repo.insert(record(matricule: '10023', employeeId: e, start: '08:00'));

      expect(
        (await repo.search(const PermanenceFilter(text: 'kacem'))).total,
        greaterThanOrEqualTo(1),
        reason: 'search_text للموظف مطابَق عبر JOIN',
      );
      expect(
        (await repo.search(const PermanenceFilter(text: 'zzzz'))).total,
        0,
      );
    });

    test('نص حرّ يجد اسم المداوم لغير المطابَق', () async {
      await repo.insert(
        record(matricule: '20006', start: '08:00', permanencier: 'بنعلي ياسين'),
      );

      final PermanencePage p = await repo.search(
        const PermanenceFilter(text: 'بنعلي'),
      );
      expect(p.total, 1);
      expect(p.items.single.isLinked, isFalse);
    });

    test('حقل تاريخ فلتر غير صالح = بلا قيد لا خطأ', () async {
      final PermanencePage p = await repo.search(
        const PermanenceFilter(from: 'ليس تاريخاً'),
      );
      expect(p.total, greaterThanOrEqualTo(0), reason: 'لا استثناء');
    });
  });

  // ── القراءة المتخصصة ────────────────────────────────────────

  group('F1 forDate و matchMatricules', () {
    test('forDate يملأ اسم الموظف والوضعية المشتقة دفعة واحدة', () async {
      final int st = (await db.query(
        Db.statusTypes,
        columns: <String>[Db.cId, Db.cName],
        where: '${Db.cName} = ?',
        whereArgs: <Object?>['في الخدمة'],
      )).single[Db.cId] as int;

      final int e = await newEmployee(matricule: '10030', statusId: st);
      await repo.insert(
        record(date: '2026-10-06', matricule: '10030', employeeId: e, start: '08:00'),
      );
      await repo.insert(record(date: '2026-10-06', matricule: '20007', start: '08:00'));

      final List<PermanenceRecord> day = await repo.forDate('2026-10-06');
      expect(day, hasLength(2));

      final PermanenceRecord linked =
          day.firstWhere((PermanenceRecord r) => r.isLinked);
      expect(linked.derivedStatusName, 'في الخدمة',
          reason: 'اشتقاق واحد لكامل اليوم لا صفّاً صفّاً');
      expect(linked.employeeNameFr, 'KACEM$seq');

      final PermanenceRecord open =
          day.firstWhere((PermanenceRecord r) => !r.isLinked);
      expect(open.derivedStatusName, isNull, reason: 'غير مربوط بلا وضعية');
    });

    test('forDate باليوم بلا سجلات → قائمة فارغة بلا خطأ', () async {
      expect(await repo.forDate('2026-12-25'), isEmpty);
    });

    test('matchMatricules ترجع المعروفين فقط بلا قيد على التفعيل', () async {
      final int active = await newEmployee(matricule: '10031');
      final int inactive = await newEmployee(matricule: '10032');
      await employees.deactivate(inactive);

      final Map<String, int> m = await repo.matchMatricules(
        <String>['10031', '10032', '00000', '  ', '10031'],
      );

      expect(m['10031'], active);
      expect(m['10032'], inactive, reason: 'سجل تاريخي يرتبط بصاحبه');
      expect(m.containsKey('00000'), isFalse, reason: 'غير معروف لا يُنشأ');
      expect(m.length, 2, reason: 'الأرقام المكررة تُدمج');
    });
  });
}
