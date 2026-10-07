import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/core/query/search_query.dart';
import 'package:admin_staff/models/saved_filter.dart';
import 'package:admin_staff/repositories/filter_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ اختبارات مستودع الفلاتر المحفوظة — جدول `saved_filters` (§10).
///
/// تغطي: الإنشاء/التحديث حسب المعرّف، الاسم الفريد العالمي
/// (الذي يفرضه `uq_saved_filter_name`)، حفظ الاستعلام كاملاً
/// (نص + معايير متداخلة D-018 + `logic` كعمود مستقل)، تحمّل صفّ
/// تالف، والحذف.
void main() {
  late Database db;
  late FilterRepository repo;

  SearchQuery textQuery(String text) => SearchQuery(text: text);

  /// كل اختبار يبدأ من جدول فارغ — لا اعتماد على ترتيب المجموعات.
  /// الحذف بـ SQL لا عبر المسترد: صفوف D1 التالفة لا تظهر في
  /// `all()` ولا يُفترض أن تضلّ بعد الاختبار.
  Future<void> clearAll() => db.delete(Db.savedFilters);

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    repo = FilterRepository(AppDatabase.fromDatabase(db));
  });

  setUp(clearAll);

  tearDownAll(() async => closeTestDb(db));

  group('A1 الإنشاء والقراءة', () {
    test('add يمنحه معرّفاً من الجدول ويحفظ ويظهر في all()', () async {
      final SavedFilter f = await repo.add(
        name: '   موظفو الدائرة الأولى   ',
        kind: SavedFilterKind.employees,
        query: textQuery('ahmed'),
      );

      expect(f.id, greaterThan(0));
      expect(f.isNew, isFalse);
      expect(f.name, 'موظفو الدائرة الأولى', reason: 'الاسم يُقصّ عند الحفظ');
      expect(f.createdAt, isNotNull);
      expect(f.updatedAt, isNotNull);

      final List<SavedFilter> all = await repo.all();
      expect(all, hasLength(1));
      expect(all.single.id, f.id);
      expect(await repo.count(), 1);
    });

    test('الصفّ في الجدول بمخططه §10 (criteria + logic منفصلان)', () async {
      final SavedFilter f = await repo.add(
        name: 'قيد-جدولي',
        kind: SavedFilterKind.permanence,
        query: const SearchQuery(
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.dateFrom,
                operator: FilterOperator.gte,
                value: '2026-01-01',
              ),
            ],
            logic: FilterLogic.or,
          ),
        ),
      );

      final List<Map<String, Object?>> rows = await db.query(
        Db.savedFilters,
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[f.id],
      );
      final Map<String, Object?> row = rows.single;

      expect(row[Db.cName], 'قيد-جدولي');
      expect(row[Db.cLogic], 'OR',
          reason: 'منطق المجموعة العليا عمود مستقل لا داخل JSON');
      expect(row[Db.cCriteria] as String, contains('permanence'));
      expect(row[Db.cCriteria] as String, contains('date_from'));
      expect(row[Db.cCreatedAt], isNotNull);
      expect(row[Db.cUpdatedAt], isNotNull);
    });

    test('الاستعلام يعود كما هو (نص + معايير متداخلة + سجل)', () async {
      const FilterCriterion criterion = FilterCriterion(
        field: FilterField.section,
        operator: FilterOperator.eq,
        value: '7',
      );
      const SearchQuery query = SearchQuery(
        text: '  ',
        includeInactive: true,
        filters: FilterSet(
          criteria: <FilterCriterion>[
            FilterCriterion.group(
              FilterSet(
                criteria: <FilterCriterion>[criterion],
                logic: FilterLogic.or,
              ),
            ),
          ],
        ),
      );

      final SavedFilter saved = await repo.add(
        name: 'شامل',
        kind: SavedFilterKind.employees,
        query: query,
      );
      final SavedFilter? read = await repo.byId(saved.id);

      expect(read, isNotNull);
      expect(read!.kind, SavedFilterKind.employees);
      expect(read.query.includeInactive, isTrue);
      expect(read.query.filters.logic, FilterLogic.and);
      expect(read.query.filters.criteria.single.isGroup, isTrue);

      final FilterSet inner = read.query.filters.criteria.single.group!;
      expect(inner.logic, FilterLogic.or);
      expect(inner.criteria.single, criterion,
          reason: 'المعيار المعاود يساوي الأصلي بالكامل');
    });

    test('البيانات في القاعدة لا في الذاكرة', () async {
      await repo.add(
        name: 'persist',
        kind: SavedFilterKind.employees,
        query: textQuery('x'),
      );

      final FilterRepository other =
          FilterRepository(AppDatabase.fromDatabase(db));
      expect(await other.count(), 1);
      expect((await other.all()).single.name, 'persist');
    });

    test('مفتاح غير موجود → null بلا استثناء', () async {
      expect(await repo.byId(9999), isNull);
      expect(await repo.all(), isEmpty);
    });
  });

  group('A2 التحقق من المدخلات', () {
    test('اسم فارغ → AppException عربية ولا يُكتب شيء', () async {
      await expectLater(
        repo.add(
          name: '   ',
          kind: SavedFilterKind.employees,
          query: textQuery('x'),
        ),
        throwsA(isA<AppException>()),
      );
      expect(await repo.count(), 0);
    });

    test('فلتر بلا نص وبلا معايير → رسالة «فلتر فارغ»', () async {
      Object? err;
      try {
        await repo.add(
          name: 'فارغ',
          kind: SavedFilterKind.employees,
          query: const SearchQuery(),
        );
      } on AppException catch (e) {
        err = e;
      }

      expect(err, isA<AppException>());
      expect((err! as AppException).userMessage, contains('فارغ'));
      expect(await repo.count(), 0);
    });

    test('الاسم فريد عالمياً — حتى بين الشاشات المختلفة', () async {
      await repo.add(
        name: 'المداومة اليومية',
        kind: SavedFilterKind.permanence,
        query: textQuery('lundi'),
      );
      expect(await repo.count(), 1);

      await expectLater(
        repo.add(
          name: '  المداومة اليومية ',
          kind: SavedFilterKind.permanence,
          query: textQuery('mardi'),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.add(
          name: 'المداومة اليومية',
          kind: SavedFilterKind.leaves,
          query: textQuery('mardi'),
        ),
        throwsA(isA<AppException>()),
        reason: 'uq_saved_filter_name يغطي الجدول كله',
      );
      expect(await repo.count(), 1, reason: 'المرفوض لا يترك أثراً');
    });

    test('حالة أحرف مختلفة تعدّ تكراراً أيضاً', () async {
      await repo.add(
        name: 'Alpha',
        kind: SavedFilterKind.employees,
        query: textQuery('a'),
      );
      await expectLater(
        repo.add(
          name: 'ALPHA',
          kind: SavedFilterKind.leaves,
          query: textQuery('b'),
        ),
        throwsA(isA<AppException>()),
      );
      expect(await repo.count(), 1);
    });
  });

  group('B1 التحديث وإعادة التسمية', () {
    test('save بنفس المعرّف يحدّث ولا يكرّر', () async {
      final SavedFilter f = await repo.add(
        name: 'الأول',
        kind: SavedFilterKind.leaves,
        query: textQuery('a'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      final SavedFilter updated = await repo.save(
        f.copyWith(name: 'الأول معدَّل', query: textQuery('b')),
      );

      expect(updated.id, f.id);
      expect(updated.createdAt, f.createdAt,
          reason: 'تاريخ الإنشاء لا يتغيّر عند التحديث');
      expect(updated.updatedAt, isNot(f.updatedAt));

      expect(await repo.count(), 1, reason: 'لا تكرار');
      expect((await repo.all()).single.name, 'الأول معدَّل');
      expect((await repo.all()).single.query.text, 'b');
    });

    test('rename يغيّر الاسم ويحفظ المعرّف', () async {
      final SavedFilter f = await repo.add(
        name: 'قبل',
        kind: SavedFilterKind.employees,
        query: textQuery('q'),
      );

      final SavedFilter renamed = await repo.rename(f.id, '  بعد  ');
      expect(renamed.name, 'بعد');
      expect(renamed.id, f.id);

      final List<SavedFilter> all = await repo.all();
      expect(all, hasLength(1));
      expect(all.single.name, 'بعد');
    });

    test('rename باسم فارغ أو مكرر أو معرّف مفقود → AppException', () async {
      final SavedFilter a = await repo.add(
        name: 'أ',
        kind: SavedFilterKind.employees,
        query: textQuery('a'),
      );
      final SavedFilter b = await repo.add(
        name: 'ب',
        kind: SavedFilterKind.employees,
        query: textQuery('b'),
      );

      await expectLater(repo.rename(a.id, '   '), throwsA(isA<AppException>()));
      await expectLater(repo.rename(a.id, b.name), throwsA(isA<AppException>()));
      await expectLater(repo.rename(9999, 'أي'), throwsA(isA<AppException>()));

      final List<SavedFilter> all = await repo.all();
      expect(all, hasLength(2), reason: 'لا شيء تغيّر في المسارات الفاشلة');
      expect(all.firstWhere((SavedFilter f) => f.id == a.id).name, 'أ');
    });

    test('إعادة التسمية إلى الاسم نفسه بعد التصحيح مقبولة', () async {
      final SavedFilter f = await repo.add(
        name: 'مفضّل',
        kind: SavedFilterKind.employees,
        query: textQuery('x'),
      );

      final SavedFilter same = await repo.save(
        f.copyWith(name: '  مفضّل  ', query: textQuery('y')),
      );
      expect(same.id, f.id);
      expect(await repo.count(), 1);
    });
  });

  group('C1 الحذف والاستعلام', () {
    test('remove يحذف فعلاً وبغير موجود → AppException', () async {
      final SavedFilter a = await repo.add(
        name: 'a',
        kind: SavedFilterKind.employees,
        query: textQuery('a'),
      );
      final SavedFilter b = await repo.add(
        name: 'b',
        kind: SavedFilterKind.employees,
        query: textQuery('b'),
      );

      await repo.remove(a.id);
      expect(await repo.byId(a.id), isNull);
      expect(await repo.count(), 1);
      expect(await repo.byId(b.id), isNotNull);

      await expectLater(repo.remove(a.id), throwsA(isA<AppException>()));
      await expectLater(repo.remove(9999), throwsA(isA<AppException>()));
      expect(await repo.count(), 1);
    });

    test('forKind لا يخلط الشاشات', () async {
      await repo.add(
          name: 'E-1', kind: SavedFilterKind.employees, query: textQuery('e'));
      await repo.add(
          name: 'E-2', kind: SavedFilterKind.employees, query: textQuery('e'));
      await repo.add(
          name: 'L-1', kind: SavedFilterKind.leaves, query: textQuery('l'));
      await repo.add(
          name: 'L-2', kind: SavedFilterKind.leaves, query: textQuery('l'));
      await repo.add(
          name: 'P-1', kind: SavedFilterKind.permanence, query: textQuery('p'));
      expect(await repo.count(), 5);

      expect(await repo.forKind(SavedFilterKind.employees), hasLength(2));
      expect(await repo.forKind(SavedFilterKind.leaves), hasLength(2));
      expect(await repo.forKind(SavedFilterKind.permanence), hasLength(1));

      for (final SavedFilterKind kind in SavedFilterKind.values) {
        final List<SavedFilter> items = await repo.forKind(kind);
        expect(items.every((SavedFilter f) => f.kind == kind), isTrue,
            reason: 'لا يدخل من نوع آخر');
      }
    });

    test('الترتيب أبجدي غير حساس لحالة الأحرف', () async {
      await repo.add(
          name: 'charlie', kind: SavedFilterKind.employees, query: textQuery('c'));
      await repo.add(
          name: 'Alpha', kind: SavedFilterKind.employees, query: textQuery('a'));
      await repo.add(
          name: 'bravo', kind: SavedFilterKind.employees, query: textQuery('b'));

      expect(
        (await repo.all()).map((SavedFilter f) => f.name).toList(growable: false),
        <String>['Alpha', 'bravo', 'charlie'],
      );
    });
  });

  group('D1 صفّ تالف لا يُسقط القائمة', () {
    test('صف بمعايير تالفة يُتجاهَل والصف السليم يُقرأ', () async {
      await db.insert(Db.savedFilters, <String, Object?>{
        Db.cName: 'سليم',
        Db.cCriteria:
            '{"kind":"employees","text":"x","include_inactive":false,"criteria":[]}',
        Db.cLogic: 'AND',
        Db.cCreatedAt: 'now',
        Db.cUpdatedAt: 'now',
      });
      final int badJsonId = await db.insert(Db.savedFilters, <String, Object?>{
        Db.cName: 'تالف-JSON',
        Db.cCriteria: 'ليست JSON أصلاً',
        Db.cLogic: 'AND',
        Db.cCreatedAt: 'now',
        Db.cUpdatedAt: 'now',
      });
      await db.insert(Db.savedFilters, <String, Object?>{
        Db.cName: 'تالف-صيغة',
        Db.cCriteria: '{"kind":"employees","criteria":"ليست قائمة"}',
        Db.cLogic: 'AND',
        Db.cCreatedAt: 'now',
        Db.cUpdatedAt: 'now',
      });
      await db.insert(Db.savedFilters, <String, Object?>{
        Db.cName: 'تالف-نوع',
        Db.cCriteria: '{"kind":"مجهول","criteria":[]}',
        Db.cLogic: 'AND',
        Db.cCreatedAt: 'now',
        Db.cUpdatedAt: 'now',
      });
      await db.insert(Db.savedFilters, <String, Object?>{
        Db.cName: '',
        Db.cCriteria: '{"kind":"employees","criteria":[]}',
        Db.cLogic: 'AND',
        Db.cCreatedAt: 'now',
        Db.cUpdatedAt: 'now',
      });

      final int rows = (await db.rawQuery(
        'SELECT COUNT(*) c FROM ${Db.savedFilters}',
      ))
          .first['c'] as int;
      expect(rows, 5);

      final List<SavedFilter> items = await repo.all();
      expect(items.map((SavedFilter f) => f.name).toList(), <String>['سليم'],
          reason: 'أربعة تالفة تُتجاهَل وواحد يُقرأ');

      expect(await repo.byId(items.first.id), isNotNull);
      expect(await repo.byId(badJsonId), isNull,
          reason: 'الصفّ التالف لا يُقرأ ولو طلبناه بالتحديد');
    });

    test('كل الصفوف تالفة → قائمة فارغة لا استثناء', () async {
      final int badId = await db.insert(Db.savedFilters, <String, Object?>{
        Db.cName: 'فقط',
        Db.cCriteria: '',
        Db.cLogic: 'AND',
        Db.cCreatedAt: 'now',
        Db.cUpdatedAt: 'now',
      });

      expect(await repo.all(), isEmpty);
      expect(await repo.byId(badId), isNull);
      expect(await repo.count(), 1,
          reason: 'العدّ يقرأ الصفوف كما هي ولا يفرّي الجدول');
    });
  });

  group('E1 الكتابة المتوازية', () {
    test('طلبات متوازية لا تفقد بعضها', () async {
      final List<Future<SavedFilter>> pending =
          List<Future<SavedFilter>>.generate(
        8,
        (int i) => repo.add(
          name: 'f$i',
          kind: SavedFilterKind.employees,
          query: textQuery('q$i'),
        ),
      );
      final List<SavedFilter> saved = await Future.wait(pending);

      expect(saved.map((SavedFilter f) => f.id).toSet(), hasLength(8),
          reason: 'AUTOINCREMENT لا يمنح معرّفين متطابقين');
      expect(await repo.count(), 8);
      expect(
        (await repo.all()).map((SavedFilter f) => f.name).toSet(),
        <String>{for (int i = 0; i < 8; i++) 'f$i'},
      );
    });

    test('عملية تفشل لا توقف ما بعدها', () async {
      await repo.add(
        name: 'dup',
        kind: SavedFilterKind.employees,
        query: textQuery('x'),
      );

      await expectLater(
        repo.add(
          name: 'dup',
          kind: SavedFilterKind.employees,
          query: textQuery('y'),
        ),
        throwsA(isA<AppException>()),
      );

      final SavedFilter next = await repo.add(
        name: 'بعد-الفشل',
        kind: SavedFilterKind.leaves,
        query: textQuery('after'),
      );
      expect(await repo.byId(next.id), isNotNull);
      expect(await repo.count(), 2);
    });
  });
}
