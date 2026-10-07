import '../utils/text_normalizer.dart';

/// نوع معايير التصفية.
enum FilterField {
  section('section'),
  grade('grade'),
  fonction('fonction'),
  status('status'),
  quality('quality'),
  active('active'),
  dateFrom('date_from'),
  dateTo('date_to'),
  hasLeave('has_leave');

  const FilterField(this.id);
  final String id;

  static FilterField? fromId(String? id) {
    for (final FilterField f in values) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// هل هذا الحقل يقارن بالتواريخ؟ (للتحقق من الصيغة)
  bool get isDateField =>
      this == FilterField.dateFrom || this == FilterField.dateTo;
}

/// عملية المقارنة.
enum FilterOperator {
  eq('eq', '='),
  ne('ne', '<>'),
  contains('contains', 'LIKE'),
  gt('gt', '>'),
  gte('gte', '>='),
  lt('lt', '<'),
  lte('lte', '<='),
  isNull('is_null', 'IS NULL'),
  isNotNull('is_not_null', 'IS NOT NULL');

  const FilterOperator(this.id, this.sql);
  final String id;
  final String sql;

  static FilterOperator fromId(String? id) =>
      FilterOperator.values.firstWhere(
        (FilterOperator o) => o.id == id,
        orElse: () => FilterOperator.eq,
      );
}

/// منطق الربط بين المعايير.
enum FilterLogic {
  and('AND'),
  or('OR');

  const FilterLogic(this.id);
  final String id;

  static FilterLogic fromId(String? id) =>
      id?.toUpperCase() == 'OR' ? FilterLogic.or : FilterLogic.and;
}

/// معيار تصفية واحد — **أو** مجموعة معايير متداخلة.
///
/// مجموعة معايير (قاعدة F3: `section = RH AND (status = A OR status = B)`)
/// تعبَّر عنها [FilterCriterion] يحمل `group` بدل الحقول.
class FilterCriterion {
  const FilterCriterion({
    required this.field,
    required this.operator,
    this.value,
    this.value2,
    this.group,
  });

  /// مجموعة متداخلة `(...)` — إذا وُجدت تُهمّ الحقول تماماً.
  ///
  /// تسمح بـ `A AND (B OR C)` وهو ما لا تستطيعه قائمة مسطّحة
  /// بمنطق واحد.
  const FilterCriterion.group(FilterSet this.group)
      : field = FilterField.section,
        operator = FilterOperator.eq,
        value = null,
        value2 = null;

  final FilterField field;
  final FilterOperator operator;

  /// القيمة الأولى.
  final String? value;

  /// القيمة الثانية (للنطاقات: من/إلى).
  final String? value2;

  /// المجموعة الفرعية المتداخلة — `null` عدا ذلك.
  final FilterSet? group;

  bool get isGroup => group != null && group!.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'field': field.id,
        'operator': operator.id,
        'value': value,
        'value2': value2,
        if (group != null) 'group': group!.toJson(),
      };

  factory FilterCriterion.fromJson(Map<String, dynamic> j) => FilterCriterion(
        field: FilterField.fromId(j['field'] as String?) ?? FilterField.section,
        operator:
            FilterOperator.fromId(j['operator'] as String?),
        value: j['value'] as String?,
        value2: j['value2'] as String?,
        group: j['group'] == null
            ? null
            : FilterSet.fromJson(
                Map<String, dynamic>.from(j['group'] as Map),
              ),
      );

  @override
  bool operator ==(Object other) =>
      other is FilterCriterion &&
      other.field == field &&
      other.operator == operator &&
      other.value == value &&
      other.value2 == value2 &&
      other.group == group;

  @override
  int get hashCode => Object.hash(field, operator, value, value2, group);
}

/// مجموعة معايير + منطق الربط.
class FilterSet {
  const FilterSet({
    this.criteria = const <FilterCriterion>[],
    this.logic = FilterLogic.and,
  });

  final List<FilterCriterion> criteria;
  final FilterLogic logic;

  bool get isEmpty => criteria.isEmpty;
  bool get isNotEmpty => criteria.isNotEmpty;
  int get length => criteria.length;

  FilterSet copyWith({
    List<FilterCriterion>? criteria,
    FilterLogic? logic,
  }) =>
      FilterSet(
        criteria: criteria ?? this.criteria,
        logic: logic ?? this.logic,
      );

  FilterSet add(FilterCriterion c) => FilterSet(
        criteria: <FilterCriterion>[...criteria, c],
        logic: logic,
      );

  FilterSet removeAt(int index) => FilterSet(
        criteria: <FilterCriterion>[...criteria]..removeAt(index),
        logic: logic,
      );

  FilterSet clear() => const FilterSet();

  Map<String, Object?> toJson() => <String, Object?>{
        'criteria': criteria.map((FilterCriterion c) => c.toJson()).toList(),
        'logic': logic.id,
      };

  factory FilterSet.fromJson(Map<String, dynamic> j) => FilterSet(
        criteria: (j['criteria'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (dynamic e) =>
                  FilterCriterion.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        logic: FilterLogic.fromId(j['logic'] as String?),
      );
}

/// ★ مبني SQL للبحث والتصفية (قاعدة 39 و61).
///
/// **قاعدة أمنية:** كل القيم تمر عبر `?` placeholders —
/// لا يمكن حقن SQL عبر حقل البحث.
///
/// البحث يتم **داخل SQL** على الفهارس، لا بفلترة في الذاكرة.
class SqlWhere {
  const SqlWhere(this.clause, this.args);

  final String clause;
  final List<Object?> args;

  bool get isEmpty => clause.isEmpty;

  static const SqlWhere none = SqlWhere('', <Object?>[]);

  /// دمج عدة شروط بمنطق [logic].
  static SqlWhere combine(List<SqlWhere> parts, {required String logic}) {
    final List<SqlWhere> usable =
        parts.where((SqlWhere p) => !p.isEmpty).toList();
    if (usable.isEmpty) return SqlWhere('', <Object?>[]);
    final String joined =
        usable.map((SqlWhere p) => '(${p.clause})').join(' $logic ');
    return SqlWhere(
      joined,
      <Object?>[for (final SqlWhere p in usable) ...p.args],
    );
  }
}

/// نص البحث الحرّ + التصفية → شرط SQL واحد.
class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.filters = const FilterSet(),
    this.includeInactive = false,
    this.limit = 50,
    this.offset = 0,
  });

  /// نص البحث الحرّ (يُطبَّع عبر [TextNormalizer]).
  final String text;
  final FilterSet filters;

  /// هل تُعرض الموظفين المُعطَّلين أيضاً؟
  final bool includeInactive;

  final int limit;
  final int offset;

  static SearchQuery initial() => const SearchQuery();

  SearchQuery copyWith({
    String? text,
    FilterSet? filters,
    bool? includeInactive,
    int? limit,
    int? offset,
  }) =>
      SearchQuery(
        text: text ?? this.text,
        filters: filters ?? this.filters,
        includeInactive: includeInactive ?? this.includeInactive,
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
      );

  bool get hasQuery => text.trim().isNotEmpty || filters.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'text': text,
        'filters': filters.toJson(),
        'include_inactive': includeInactive,
      };

  factory SearchQuery.fromJson(Map<String, dynamic> j) => SearchQuery(
        text: (j['text'] as String?) ?? '',
        filters: FilterSet.fromJson(
          Map<String, dynamic>.from(j['filters'] as Map? ?? <String, dynamic>{}),
        ),
        includeInactive: (j['include_inactive'] as bool?) ?? false,
      );
}

/// يبني شرط `WHERE` الكامل من [SearchQuery].
abstract final class SearchQueryBuilder {
  /// أعمدة البحث النصّي — **كلها عمود واحد مطبَّع** `search_text`.
  ///
  /// لماذا بدل `e.nom_fr` و… (11 عموداً)؟ لأن `LIKE` لا يفهم العربية:
  /// `LOWER()` في SQLite لاتيني فقط، فالبحث عن `أحمد` ضدّ `أحمد`
  /// يفشل. لذلك نطبّع الطرفين مرة واحدة عند الكتابة ونخزّن النتيجة
  /// في `search_text` — **أسرع** (عمود واحد بدل 11) وصحيح للعربية.
  ///
  /// الأقسام والرتب والوظائف تُبحث عبر جداولها المطبّعة نفسها.
  static const List<String> textColumns = <String>[
    'e.search_text',
    's.search_text',
    'g.search_text',
    'f.search_text',
  ];

  /// يبني شرط النص الحرّ وحده.
  ///
  /// كل كلمة في البحث يجب أن تظهر في **أي** عمود (AND بين الكلمات).
  static SqlWhere textClause(String raw) {
    final List<String> tokens = TextNormalizer.tokens(raw);
    if (tokens.isEmpty) return SqlWhere('', <Object?>[]);

    final List<SqlWhere> perToken = <SqlWhere>[];
    for (final String t in tokens) {
      final String pattern = '%${escapeLike(t)}%';
      final String or = textColumns
          .map((String c) => "LOWER(COALESCE($c, '')) LIKE ? ESCAPE '\\'")
          .join(' OR ');
      perToken.add(
        SqlWhere(
          or,
          <Object?>[for (int i = 0; i < textColumns.length; i++) pattern],
        ),
      );
    }
    return SqlWhere.combine(perToken, logic: 'AND');
  }

  /// يهرب رموز `LIKE` — **النقطة المائلة أولاً** وإلا انهار الهروب.
  static String escapeLike(String input) => input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// يبني شرط تصفية واحداً — أو مجموعة فرعية كاملة إن كان معياراً.
  static SqlWhere criterionClause(FilterCriterion c) {
    // مجموعة متداخلة `(...)` — نبنيها بعمق، وسيغلّفها الدامج أقواساً.
    if (c.isGroup) return filterClause(c.group!);

    switch (c.field) {
      // ── نطاق تاريخ: نقارن جزء التاريخ فقط (بدون الوقت) ──
      case FilterField.dateFrom:
      case FilterField.dateTo:
        final String? v = c.value;
        if (v == null || v.trim().isEmpty) return SqlWhere('', <Object?>[]);
        final String date = v.trim().substring(0, 10);
        final String op =
            c.field == FilterField.dateFrom ? '>=' : '<=';
        return SqlWhere(
          "substr(e.created_at, 1, 10) $op ?",
          <Object?>[date],
        );

      // ── هل لديه رخصة سارية؟ ( EXISTS على leaves ) ──
      case FilterField.hasLeave:
        final String? v = c.value;
        if (v == null || v == '0' || v.toLowerCase() == 'false') {
          return SqlWhere(
            'NOT EXISTS (SELECT 1 FROM leaves l '
            'WHERE l.employee_id = e.id AND l.is_cancelled = 0)',
            <Object?>[],
          );
        }
        return SqlWhere(
          'EXISTS (SELECT 1 FROM leaves l '
          'WHERE l.employee_id = e.id AND l.is_cancelled = 0)',
          <Object?>[],
        );

      case FilterField.active:
        // `is_active` عمود INTEGER — نقارن برقم لا بنص.
        final String? raw = c.value;
        final int? n = raw == null
            ? null
            : int.tryParse(raw.trim()) ??
                (raw.trim().toLowerCase() == 'true'
                    ? 1
                    : raw.trim().toLowerCase() == 'false'
                        ? 0
                        : null);
        if (n == null) return SqlWhere('', <Object?>[]);
        return SqlWhere('e.is_active ${c.operator.sql} ?', <Object?>[n]);

      default:
        break;
    }

    final String column = _columnFor(c.field);

    switch (c.operator) {
      case FilterOperator.isNull:
        return SqlWhere('$column IS NULL', <Object?>[]);
      case FilterOperator.isNotNull:
        return SqlWhere('$column IS NOT NULL', <Object?>[]);
      case FilterOperator.contains:
        final String v = TextNormalizer.normalize(c.value);
        if (v.isEmpty) return SqlWhere('', <Object?>[]);
        return SqlWhere(
          "LOWER(COALESCE($column, '')) LIKE ? ESCAPE '\\'",
          <Object?>['%${escapeLike(v)}%'],
        );
      case FilterOperator.eq:
      case FilterOperator.ne:
      case FilterOperator.gt:
      case FilterOperator.gte:
      case FilterOperator.lt:
      case FilterOperator.lte:
        final String? v = c.value;
        if (v == null || v.trim().isEmpty) return SqlWhere('', <Object?>[]);
        return SqlWhere('$column ${c.operator.sql} ?', <Object?>[v.trim()]);
    }
  }

  /// يبني شرط التصفية الكامل مع المنطق (AND/OR).
  static SqlWhere filterClause(FilterSet set) {
    if (set.isEmpty) return SqlWhere('', <Object?>[]);
    final String logic = set.logic == FilterLogic.or ? 'OR' : 'AND';
    return SqlWhere.combine(
      set.criteria.map(criterionClause).toList(),
      logic: logic,
    );
  }

  /// يبني `WHERE` الكامل: النص الحرّ **AND** التصفية.
  static SqlWhere build(SearchQuery q) {
    final List<SqlWhere> parts = <SqlWhere>[
      textClause(q.text),
      filterClause(q.filters),
      if (!q.includeInactive) const SqlWhere('e.is_active = 1', <Object?>[]),
    ];
    return SqlWhere.combine(parts, logic: 'AND');
  }

  /// أعمدة البحث البسيطة. الحقول الخاصة (تاريخ/رخصة/تفعيل)
  /// تُعالَج قبل الوصول إلى هنا في [criterionClause].
  static String _columnFor(FilterField f) => switch (f) {
        FilterField.section => 'e.section_id',
        FilterField.grade => 'e.grade_id',
        FilterField.fonction => 'e.function_id',
        FilterField.status => 'e.current_status_id',
        FilterField.quality => 'e.quality',
        FilterField.active => 'e.is_active',
        FilterField.dateFrom => 'substr(e.created_at, 1, 10)',
        FilterField.dateTo => 'substr(e.created_at, 1, 10)',
        FilterField.hasLeave => 'e.id',
      };
}
