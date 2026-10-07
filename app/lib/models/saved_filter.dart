import 'dart:convert';

import '../core/query/search_query.dart';

/// شاشة الفلتر المحفوظ — الموظفون / الرخص / المداومة.
///
/// المخطط `saved_filters` (§10) **لا عمود له**؛ لذا يُخزَّن النوع
/// داخل عمود `criteria` (JSON) لا كعمود جديد — لا هجرة، لا تغيير في
/// `schema_version`.
enum SavedFilterKind {
  employees('employees'),
  leaves('leaves'),
  permanence('permanence');

  const SavedFilterKind(this.id);

  /// القيمة المخزَّنة في JSON — لا اسم الحالة (فإن تغيّر الاسم
  /// لغةً لا يختلّ ما كُتب سابقاً).
  final String id;

  /// يرمي [FormatException] لغير معروف — لا استثناء خام للواجهة.
  static SavedFilterKind fromId(String? raw) {
    for (final SavedFilterKind k in SavedFilterKind.values) {
      if (k.id == raw) return k;
    }
    throw FormatException('نوع فلتر غير معروف: $raw');
  }
}

/// فلتر محفوظ يعيد المستخدم إليه بضغطة واحدة.
///
/// [id] = `0` قبل الحفظ (`INTEGER PRIMARY KEY AUTOINCREMENT`).
/// المعرّف لا يعتمد على الاسم، فيخرج الاسم من الاعتبار عند إعادة
/// التسمية.
class SavedFilter {
  const SavedFilter({
    this.id = 0,
    required this.name,
    required this.kind,
    this.query = const SearchQuery(),
    this.createdAt,
    this.updatedAt,
  });

  /// يبني الفلتر من صفّ جدول `saved_filters` — المخطط §10.
  ///
  /// يرمي [FormatException] لو كان `criteria` تالفاً أو ناقصاً؛
  /// المسترد **يتجاهل الصف ولا يسقط بقية القائمة** (قاعدة 49).
  factory SavedFilter.fromRow({
    required int id,
    required String name,
    required String logic,
    required String criteria,
    String? createdAt,
    String? updatedAt,
  }) {
    if (id <= 0 || name.trim().isEmpty) {
      throw const FormatException('صف فلتر محفوظ بلا معرّف أو باسم فارغ.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(criteria);
    } on FormatException {
      throw FormatException('معايير فلتر محفوظ تالفة (id=$id).');
    }
    if (decoded is! Map) {
      throw FormatException('معايير فلتر محفوظ ليست كائناً (id=$id).');
    }

    final Map<String, dynamic> m = Map<String, dynamic>.from(decoded);
    final Object? text = m['text'];
    final Object? includeInactive = m['include_inactive'];
    final Object? list = m['criteria'];
    if ((text != null && text is! String) ||
        (includeInactive != null && includeInactive is! bool) ||
        list is! List) {
      throw FormatException('صيغة معايير فلتر محفوظ غير صالحة (id=$id).');
    }

    final List<FilterCriterion> criteriaList = <FilterCriterion>[];
    for (final Object? e in list) {
      if (e is! Map) {
        throw FormatException('معيار غير صالح في فلتر id=$id.');
      }
      try {
        criteriaList.add(FilterCriterion.fromJson(Map<String, dynamic>.from(e)));
      } on TypeError {
        throw FormatException('معيار بحقل غير صالح في فلتر id=$id.');
      }
    }

    return SavedFilter(
      id: id,
      name: name.trim(),
      kind: SavedFilterKind.fromId(
        m['kind'] is String ? m['kind'] as String? : null,
      ),
      query: SearchQuery(
        text: (text as String?) ?? '',
        includeInactive: (includeInactive as bool?) ?? false,
        filters: FilterSet(
          criteria: criteriaList,
          logic: FilterLogic.fromId(logic),
        ),
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// `0` = لم يُحفظ بعد.
  final int id;
  final String name;
  final SavedFilterKind kind;

  /// النص الحرّ + المجموعة المتداخلة من `FilterSet` (D-018).
  final SearchQuery query;

  final String? createdAt;
  final String? updatedAt;

  bool get isNew => id == 0;

  /// ما يُكتب في عمود `criteria` (صيغة قابلة للتوسّع: مفاتيح
  /// مجهولة في إصدار لاحق تُتجاهَل لا تكسر القراءة).
  String toCriteria() => jsonEncode(<String, Object?>{
        'kind': kind.id,
        'text': query.text,
        'include_inactive': query.includeInactive,
        'criteria': <Map<String, Object?>>[
          for (final FilterCriterion c in query.filters.criteria) c.toJson(),
        ],
      });

  /// ما يُكتب في عمود `logic` — منطق المجموعة العليا.
  String get logic => query.filters.logic.id;

  SavedFilter copyWith({
    int? id,
    String? name,
    SavedFilterKind? kind,
    SearchQuery? query,
    String? createdAt,
    String? updatedAt,
  }) =>
      SavedFilter(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        query: query ?? this.query,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) => other is SavedFilter && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SavedFilter($id, ${kind.id}, $name)';
}
