import 'dart:convert';

import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/query/search_query.dart';
import 'package:admin_staff/models/employee.dart';
import 'package:admin_staff/repositories/audit_repository.dart';
import 'package:admin_staff/repositories/employee_repository.dart';
import 'package:admin_staff/repositories/reference_repository.dart';
import 'package:admin_staff/services/csv_column_mapper.dart';
import 'package:admin_staff/services/import/csv_import_service.dart';
import 'package:admin_staff/services/import/import_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ استيراد CSV فعلي على SQLite حقيقي.
///
/// الغرض هنا إثبات أن مسار الكتابة الثاني في الإنتاج —
/// خلية الاستيراد — يملأ `search_text` **وبشكل صحيح في الحالتين**:
///  1. إدراج موظف جديد، و
///  2. **تحديث جزئي**: ملف فيه `matricule` فقط، فيجب أن يبقى الاسم
///     العربي المحفوظ دخلاً في نص البحث وإلا اختفى الموظف منه.
void main() {
  late Database db;
  late AppDatabase appDb;
  late EmployeeRepository repo;
  late CsvImportService service;

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    appDb = AppDatabase.fromDatabase(db);
    repo = EmployeeRepository(appDb);
    service = CsvImportService(
      appDb,
      ReferenceRepository(appDb),
      AuditRepository(appDb),
    );
  });

  tearDownAll(() async {
    await closeTestDb(db);
  });

  List<int> bytesOf(String csv) => utf8.encode(csv);

  Future<ImportResult> run(String csv, {ImportMode mode = ImportMode.addNew}) async {
    final ImportPreview p = await service.preview(
      kind: ImportKind.employees,
      bytes: bytesOf(csv),
      fileName: 'test.csv',
      mode: mode,
    );
    return service.commit(p, mode: mode);
  }

  group('استيراد الموظفين: search_text', () {
    test('معاينة لا تكتب في القاعدة', () async {
      final int before = await repo.countAll();
      await service.preview(
        kind: ImportKind.employees,
        bytes: bytesOf('matricule,nom_fr\n8888,TESTER\n'),
        fileName: 'x.csv',
      );
      expect(await repo.countAll(), before, reason: 'المعاينة بلا كتابة');
    });

    test('إدراج جديد يملأ search_text فيجدّ البحث العربي', () async {
      final ImportResult r = await run(
        'matricule,nom_ar,prenom_ar,nom_fr,prenom_fr\n'
        '9001,بن عيسى,أحمد,BEN AISSA,Ahmed\n',
      );
      expect(r.inserted, 1);

      // بحث عربي بلا همزة يجد الاسم المسجّل بالهمزة.
      final EmployeePage byArabic =
          await repo.search(const SearchQuery(text: 'احمد'));
      expect(byArabic.total, 1);
      expect(byArabic.items.single.matricule, '9001');

      // والاسم الفرنسي أيضاً.
      final EmployeePage byFrench =
          await repo.search(const SearchQuery(text: 'ben aissa'));
      expect(byFrench.total, 1);

      // والرقم.
      expect((await repo.search(const SearchQuery(text: '9001'))).total, 1);
    });

    test('قسم جديد يُنشأ بـ search_text فيجدّه البحث', () async {
      final ImportResult r = await run(
        'matricule,nom_fr,section\n'
        '9002,MARTIN,Direction générale\n',
      );
      expect(r.inserted, 1);
      expect(r.referenceEntriesCreated, 1);

      final EmployeePage bySection = await repo.search(
        const SearchQuery(text: 'direction generale'),
      );
      expect(bySection.total, 1, reason: 'قسم جديد + أ + ه');
      expect(bySection.items.single.matricule, '9002');
    });

    test('تحديث جزئي لا يطمس الاسم العربي من search_text', () async {
      // الملف يحوي matricule و nom_fr فقط.
      final ImportResult r = await run(
        'matricule,nom_fr\n'
        '9001,UPDATEDNAME\n',
      );
      expect(r.updated, 1);

      final Employee? after = await repo.findByMatricule('9001');
      expect(after!.nomFr, 'UPDATEDNAME');
      expect(after.nomAr, 'بن عيسى',
          reason: 'الاسم العربي غير الوارد في الملف يبقى كما هو');
      expect(after.prenomAr, 'أحمد');

      // ما زال قابلاً بالبحث العربي (الحقل المتروك لم يُطمس).
      final EmployeePage byArabic =
          await repo.search(const SearchQuery(text: 'احمد'));
      expect(byArabic.total, 1);
      expect(byArabic.items.single.matricule, '9001');

      // والاسم الجديد دخل نص البحث أيضاً.
      expect(
        (await repo.search(const SearchQuery(text: 'updatedname'))).total,
        1,
      );

      // وعمود search_text في القاعدة فعلاً يحوي الحقلين.
      final List<Map<String, Object?>> row = await db.query(
        Db.employees,
        columns: <String>[Db.cSearchText],
        where: '${Db.cMatricule} = ?',
        whereArgs: <Object?>['9001'],
      );
      final String st = row.single[Db.cSearchText] as String;
      expect(st, contains('احمد'), reason: 'الاسم العربي المطبّع محفوظ');
      expect(st, contains('updatedname'), reason: 'الاسم الفرنسي الجديد');
      expect(st, contains('9001'), reason: 'الرقم محفوظ');
    });

    test('الاستيراد لا يمسّ created_at عند التحديث', () async {
      final List<Map<String, Object?>> before = await db.query(
        Db.employees,
        columns: <String>[Db.cCreatedAt],
        where: '${Db.cMatricule} = ?',
        whereArgs: <Object?>['9001'],
      );
      await run('matricule,nom_fr,notes\n9001,UPDATEDNAME,ملاحظة\n');
      final List<Map<String, Object?>> after = await db.query(
        Db.employees,
        columns: <String>[Db.cCreatedAt],
        where: '${Db.cMatricule} = ?',
        whereArgs: <Object?>['9001'],
      );
      expect(after.single[Db.cCreatedAt], before.single[Db.cCreatedAt]);
    });

    test('تكرار matricule داخل الملف الواحد → صف واحد فقط يُكتب', () async {
      final ImportResult r = await run(
        'matricule,nom_fr\n'
        '9003,DUP ONE\n'
        '9003,DUP TWO\n',
      );
      expect(r.inserted, 1, reason: 'الصف الأول فقط');
      expect(r.errors, 1, reason: 'الثاني مرفوض بتكرار في الملف');
      expect(
        (await repo.search(const SearchQuery(text: '9003'))).total,
        1,
      );
    });

    test('استيراد جزئي لموظف موجود لا يمسّ باقي حقوله', () async {
      await run('matricule,nom_fr,notes\n9001,UPDATEDNAME,نهاية\n');

      final Employee? e = await repo.findByMatricule('9001');
      expect(e!.notes, 'نهاية');
      expect(e.prenomFr, 'Ahmed', reason: 'غير وارد → لم يُمسّ');
      expect(e.nomAr, 'بن عيسى', reason: 'غير وارد → لم يُمسّ');
      expect(e.sectionId, isNull, reason: 'لم يكن من أصله');
      expect(e.mobilePhone, isNull);
    });
  });
}
