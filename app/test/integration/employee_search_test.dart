import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/core/query/search_query.dart';
import 'package:admin_staff/models/employee.dart';
import 'package:admin_staff/repositories/employee_repository.dart';
import 'package:admin_staff/repositories/reference_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

/// ★ اختبارات البحث الفعلية على SQLite حقيقي (قاعدة 61).
///
/// هنا نثبت أن SQL المولّد **يعمل** ويعيد النتائج الصحيحة —
/// وليس مجرد مطابقة نصية على الجملة.
///
/// **ملاحظة عن البيانات:** تُنشأ عبر مسارات الإنتاج نفسها
/// ([ReferenceRepository] للأقسام/الوظائف و[Employee.toInsertMap]
/// للموظفين) حتى لا ينحرف الاختبار عن السلوك الحقيقي — وبخاصة
/// عمود `search_text` المطبَّع الذي يقوم عليه البحث كله.
void main() {
  late Database db;
  late AppDatabase appDb;
  late EmployeeRepository repo;
  late ReferenceRepository refs;

  // معرّفات مرجعية يملؤها الإعداد.
  int sectionRh = 0;
  int sectionFinances = 0;
  int fnChef = 0;
  int statusService = 0;
  int statusMaladie = 0;
  int statusSuspendu = 0;

  setUpAll(() async {
    await setUpFfi();
    db = await openTestDb();
    appDb = AppDatabase.fromDatabase(db);
    repo = EmployeeRepository(appDb);
    refs = ReferenceRepository(appDb);

    // ── مراجع عبر المستودع الفعلي (يملأ search_text) ──
    sectionRh = await refs.createEntry(
      Db.sections,
      'Ressources humaines',
      nameAr: 'الموارد البشرية',
    );
    sectionFinances =
        await refs.createEntry(Db.sections, 'Finances', nameAr: 'المالية');
    fnChef = await refs.createEntry(
      Db.functions,
      'Chef de service',
      nameAr: 'رئيس مصلحة',
    );

    final List<Map<String, Object?>> statuses = await db.query(
      'status_types',
      columns: <String>['id', 'name'],
    );
    for (final Map<String, Object?> s in statuses) {
      final String name = s['name'] as String;
      if (name == 'في الخدمة') statusService = s['id'] as int;
      if (name == 'رخصة مرضية') statusMaladie = s['id'] as int;
      if (name == 'موقوف') statusSuspendu = s['id'] as int;
    }

    // ── موظفون ──
    await _seedEmployees(
      db,
      sectionRh: sectionRh,
      sectionFinances: sectionFinances,
      fnChef: fnChef,
      statusService: statusService,
      statusMaladie: statusMaladie,
      statusSuspendu: statusSuspendu,
    );
  });

  tearDownAll(() async {
    await closeTestDb(db);
  });

  // ── S: البحث الفعلي ─────────────────────────────────────────

  group('S1–S7 البحث على SQLite حقيقي', () {
    test('S1 اسم لاتيني يطابق بحالة غير حساسة', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'Ahmed', includeInactive: true),
      );
      expect(page.total, 2, reason: 'Ahmed Mohamed + AHMED ALI');
      expect(matriculesOf(page.items), containsAll(<String>['1001', '1004']));
    });

    test('S1ب اسم فرنسي بحروف كبيرة يجد نفسه', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'AHMED', includeInactive: true),
      );
      expect(page.total, 2);
    });

    test('S2 الاسم العربي يُطبع ويطابق', () async {
      // الملف يحوي `أحمد` والبحث `أحمد` — لو طبّعنا الطرفين
      // لكان `احمد LIKE %احمد%` وهذا لا تستطيعه SQLite وحدها.
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'أحمد', includeInactive: true),
      );
      expect(page.total, 2, reason: 'أحمد محمد + أحمد علي');
      expect(
        matriculesOf(page.items),
        containsAll(<String>['1001', '1004']),
      );
    });

    test('S2ب الهمزة alternative في الاتجاهين: بحث بلا همزة يجد صاحبها',
        () async {
      // "احمد" بلا همزة يجب أن يجد "أحمد" المسجّلة.
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'احمد', includeInactive: true),
      );
      expect(page.total, 2);
      expect(
        matriculesOf(page.items),
        containsAll(<String>['1001', '1004']),
      );
    });

    test('S2ج التاء المربوطة والألف المقصورة لا تفقد النتائج', () async {
      // "المالية" تُخزَّن كـ "الماليه" بعد التطبيع — البحث عنها
      // بالهمزة/التاء الأصلية يجد الموظفين.
      final EmployeePage byOriginal = await repo.search(
        const SearchQuery(text: 'المالية', includeInactive: true),
      );
      final EmployeePage byFolded = await repo.search(
        const SearchQuery(text: 'ماليه', includeInactive: true),
      );
      expect(byOriginal.total, greaterThanOrEqualTo(1));
      expect(byFolded.total, byOriginal.total);
    });

    test('S3 مسافات زائدة = نفس النتيجة', () async {
      final EmployeePage a =
          await repo.search(const SearchQuery(text: 'ahmed'));
      final EmployeePage b =
          await repo.search(const SearchQuery(text: '   ahmed   '));
      expect(b.total, a.total);
      expect(matriculesOf(b.items), matriculesOf(a.items));
    });

    test('S5 البحث بـ matricule', () async {
      final EmployeePage page =
          await repo.search(const SearchQuery(text: '12547'));
      expect(page.total, 1);
      expect(page.items.single.matricule, '12547');
    });

    test('S6 بادئة رقم الهاتف تجد الموظف', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: '0555', includeInactive: true),
      );
      expect(page.total, 6, reason: '6 أرقام تبدأ بـ 0555 (منها 1008 معطَّل)');
    });

    test('S6ب بحث بـ PPR', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: '2200', includeInactive: true),
      );
      expect(page.total, 8, reason: 'كل الـ PPR تبدأ بـ 2200');
    });

    test('S7 نص بلا نتائج → صفحة فارغة وtotalCount = 0', () async {
      final EmployeePage page =
          await repo.search(const SearchQuery(text: 'zzzz'));
      expect(page.total, 0);
      expect(page.isEmpty, isTrue);
      expect(page.hasMore, isFalse);
    });

    test('S8 بحث مركب: كلمتان تُربطان بـ AND', () async {
      // "أحمد" و"محمد" موجودان في موظف واحد فقط.
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'أحمد محمد', includeInactive: true),
      );
      expect(page.total, 1);
      expect(page.items.single.matricule, '1001');
    });

    test('S8ب بحث مركب بلا تقاطع → فارغ', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'أحمد تقاعد', includeInactive: true),
      );
      expect(page.total, 0);
    });

    test('البحث في اسم القسم المفهرس', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'Finances', includeInactive: true),
      );
      expect(page.total, 3, reason: 'موظفو قسم المالية: 1004 و12547 و1008');
      expect(
        matriculesOf(page.items),
        containsAll(<String>['1004', '12547', '1008']),
      );
    });

    test('البحث باسم القسم العربي (search_text المطبّع)', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'الموارد البشرية', includeInactive: true),
      );
      expect(page.total, 5, reason: 'موظفو RH: 1001 و1002 و1003 و1005 و1007');
    });

    test('البحث بجزء من الوظيفة', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'chef', includeInactive: true),
      );
      expect(page.total, 2, reason: '1001 و1002 يحملان وظيفة Chef');
      expect(
        matriculesOf(page.items),
        containsAll(<String>['1001', '1002']),
      );
    });

    test('البحث بجزء من الجودة', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'titulaire', includeInactive: true),
      );
      expect(page.total, 5, reason: '5 بجودة Titulaire');
    });
  });

  // ── F: التصفية الفعلية ──────────────────────────────────────

  group('F1–F5 تصفية على SQLite حقيقي', () {
    test('F1 قسم AND حالة (تقاطع)', () async {
      final EmployeePage page = await repo.search(
        SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '$sectionRh',
              ),
              FilterCriterion(
                field: FilterField.status,
                operator: FilterOperator.eq,
                value: '$statusService',
              ),
            ],
          ),
        ),
      );
      expect(page.total, 3, reason: 'RH في الخدمة: 1001 و1002 و1007');
      expect(
        matriculesOf(page.items),
        containsAll(<String>['1001', '1002', '1007']),
      );
    });

    test('F2 قسم OR قسم (اتحاد)', () async {
      final EmployeePage page = await repo.search(
        SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '$sectionRh',
              ),
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '$sectionFinances',
              ),
            ],
            logic: FilterLogic.or,
          ),
        ),
      );
      expect(page.total, 8, reason: '5 RH + 3 مالية = كل الموظفين');
    });

    test('F3 قسم AND (حالة OR حالة) — مجموعة متداخلة', () async {
      // التعبير الصحيح عن `A AND (B OR C)` — قائمة مسطّحة
      // بمنطق واحد لا تستطيع التعبير عنه، فنستعمل group.
      final EmployeePage page = await repo.search(
        SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '$sectionRh',
              ),
              FilterCriterion.group(
                FilterSet(
                  criteria: <FilterCriterion>[
                    FilterCriterion(
                      field: FilterField.status,
                      operator: FilterOperator.eq,
                      value: '$statusMaladie',
                    ),
                    FilterCriterion(
                      field: FilterField.status,
                      operator: FilterOperator.eq,
                      value: '$statusSuspendu',
                    ),
                  ],
                  logic: FilterLogic.or,
                ),
              ),
            ],
            logic: FilterLogic.and,
          ),
        ),
      );
      expect(page.total, 2, reason: 'RH ∩ (مرضية ∨ موقوف) = 1003 و1005');
      expect(matriculesOf(page.items), containsAll(<String>['1003', '1005']));

      // المجموعة تحيط أقواسها: لو فُكّت لكانت OR أقوى من AND
      // وعادت كل الموظفين.
      final SqlWhere built = SearchQueryBuilder.build(
        SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '$sectionRh',
              ),
              FilterCriterion.group(
                FilterSet(
                  criteria: <FilterCriterion>[
                    FilterCriterion(
                      field: FilterField.status,
                      operator: FilterOperator.eq,
                      value: '$statusMaladie',
                    ),
                    FilterCriterion(
                      field: FilterField.status,
                      operator: FilterOperator.eq,
                      value: '$statusSuspendu',
                    ),
                  ],
                  logic: FilterLogic.or,
                ),
              ),
            ],
            logic: FilterLogic.and,
          ),
        ),
      );
      expect(built.clause, contains(' OR '));
      expect(built.args, <Object?>['$sectionRh', '$statusMaladie', '$statusSuspendu']);
    });

    test('F3ب عمق أكبر: (قسم OR قسم) AND (حالة OR حالة)', () async {
      final EmployeePage page = await repo.search(
        SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion.group(
                FilterSet(
                  criteria: <FilterCriterion>[
                    FilterCriterion(
                      field: FilterField.section,
                      operator: FilterOperator.eq,
                      value: '$sectionRh',
                    ),
                    FilterCriterion(
                      field: FilterField.section,
                      operator: FilterOperator.eq,
                      value: '$sectionFinances',
                    ),
                  ],
                  logic: FilterLogic.or,
                ),
              ),
              FilterCriterion.group(
                FilterSet(
                  criteria: <FilterCriterion>[
                    FilterCriterion(
                      field: FilterField.status,
                      operator: FilterOperator.eq,
                      value: '$statusMaladie',
                    ),
                    FilterCriterion(
                      field: FilterField.status,
                      operator: FilterOperator.eq,
                      value: '$statusSuspendu',
                    ),
                  ],
                  logic: FilterLogic.or,
                ),
              ),
            ],
            logic: FilterLogic.and,
          ),
        ),
      );
      // كل الموظفين في RH أو مالية، ومعطَّلهم 1008.
      expect(page.total, 2, reason: 'مرضية=1003 وموقوف=1005 وكلاهما نشط');
      expect(matriculesOf(page.items), containsAll(<String>['1003', '1005']));
    });

    test('F4 نطاق تاريخ على تاريخ التسجيل', () async {
      final EmployeePage page = await repo.search(
        SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              const FilterCriterion(
                field: FilterField.dateFrom,
                operator: FilterOperator.gte,
                value: '2026-03-01',
              ),
              const FilterCriterion(
                field: FilterField.dateTo,
                operator: FilterOperator.lte,
                value: '2026-06-30',
              ),
            ],
          ),
        ),
      );
      expect(page.total, 4,
          reason: '1003 (أبريل) و1004 (مايو) و12547 (مارس) و1007 (يونيو)');
      expect(
        matriculesOf(page.items),
        containsAll(<String>['1003', '1004', '12547', '1007']),
      );
    });

    test('F5 بدون معايير → كل السجلات النشطة', () async {
      final EmployeePage all = await repo.search(SearchQuery.initial());
      expect(all.total, 7, reason: '8 موظفين - 1 معطَّل (1008)');

      final EmployeePage withInactive =
          await repo.search(const SearchQuery(includeInactive: true));
      expect(withInactive.total, 8);
    });

    test('F6 فلترة بالتفعيل وحدها', () async {
      final EmployeePage inactive = await repo.search(
        const SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.active,
                operator: FilterOperator.eq,
                value: '0',
              ),
            ],
          ),
        ),
      );
      expect(inactive.total, 1);
      expect(inactive.items.single.matricule, '1008');
    });

    test('F7 نص + فلترة معاً', () async {
      final EmployeePage page = await repo.search(
        SearchQuery(
          text: 'أحمد',
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '$sectionRh',
              ),
            ],
          ),
        ),
      );
      expect(page.total, 1, reason: '1001 فقط: أحمد في RH (1004 في المالية)');
      expect(page.items.single.matricule, '1001');
    });

    test('F8 فلترة بجودة يحتوي', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.quality,
                operator: FilterOperator.contains,
                value: 'titulaire',
              ),
            ],
          ),
        ),
      );
      expect(page.total, 5);
    });
  });

  // ── الترقيم (Pagination) ────────────────────────────────────

  group('الترقيم داخل SQL', () {
    test('صفحة أولى بحجم 3', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(includeInactive: true, limit: 3, offset: 0),
      );
      expect(page.items, hasLength(3));
      expect(page.total, 8);
      expect(page.hasMore, isTrue);
      expect(page.currentPage, 0);
      expect(page.pageCount, 3);
    });

    test('الصفحة الأخيرة أقل حجماً', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(includeInactive: true, limit: 3, offset: 6),
      );
      expect(page.items, hasLength(2));
      expect(page.hasMore, isFalse);
      expect(page.currentPage, 2);
    });

    test('صفحات متتابعة لا تكرر ولا تفقد سجلاً', () async {
      final List<String> seen = <String>[];
      for (int offset = 0; offset < 8; offset += 3) {
        final EmployeePage page = await repo.search(
          SearchQuery(includeInactive: true, limit: 3, offset: offset),
        );
        seen.addAll(matriculesOf(page.items));
      }
      expect(seen, hasLength(8), reason: 'لا تكرر ولا فقدان');
      expect(seen.toSet(), hasLength(8));
    });

    test('الترتيب ثابت بين الصفحات (لا قفز عشوائي)', () async {
      final EmployeePage all = await repo.search(
        const SearchQuery(includeInactive: true, limit: 8),
      );
      final EmployeePage firstHalf = await repo.search(
        const SearchQuery(includeInactive: true, limit: 4, offset: 0),
      );
      final EmployeePage secondHalf = await repo.search(
        const SearchQuery(includeInactive: true, limit: 4, offset: 4),
      );

      expect(
        matriculesOf(all.items),
        <String>[
          ...matriculesOf(firstHalf.items),
          ...matriculesOf(secondHalf.items),
        ],
      );
    });
  });

  // ── عمليات قاعدة البيانات ───────────────────────────────────

  group('قاعدة البيانات: عمليات الموظفين', () {
    test('البحث بالـ matricule يعيد الموظف مع أسماء المراجع', () async {
      final Employee? e = await repo.findByMatricule('1001');
      expect(e, isNotNull);
      expect(e!.sectionName, 'Ressources humaines');
      expect(e.functionName, 'Chef de service');
      expect(e.statusName, 'في الخدمة');
      expect(e.statusPriority, 0);
      expect(e.displayNameAr, 'أحمد محمد');
    });

    test('matricule غير موجود → null لا استثناء', () async {
      expect(await repo.findByMatricule('0000'), isNull);
      expect(await repo.findByMatricule('   '), isNull);
    });

    test('ربط matricules دفعة واحدة (للمداومة)', () async {
      final Map<String, int> ids =
          await repo.matriculeIds(<String>['1001', '1003', 'لا يوجد']);
      expect(ids, hasLength(2));
      expect(ids.containsKey('لا يوجد'), isFalse);
      expect(ids['1001'], isNotNull);
      expect(ids['1001'], isNot(ids['1003']));
    });

    test('matricules فارغة → خريطة فارغة بلا استعلام', () async {
      expect(await repo.matriculeIds(<String>[]), isEmpty);
      expect(await repo.matriculeIds(<String>['  ']), isEmpty);
    });

    test('الإدراج بـ matricule مكرر يُرفض برسالة عربية', () async {
      await expectLater(
        repo.insert(
          const Employee(matricule: '1001', nomFr: 'GHOST'),
        ),
        throwsA(
          isAppException(),
        ),
      );
    });

    test('الإدراج بـ matricule فارغ مرفوض', () async {
      await expectLater(
        repo.insert(const Employee(matricule: '   ')),
        throwsA(isAppException()),
      );
    });

    test('الحذف المنطقي لا يمسّ السجل', () async {
      final EmployeePage before =
          await repo.search(const SearchQuery(includeInactive: true));
      expect(before.total, 8);

      // id=7 هو matricule 1007 (نشط) — id=8 هو 1008 المعطَّل أصلاً.
      await repo.deactivate(7);

      // ما زال موجوداً في القاعدة.
      expect(await repo.countAll(), 8);
      // لكن مخفياً من القائمة الافتراضية.
      expect((await repo.search(SearchQuery.initial())).total, 6);
      // معطَّلان.
      expect(
        (await repo.search(
          const SearchQuery(
            includeInactive: true,
            filters: FilterSet(
              criteria: <FilterCriterion>[
                FilterCriterion(
                  field: FilterField.active,
                  operator: FilterOperator.eq,
                  value: '0',
                ),
              ],
            ),
          ),
        )).total,
        2,
        reason: '1008 سابقاً + 1007 المُعطَّل الآن',
      );

      // إعادة التفعيل تعيده.
      await repo.activate(7);
      expect((await repo.search(SearchQuery.initial())).total, 7);
      expect(await repo.countAll(), 8);
    });

    test('update يحدّث ولا يمسّ created_at ويحدّث search_text', () async {
      final Employee? original = await repo.findByMatricule('1002');
      expect(original, isNotNull);
      final String createdBefore = original!.createdAt!;

      await repo.update(original.copyWith(notes: 'ملاحظة جديدة'));

      final Employee? after = await repo.findByMatricule('1002');
      expect(after!.notes, 'ملاحظة جديدة');
      expect(after.createdAt, createdBefore,
          reason: 'تاريخ الإنشاء مقدّس (قاعدة 70)');

      // سطر البحث أُعيد بناؤه.
      final List<Map<String, Object?>> row = await db.query(
        Db.employees,
        columns: <String>[Db.cSearchText],
        where: '${Db.cMatricule} = ?',
        whereArgs: <Object?>['1002'],
      );
      expect(row.single[Db.cSearchText], isNotEmpty);
    });

    test('بحث عربي جديد يجد الموظف بعد التحديث (search_text متجدّد)',
        () async {
      await repo.update(
        (await repo.findByMatricule('1008'))!.copyWith(
          nomFr: 'ZERO',
          prenomFr: 'Karim',
        ),
      );
      final EmployeePage page = await repo.search(
        const SearchQuery(text: 'ZERO', includeInactive: true),
      );
      expect(page.total, 1);
      expect(page.items.single.matricule, '1008');
    });

    test('update بمعرّف معدوم يُعطي رسالة عربية', () async {
      await expectLater(
        repo.update(const Employee(id: 99999, matricule: 'X')),
        throwsA(isAppException()),
      );
    });

    test('suggest يحوي فقط النشطين', () async {
      await repo.deactivate(7);
      try {
        final List<Employee> s = await repo.suggest('شريف');
        expect(
          s.every((Employee e) => e.isActive),
          isTrue,
          reason: 'معطَّل لا يظهر في الاقتراحات',
        );
      } finally {
        await repo.activate(7);
      }
    });

    test('suggest بحث فارغ يعيد حدّاً صحيحاً', () async {
      final List<Employee> s = await repo.suggest('', limit: 3);
      expect(s.length, lessThanOrEqualTo(3));
    });

    test('عدّادات لوحة القيادة', () async {
      expect(await repo.countAll(), 8);
      expect(await repo.countActive(), 7);
    });

    test('findById يعيد الموظف أو null', () async {
      expect(await repo.findById(1001), isNull, reason: 'id داخلي ليس matricule');
      final Employee? first = await repo.findById(1);
      expect(first, isNotNull);
      expect(first!.matricule, '1001');
      expect(await repo.findById(99999), isNull);
    });
  });

  // ── أمن: حقن SQL على SQLite فعلي ────────────────────────────

  group('حقن SQL على قاعدة حقيقية', () {
    test('محاولة حذف الجدول عبر حقل البحث تفشل ولا تتلف البيانات',
        () async {
      const String attack = "x'; DROP TABLE employees; --";
      final EmployeePage page =
          await repo.search(SearchQuery(text: attack));

      expect(page.total, 0, reason: 'لا نتائج — لكن الجدول سليم');
      // الجدول ما زال موجوداً وبياناته كما هي.
      expect(await repo.countAll(), 8);
    });

    test('مقارنة حرفية بقيمة خبيثة لا تُطابق شيئاً', () async {
      final EmployeePage page = await repo.search(
        const SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.quality,
                operator: FilterOperator.eq,
                value: "x' OR '1'='1",
              ),
            ],
          ),
        ),
      );
      expect(page.total, 0);
      expect(await repo.countAll(), 8, reason: 'كل الموظفين ما زالوا موجودين');
    });

    test('ومضة % لا تُرجع كل السجلات', () async {
      final EmployeePage page =
          await repo.search(const SearchQuery(text: '%'));
      expect(page.total, 0, reason: 'النسبة مهربة داخل النمط');
    });

    test('ومضة _ لا تعمل كحرف جامد', () async {
      // `_` تُحذف في التطبيع فلا تصير فاصلة جامدة أبداً:
      // `10_01` تُبحث ككلمتين (10 و01) لا كنمط جامد.
      final EmployeePage page =
          await repo.search(const SearchQuery(text: '10_01'));
      final EmployeePage split =
          await repo.search(const SearchQuery(text: '10 01'));
      expect(page.total, split.total);
      expect(page.total, greaterThanOrEqualTo(1));

      // والبحث بال `_` وحدها يعادل بحثاً فارغاً (مطابقة للتطبيع).
      final EmployeePage underscore =
          await repo.search(const SearchQuery(text: '_'));
      final EmployeePage empty = await repo.search(SearchQuery.initial());
      expect(underscore.total, empty.total);
      expect(await repo.countAll(), 8, reason: 'لا شيء انحذف');
    });
  });
}

// ── مساعدات ───────────────────────────────────────────────────

/// يطابق [AppException] — الخطأ المفهوم للمستخدم، لا SQLite خام.
Matcher isAppException() => isA<AppException>();

/// يملأ الجدول بموظفين تغطي كل حالات الاختبار.
///
/// الكتابة تمرّ عبر [Employee.toInsertMap] — أي نفس المسار الذي
/// يستعمله المستودع وخلية الاستيراد، فلا يمكن أن ينحرف `search_text`
/// بين الإنتاج والاختبار.
Future<void> _seedEmployees(
  Database db, {
  required int sectionRh,
  required int sectionFinances,
  required int fnChef,
  required int statusService,
  required int statusMaladie,
  required int statusSuspendu,
}) async {
  Future<void> add(
    String matricule, {
    String? nomAr,
    String? prenomAr,
    String? nomFr,
    String? prenomFr,
    int? sectionId,
    int? functionId,
    String? quality,
    String? ppr,
    String? phone,
    int? statusId,
    String createdAt = '2026-01-01T00:00:00.000',
    bool active = true,
  }) async {
    await db.insert(
      'employees',
      Employee(
        matricule: matricule,
        nomAr: nomAr,
        prenomAr: prenomAr,
        nomFr: nomFr,
        prenomFr: prenomFr,
        sectionId: sectionId,
        functionId: functionId,
        quality: quality,
        ppr: ppr,
        mobilePhone: phone,
        currentStatusId: statusId,
        isActive: active,
        createdAt: createdAt,
        updatedAt: createdAt,
      ).toInsertMap(),
    );
  }

  await add(
    '1001',
    nomAr: 'محمد',
    prenomAr: 'أحمد',
    nomFr: 'MOHAMED',
    prenomFr: 'Ahmed',
    sectionId: sectionRh,
    functionId: fnChef,
    quality: 'Titulaire',
    ppr: '22001',
    phone: '0555112233',
    statusId: statusService,
    createdAt: '2026-01-15T08:00:00.000',
  );
  await add(
    '1002',
    nomAr: 'بن عمر',
    prenomAr: 'سارة',
    nomFr: 'BEN AMAR',
    prenomFr: 'Sara',
    sectionId: sectionRh,
    functionId: fnChef,
    quality: 'Stagiaire',
    ppr: '22002',
    phone: '0555445566',
    statusId: statusService,
    createdAt: '2026-02-10T08:00:00.000',
  );
  await add(
    '1003',
    nomAr: 'شريف',
    prenomAr: 'كنزة',
    nomFr: 'CHERIF',
    prenomFr: 'Kenza',
    sectionId: sectionRh,
    quality: 'Titulaire',
    ppr: '22003',
    phone: '0666778899',
    statusId: statusMaladie,
    createdAt: '2026-04-02T08:00:00.000',
  );
  await add(
    '1004',
    nomAr: 'علي',
    prenomAr: 'أحمد',
    nomFr: 'ALI',
    prenomFr: 'AHMED',
    sectionId: sectionFinances,
    quality: 'Titulaire',
    ppr: '22004',
    phone: '0777001122',
    statusId: statusService,
    createdAt: '2026-05-20T08:00:00.000',
  );
  await add(
    '1005',
    nomAr: 'وحيد',
    prenomAr: 'مراد',
    nomFr: 'OUAHID',
    prenomFr: 'Murad',
    sectionId: sectionRh,
    quality: 'Contractuel',
    ppr: '22005',
    phone: '0555998877',
    statusId: statusSuspendu,
    createdAt: '2026-01-30T08:00:00.000',
  );
  await add(
    '12547',
    nomAr: 'قدور',
    prenomAr: 'يوسف',
    nomFr: 'KADDOUR',
    prenomFr: 'Youssef',
    sectionId: sectionFinances,
    quality: 'Titulaire',
    ppr: '22006',
    phone: '0555334455',
    statusId: statusService,
    createdAt: '2026-03-15T08:00:00.000',
  );
  await add(
    '1007',
    nomAr: 'بلقاسم',
    prenomAr: 'نادية',
    nomFr: 'BELKACEM',
    prenomFr: 'Nadia',
    sectionId: sectionRh,
    quality: 'Stagiaire',
    ppr: '22007',
    phone: '0555667788',
    statusId: statusService,
    createdAt: '2026-06-01T08:00:00.000',
  );
  await add(
    '1008',
    nomAr: 'زروقي',
    prenomAr: 'كريم',
    nomFr: 'ZERROUKI',
    prenomFr: 'Karim',
    sectionId: sectionFinances,
    quality: 'Titulaire',
    ppr: '22008',
    phone: '0555223344',
    statusId: statusService,
    createdAt: '2026-02-25T08:00:00.000',
    active: false,
  );
}
