import 'package:admin_staff/core/database/schema.dart';
import 'package:admin_staff/core/query/search_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات مبني SQL للبحث (S1–S8) والتصفية (F1–F5).
///
/// **القاعدة الأمنية المشتركة:** أي قيمة من المستخدم تظهر عبر `?`
/// وتمرّ في `args` — لا تُلصق في نص SQL أبداً.
///
/// ملاحظة: `TextNormalizer.normalize()` يحوّل للحروف الصغيرة،
/// لذا أنماط `LIKE` تكون **دائماً** صغيرة الحرف.
void main() {
  // ── S: البحث الحرّ ───────────────────────────────────────────

  group('S1–S4 البحث النصي', () {
    test('S1 كلمة واحدة تُطابق في كل الأعمدة المفهرسة', () {
      final SqlWhere w = SearchQueryBuilder.textClause('Ahmed');

      expect(w.args, hasLength(SearchQueryBuilder.textColumns.length));
      expect(w.args.first, '%ahmed%', reason: 'التطبيع يحول للصغير');
      // كل الأعمدة مطبَّعة في `search_text` (قاعدة 61).
      expect(w.clause, contains('e.search_text'));
      expect(w.clause, contains('s.search_text'));
      expect(w.clause, contains('g.search_text'));
      expect(w.clause, contains('f.search_text'));
      expect(w.clause, contains(' OR '));
      expect(w.clause, isNot(contains('Ahmed')), reason: 'لا حقن SQL');
      expect(w.clause, isNot(contains('ahmed')), reason: 'القيمة في args لا في SQL');
    });

    test('S2 البحث بالعربية يطبّع الهمزات ويطابق الأعمدة العربية', () {
      // "أحمد" تُطبع إلى "احمد" (توحيد الألف/الهمزة).
      //
      // الطرف الآخر مطبَّع أيضاً عند الكتابة، فتصبح المطابقة
      // `احمد LIKE %احمد%` — وهذا عملٌ لا تقدر عليه SQLite وحدها.
      final SqlWhere w = SearchQueryBuilder.textClause('أحمد');

      expect(w.args.first, '%احمد%');
      expect(w.clause, contains('search_text'));
      expect(w.clause, contains('LOWER('));
    });

    test('S3 المسافات الزائدة تُهمل', () {
      final SqlWhere padded = SearchQueryBuilder.textClause('  ahmed  ');
      final SqlWhere clean = SearchQueryBuilder.textClause('ahmed');

      expect(padded.args, clean.args);
      expect(padded.clause, clean.clause);
    });

    test('S4 غير حساس لحالة الأحرف — LOWER على الجانبين', () {
      final SqlWhere lower = SearchQueryBuilder.textClause('ahmed');
      final SqlWhere upper = SearchQueryBuilder.textClause('AHMED');

      // الفهرسة تعمل بـ LOWER(...) LIKE ? — الجملتان متطابقتان.
      expect(lower.clause, upper.clause);
      expect(lower.args, upper.args);
      expect(lower.clause, contains('LOWER('));
    });

    test('S8 بحث مركب: كلمتان تُربطان بـ AND', () {
      final SqlWhere w = SearchQueryBuilder.textClause('محمد قسم');

      expect(w.args, hasLength(2 * SearchQueryBuilder.textColumns.length));
      expect(w.clause, contains(' AND '));

      // كل كلمة تبقى مجموعة OR مستقلة بين الأعمدة.
      final List<String> groups =
          w.clause.split(') AND (').map((String s) => s.trim()).toList();
      expect(groups, hasLength(2));
      expect(groups.first, contains(' OR '));
      expect(groups.last, contains(' OR '));
    });

    test('نص فارغ أو مسافات فقط → شرط فارغ', () {
      expect(SearchQueryBuilder.textClause('').isEmpty, isTrue);
      expect(SearchQueryBuilder.textClause('   ').isEmpty, isTrue);
    });

    test('رموز LIKE تُهرب داخل النمط فقط', () {
      final SqlWhere w = SearchQueryBuilder.textClause(r'100%');

      expect(w.args.first, r'%100\%%');
      expect(w.clause, isNot(contains(r'100\%')));
    });

    test('شرط ESCAPE موجود مع كل LIKE', () {
      final SqlWhere w = SearchQueryBuilder.textClause('abc');

      expect(w.clause, contains(r"ESCAPE '\'"));
      // كل عمود له LIKE? + ESCAPE مطابق.
      final int escapes = RegExp(r"ESCAPE").allMatches(w.clause).length;
      expect(escapes, SearchQueryBuilder.textColumns.length);
      expect('LIKE ?'.allMatches(w.clause).length,
          SearchQueryBuilder.textColumns.length);
    });

    test('S7 نص بلا نتائج لا يزال يبني SQL صالحاً', () {
      final SqlWhere w = SearchQueryBuilder.textClause('zzzz');

      expect(w.isEmpty, isFalse);
      expect(w.args, isNotEmpty);
      expect(w.clause, contains('LIKE ?'));
    });

    test('كلمة واحدة تبحث في القائمة نفسها من الأعمدة', () {
      final SqlWhere w = SearchQueryBuilder.textClause('x');
      final String orBody = w.clause;
      for (final String col in SearchQueryBuilder.textColumns) {
        expect(orBody, contains(col), reason: 'العمود $col مفقود من البحث');
      }
    });
  });

  // ── F: التصفية المتقدمة ──────────────────────────────────────

  group('F1–F5 تركيب المعايير', () {
    test('F1 معياران AND (مع إهمال شرط النشاط لعزل الاختبار)', () {
      final SqlWhere w = SearchQueryBuilder.build(
        const SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '3',
              ),
              FilterCriterion(
                field: FilterField.status,
                operator: FilterOperator.eq,
                value: '1',
              ),
            ],
            logic: FilterLogic.and,
          ),
        ),
      );

      expect(w.clause, contains(' AND '));
      expect(w.clause, isNot(contains(' OR ')));
      expect(w.args, <Object?>['3', '1']);
    });

    test('F2 معياران OR', () {
      final SqlWhere w = SearchQueryBuilder.build(
        const SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '3',
              ),
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '5',
              ),
            ],
            logic: FilterLogic.or,
          ),
        ),
      );

      expect(w.clause, contains(' OR '));
      expect(w.clause, isNot(contains(' AND ')));
      expect(w.args, <Object?>['3', '5']);
    });

    test('F3 مركب: قسم AND (حالتان OR) — مجموعة متداخلة', () {
      // يحاكي: Section=3 AND (Status=2 OR Status=4)
      // عبر `FilterCriterion.group` — التعبير الصحيح عن هذا المنطق.
      final SqlWhere w = SearchQueryBuilder.build(
        const SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '3',
              ),
              FilterCriterion.group(
                FilterSet(
                  criteria: <FilterCriterion>[
                    FilterCriterion(
                      field: FilterField.status,
                      operator: FilterOperator.eq,
                      value: '2',
                    ),
                    FilterCriterion(
                      field: FilterField.status,
                      operator: FilterOperator.eq,
                      value: '4',
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

      // الأقواس تحيط بالمجموعة الفرعية **وحدها**، فالـ OR
      // لا يتسرّب إلى المستوى الخارجي.
      expect(
        w.clause,
        '((e.section_id = ?) AND '
        '((e.current_status_id = ?) OR (e.current_status_id = ?)))',
        reason: 'البنية الدقيقة للأقواس هي ما يمنع تسرّب OR',
      );
      expect(w.args, <Object?>['3', '2', '4']);
    });

    test('F5 بدون معايير وبدون نص → شرط النشاط فقط (كل السجلات)', () {
      final SqlWhere w = SearchQueryBuilder.build(SearchQuery.initial());

      // الافتراضي يُخفي المعطَّلين — وهذا هو "كل السجلات" الحية.
      expect(w.clause.replaceAll('(', '').replaceAll(')', ''),
          'e.is_active = 1');
      expect(w.args, isEmpty);
    });

    test('F5ب مع includeInactive → شرط فارغ تماماً', () {
      final SqlWhere w =
          SearchQueryBuilder.build(const SearchQuery(includeInactive: true));
      expect(w.isEmpty, isTrue);
      expect(w.args, isEmpty);
    });

    test('نص + معايير يُدمجان بنفس الترتيب (نص أولاً)', () {
      final SqlWhere w = SearchQueryBuilder.build(
        const SearchQuery(
          text: 'ahmed',
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.grade,
                operator: FilterOperator.eq,
                value: '7',
              ),
            ],
          ),
        ),
      );

      expect(w.clause, contains(' AND '));
      expect(w.args.last, '7');
      expect(w.args.first, '%ahmed%');
    });

    test('المعيار بقيمة فارغة يُهمل ولا يكسر بقية الشرط', () {
      final SqlWhere w = SearchQueryBuilder.build(
        const SearchQuery(
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.eq,
                value: '  ',
              ),
              FilterCriterion(
                field: FilterField.fonction,
                operator: FilterOperator.eq,
                value: '2',
              ),
            ],
          ),
        ),
      );

      expect(w.args, <Object?>['2']);
      expect(w.clause, contains('e.function_id'));
      expect(w.clause, isNot(contains('e.section_id')),
          reason: 'المعيار الفارغ أُسقط كلياً');
    });

    test('F6 المعايير التفاعلية: النشط والرخصة والنطاق', () {
      // is_active عمود INTEGER → نمرّر رقماً لا نصاً.
      final SqlWhere active = SearchQueryBuilder.criterionClause(
        const FilterCriterion(
          field: FilterField.active,
          operator: FilterOperator.eq,
          value: '1',
        ),
      );
      expect(active.args, <Object?>[1]);
      expect(active.args.single, isA<int>());

      // has_leave → EXISTS على leaves، لا عمود وهمي.
      final SqlWhere leave = SearchQueryBuilder.criterionClause(
        const FilterCriterion(
          field: FilterField.hasLeave,
          operator: FilterOperator.eq,
          value: '1',
        ),
      );
      expect(leave.clause, startsWith('EXISTS'));
      expect(leave.clause, contains('is_cancelled = 0'));
      expect(leave.args, isEmpty);

      final SqlWhere noLeave = SearchQueryBuilder.criterionClause(
        const FilterCriterion(
          field: FilterField.hasLeave,
          operator: FilterOperator.eq,
          value: '0',
        ),
      );
      expect(noLeave.clause, startsWith('NOT EXISTS'));

      // النطاق الزمني يقارن جزء التاريخ فقط (10 محارف).
      final SqlWhere from = SearchQueryBuilder.criterionClause(
        const FilterCriterion(
          field: FilterField.dateFrom,
          operator: FilterOperator.gte,
          value: '2026-10-03T09:00:00.000',
        ),
      );
      expect(from.args, <Object?>['2026-10-03']);
      expect(from.clause, contains('substr('));

      final SqlWhere to = SearchQueryBuilder.criterionClause(
        const FilterCriterion(
          field: FilterField.dateTo,
          operator: FilterOperator.lte,
          value: '2026-12-31',
        ),
      );
      expect(to.args, <Object?>['2026-12-31']);
      expect(to.clause, contains('<='));
    });

    test('OPERATORS تُترجم إلى SQL صحيح', () {
      expect(FilterOperator.eq.sql, '=');
      expect(FilterOperator.ne.sql, '<>');
      expect(FilterOperator.gte.sql, '>=');
      expect(FilterOperator.lte.sql, '<=');
      expect(FilterOperator.contains.sql, 'LIKE');
      expect(FilterOperator.isNull.sql, 'IS NULL');
      expect(FilterOperator.isNotNull.sql, 'IS NOT NULL');
    });

    test('contains يطبّع القيمة ويهرب رموز LIKE', () {
      final SqlWhere w = SearchQueryBuilder.criterionClause(
        const FilterCriterion(
          field: FilterField.quality,
          operator: FilterOperator.contains,
          value: r'chef_100%',
        ),
      );
      expect(w.args.single, contains('chef'));
      expect(w.args.single, startsWith('%'));
      expect(w.args.single, endsWith('%'));
      expect(w.clause, contains('LIKE ?'));
    });
  });

  // ── القاعدة الأمنية العامة ───────────────────────────────────

  group('الأمان: لا حقن SQL', () {
    test('محاولة حقن في النص لا تدخل الجملة', () {
      const String attack = r"x'; DROP TABLE employees; --";
      final SqlWhere w = SearchQueryBuilder.textClause(attack);

      // الجملة = أسماء أعمدة فقط، لا شيء من النص.
      expect(w.clause.toUpperCase(), isNot(contains('DROP')));
      expect(w.clause, isNot(contains(';')));
      expect(w.clause, isNot(contains('--')));

      // التطبيع يحوّل النص إلى كلمات آمنة مفرّقة بمسافات.
      // "x'; DROP TABLE employees; --" → [x, drop, table, employees]
      expect(w.args, contains('%x%'));
      expect(w.args, contains('%drop%'));
      expect(w.args, contains('%employees%'));
      expect(w.args.every((Object? a) => (a as String).startsWith('%')), isTrue);
    });

    test('محاولة حقن في قيمة معيار تبقى معاملة', () {
      final SqlWhere w = SearchQueryBuilder.criterionClause(
        const FilterCriterion(
          field: FilterField.quality,
          operator: FilterOperator.eq,
          value: "chef'; DELETE FROM employees; --",
        ),
      );

      expect(w.clause, isNot(contains('DELETE')));
      expect(w.clause, isNot(contains(';')));
      expect(w.args.single, "chef'; DELETE FROM employees; --");
    });

    test('استعلام فيه نص ومعايير: القيم كلها في args', () {
      const String evilFilter = "1' OR '1'='1";
      final SqlWhere w = SearchQueryBuilder.build(
        const SearchQuery(
          text: "ali' OR 1=1 --",
          includeInactive: true,
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.status,
                operator: FilterOperator.eq,
                value: evilFilter,
              ),
            ],
          ),
        ),
      );

      // 1) القيمة الخبيثة لا تظهر في الجملة إطلاقاً — فقط في args.
      expect(w.clause, isNot(contains(evilFilter)));
      expect(w.clause, isNot(contains('1=1')));
      expect(w.clause, isNot(contains("';")));

      // 2) النص مطبّع إلى كلمات آمنة، كل كلمة في معامل منفصل.
      //    "ali' OR 1=1 --" → [ali, or, 1, 1]
      final List<String> textArgs = w.args
          .whereType<String>()
          .where((String a) => a.startsWith('%'))
          .toList();
      expect(textArgs.first, '%ali%');
      expect(textArgs, isNotEmpty);

      // 3) القيمة الخبيثة محفوظة كما هي في المعاملات (تُقارن حرفاً بحرف).
      expect(w.args, contains(evilFilter));

      // 4) عدد المعاملات يطابق عدد الـ placeholder.
      expect(w.args, hasLength('?'.allMatches(w.clause).length));
    });

    test('عدّاد المعاملات يطابق عدد علامات الـ placeholder', () {
      final SqlWhere w = SearchQueryBuilder.build(
        const SearchQuery(
          text: 'a b c',
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.section,
                operator: FilterOperator.gte,
                value: '2',
              ),
              FilterCriterion(
                field: FilterField.grade,
                operator: FilterOperator.lte,
                value: '9',
              ),
            ],
          ),
        ),
      );

      final int placeholders = '?'.allMatches(w.clause).length;
      expect(w.args, hasLength(placeholders));
    });

    test('كل عبارة LIKE يسبقها عمود ويعقبها placeholder', () {
      final SqlWhere w = SearchQueryBuilder.textClause('test');
      final RegExp row = RegExp(r"LIKE \? ESCAPE");
      expect(row.allMatches(w.clause).length,
          SearchQueryBuilder.textColumns.length);
    });
  });

  // ── (S5) الفهرسة المطلوبة ────────────────────────────────────

  group('S5 أعمدة البحث مفهرسة', () {
    test('قائمة الأعمدة تطابق docs/DATABASE.md', () {
      // عمود واحد مطبَّع لكل جدول — بدل 11 عموداً خاماً.
      // البحث يبقى داخل SQL على الفهارس (قاعدة 61).
      const Set<String> expected = <String>{
        'e.search_text',
        's.search_text',
        'g.search_text',
        'f.search_text',
      };

      expect(SearchQueryBuilder.textColumns.toSet(), expected);
      expect(SearchQueryBuilder.textColumns,
          hasLength(SearchQueryBuilder.textColumns.toSet().length),
          reason: 'لا أعمدة مكررة');
    });

    test('الفهارس المطلوبة موجودة في المخطط الفعلي', () {
      // مطابقة لـ docs/DATABASE.md — تُقرأ من DDL الحقيقي لا من نص متوقع.
      final String ddl = Schema.createStatements.join('\n');
      const List<String> required = <String>[
        'uq_employees_matricule',
        'ix_employees_ppr',
        'ix_employees_nom_ar',
        'ix_employees_nom_fr',
        'ix_employees_section',
        'ix_employees_status',
        'ix_status_priority',
        'ix_sections_name',
        'ix_grades_name',
        'ix_functions_name',
      ];
      for (final String idx in required) {
        expect(ddl, contains(idx), reason: 'الفهرس $idx مفقود من المخطط');
      }
    });
  });

  // ── JSON (لحفظ البحث المحفوظ) ────────────────────────────────

  group('حفظ/استرجاع البحث', () {
    test('دورة JSON كاملة', () {
      const SearchQuery original = SearchQuery(
        text: 'ahmed',
        includeInactive: true,
        filters: FilterSet(
          criteria: <FilterCriterion>[
            FilterCriterion(
              field: FilterField.section,
              operator: FilterOperator.eq,
              value: '3',
            ),
          ],
          logic: FilterLogic.or,
        ),
      );

      final SearchQuery back =
          SearchQuery.fromJson(original.toJson() as Map<String, dynamic>);

      expect(back.text, original.text);
      expect(back.includeInactive, isTrue);
      expect(back.filters.logic, FilterLogic.or);
      expect(back.filters.criteria, original.filters.criteria);
    });

    test('JSON فارغ يعطي استعلام ابتدائي', () {
      final SearchQuery q =
          SearchQuery.fromJson(<String, dynamic>{'text': null});
      expect(q.text, '');
      expect(q.filters.isEmpty, isTrue);
      expect(q.hasQuery, isFalse);
    });

    test('حقل مجهول في JSON لا يُسقط الاستعلام', () {
      final FilterCriterion c = FilterCriterion.fromJson(
        <String, dynamic>{'field': 'غير معروف', 'operator': 'غير معروف'},
      );
      expect(c.field, FilterField.section, reason: 'القيمة الافتراضية');
      expect(c.operator, FilterOperator.eq);
    });

    test('hasQuery يميز الفراغ عن القيمة', () {
      expect(const SearchQuery().hasQuery, isFalse);
      expect(const SearchQuery(text: '  ').hasQuery, isFalse);
      expect(const SearchQuery(text: 'x').hasQuery, isTrue);
      expect(
        const SearchQuery(
          filters: FilterSet(
            criteria: <FilterCriterion>[
              FilterCriterion(
                field: FilterField.active,
                operator: FilterOperator.eq,
                value: '1',
              ),
            ],
          ),
        ).hasQuery,
        isTrue,
      );
    });

    test('copyWith لا يمسّ ما لم يُذكر', () {
      const SearchQuery base = SearchQuery(text: 'a', includeInactive: true);
      final SearchQuery next = base.copyWith(offset: 50);

      expect(next.text, 'a');
      expect(next.includeInactive, isTrue);
      expect(next.offset, 50);
      expect(next.limit, base.limit);
    });

    test('FilterSet تُضاف وتُحذف دون mutate الأصل', () {
      const FilterSet base = FilterSet();
      final FilterSet withOne = base.add(
        const FilterCriterion(
          field: FilterField.grade,
          operator: FilterOperator.eq,
          value: '1',
        ),
      );

      expect(base.isEmpty, isTrue, reason: 'الكائن أصلي غير معدّل');
      expect(withOne.length, 1);
      expect(withOne.removeAt(0).isEmpty, isTrue);
      expect(withOne.length, 1);
    });

    test('FilterField.fromId يرفض مجهولاً', () {
      expect(FilterField.fromId('section'), FilterField.section);
      expect(FilterField.fromId('لا شيء'), isNull);
      expect(FilterField.fromId(null), isNull);
      expect(FilterLogic.fromId('OR'), FilterLogic.or);
      expect(FilterLogic.fromId(null), FilterLogic.and);
    });
  });
}
