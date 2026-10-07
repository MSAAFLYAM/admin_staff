import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';
import '../core/query/search_query.dart';
import '../core/utils/date_input.dart';
import '../core/utils/text_normalizer.dart';
import '../models/permanence_record.dart';
import '../services/status_resolver.dart';
import 'status_repository.dart';

/// فلتر قراءة المداومة — كل القيم اختيارية.
///
/// [from]/[to] على `date` (شمولية على الطرفين).
class PermanenceFilter {
  const PermanenceFilter({
    this.from,
    this.to,
    this.employeeId,
    this.matricule,
    this.section,
    this.timeSlot,
    this.unmatchedOnly = false,
    this.text = '',
  });

  /// `YYYY-MM-DD` أو أي تنسيق يفهمه [DateInput] — يُوحَّد داخلياً.
  final String? from;
  final String? to;
  final int? employeeId;

  /// مطابقة حرفية لرقم الترقيم كما هو محفوظ.
  final String? matricule;
  final String? section;
  final String? timeSlot;

  /// السجلات غير المربوطة بموظف (`employee_id IS NULL`).
  final bool unmatchedOnly;

  /// نص حرّ: يبحث في `search_text` للموظف وفي الرقم وفي اسم المداوم.
  final String text;
}

/// صفحة نتائج المداومة — الترقيم داخل SQL لا في الذاكرة.
class PermanencePage {
  const PermanencePage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<PermanenceRecord> items;
  final int total;
  final int offset;
  final int limit;

  bool get hasMore => offset + items.length < total;
  bool get isEmpty => items.isEmpty;
  int get pageCount => limit <= 0 ? 1 : ((total + limit - 1) ~/ limit);
}

/// ★ مستودع المداومة (قاعدة 10 / D-010).
///
/// المفتاح الفريد: `(date, employee_id, time_slot)` — يسمح بأكثر
/// من فترة لموظف في اليوم نفسه، ويبقي غير المربوطين بلا إنشاء
/// موظفين (القاعدة: المطابقة بالمعرّف لا إنشاء أبداً).
///
/// **لماذا يوجد `DELETE` هنا بينما بقية الجداول لا؟** المداومة
/// جدول **مواعيد** يُستبدل كاملاً عند كل ملف أسبوعي (وضع
/// «استبدال الفترة» في الاستيراد) — ليس سجلاً تاريخياً. جداول
/// التاريخ (`employees`، `leaves`، `status_history`) تبقى
/// مالكة دائماً (D-008).
class PermanenceRepository {
  PermanenceRepository(this._database, this._statuses);

  final AppDatabase _database;

  /// لاشتقاق الوضعية في عرض يوم واحد — لا نكرّر استعلاماتها.
  final StatusRepository _statuses;

  Database get _db => _database.db;

  static String _now() => DateTime.now().toIso8601String();

  /// `p` = permanence، `e` = employees.
  ///
  /// `LEFT JOIN` لا `INNER` — السجل غير المربوط يجب أن يظهر
  /// في «غير مطابِق» ولا يُستبعد من القوائم.
  static const String _from = '''
  FROM ${Db.permanence} p
  LEFT JOIN ${Db.employees} e ON e.${Db.cId} = p.${Db.cEmployeeId}
''';

  /// جلب سجل مع اسم الموظف وقسمه — **موضع واحد** للاستعلام.
  ///
  /// الاسم بالعربية والفرنسية معاً لأن الواجهة قد تُبدّل اللغة.
  static const String _select = '''
SELECT p.*,
       TRIM(COALESCE(e.${Db.cPrenomFr}, '') || ' ' ||
            COALESCE(e.${Db.cNomFr}, '')) AS employee_name_fr,
       TRIM(COALESCE(e.${Db.cPrenomAr}, '') || ' ' ||
            COALESCE(e.${Db.cNomAr}, '')) AS employee_name_ar,
       e.${Db.cSectionId} AS section_id
$_from''';

  // ── القراءة ─────────────────────────────────────────────────

  Future<PermanenceRecord?> byId(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE p.${Db.cId} = ?',
      <Object?>[id],
    );
    return rows.isEmpty ? null : PermanenceRecord.fromMap(rows.first);
  }

  /// بحث مُصفّى مع ترقيم داخل SQL — الترتيب **زمني تصاعدي**
  /// لأن المداومة مواعيد تُقرأ من الأمام إلى الخلف.
  Future<PermanencePage> search(
    PermanenceFilter filter, {
    int limit = 50,
    int offset = 0,
  }) async {
    final SqlWhere where = _where(filter);
    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.clause}';

    final List<Map<String, Object?>> countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS n $_from$whereSql',
      where.args,
    );
    final int total = (countRows.first['n'] as int?) ?? 0;

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select $whereSql '
      'ORDER BY p.${Db.cDate} ASC, p.${Db.cStartTime} ASC, p.${Db.cId} ASC '
      'LIMIT ? OFFSET ?',
      <Object?>[...where.args, limit, offset],
    );

    return PermanencePage(
      items: rows.map(PermanenceRecord.fromMap).toList(),
      total: total,
      offset: offset,
      limit: limit,
    );
  }

  /// مداومة يوم واحد — **الوحيد** الذي يملأ `derived_status_name`
  /// (استعلام اشتقاق واحد للتواريخ كلها، لا واحد لكل صف).
  Future<List<PermanenceRecord>> forDate(String date) async {
    final String d = DateInput.iso(date);
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE p.${Db.cDate} = ? '
      'ORDER BY p.${Db.cStartTime} ASC, p.${Db.cId} ASC',
      <Object?>[d],
    );
    final List<PermanenceRecord> items =
        rows.map(PermanenceRecord.fromMap).toList();
    if (items.isEmpty) return items;

    final Map<int, ResolvedStatus> statuses =
        await _statuses.derivedForAll(on: d);
    return <PermanenceRecord>[
      for (final PermanenceRecord r in items)
        r.copyWith(derivedStatusName: statuses[r.employeeId]?.label),
    ];
  }

  /// مداومة موظف ضمن فترة (تُستعمل في الملف التعريفي).
  Future<List<PermanenceRecord>> forEmployee(
    int employeeId, {
    String? from,
    String? to,
    int limit = 200,
  }) async {
    final PermanencePage page = await search(
      PermanenceFilter(employeeId: employeeId, from: from, to: to),
      limit: limit,
    );
    return page.items;
  }

  /// السجلات **غير المربوطة** بأي موظف — تُعرض ليطوّلها المستخدم.
  ///
  /// لا يُنشأ موظف تلقائياً أبداً (قاعدة الاستيراد).
  Future<List<PermanenceRecord>> unmatched({int limit = 200}) async {
    final PermanencePage page = await search(
      const PermanenceFilter(unmatchedOnly: true),
      limit: limit,
    );
    return page.items;
  }

  /// مطابقة أرقام الترقيم بموظفين — دفعات من 400 (نفس حجم
  /// الاستيراد) و**بلا قيد على التفعيل**: سجل تاريخي يجب أن يرتبط
  /// بصاحبه حتى لو كان معطَّلاً.
  ///
  /// الأرقام غير المعروفة تغادر الخريطة (غير مطابَقة) ولا تنشئ
  /// شيئاً.
  Future<Map<String, int>> matchMatricules(Iterable<String> matricules) async {
    final List<String> keys = matricules
        .map((String m) => m.trim())
        .where((String m) => m.isNotEmpty)
        .toSet()
        .toList();
    final Map<String, int> out = <String, int>{};

    for (int i = 0; i < keys.length; i += 400) {
      final List<String> chunk = keys.sublist(
        i,
        i + 400 > keys.length ? keys.length : i + 400,
      );
      final List<Map<String, Object?>> rows = await _db.query(
        Db.employees,
        columns: <String>[Db.cId, Db.cMatricule],
        where: '${Db.cMatricule} IN (${_placeholders(chunk.length)})',
        whereArgs: chunk,
      );
      for (final Map<String, Object?> m in rows) {
        out[m[Db.cMatricule] as String] = m[Db.cId] as int;
      }
    }
    return out;
  }

  // ── الكتابة ─────────────────────────────────────────────────

  /// يدرج سجلاً جديداً ويربطه بموظفيه إن كان رقمهم معروفاً.
  ///
  /// **لا ينشئ موظفاً أبداً** — إن لم يُعثر على الرقم بقي
  /// `employee_id = NULL` (غير مطابَق).
  Future<PermanenceRecord> insert(PermanenceRecord record) async {
    final PermanenceRecord p = _normalize(record);
    final int? linked = p.employeeId ?? await _resolveEmployee(p.matricule);

    final String now = _now();
    final Map<String, Object?> values = p
        .copyWith(employeeId: linked)
        .toInsertMap()
      ..[Db.cCreatedAt] = now
      ..[Db.cUpdatedAt] = now;

    try {
      final int id = await _db.insert(Db.permanence, values);
      return await _required(id);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException(
          'يوجد سجل مداومة لهذا الموظف في التاريخ والفترة نفسيهما.',
          techDetail: e.toString(),
          cause: e,
        );
      }
      rethrow;
    }
  }

  /// يحدّث سجلاً محفوظاً — يحفظ `created_at` ويمنع الانتقال
  /// إلى موظف غير موجود.
  Future<PermanenceRecord> update(PermanenceRecord record) async {
    if (record.id == null) {
      throw const AppException('سجل مداومة غير محفوظ بعد.');
    }
    final PermanenceRecord? current = await byId(record.id!);
    if (current == null) {
      throw const AppException('سجل المداومة غير موجود.');
    }

    final PermanenceRecord p = _normalize(record);
    if (p.employeeId != null) {
      await _requireEmployee(p.employeeId!);
    }

    final String now = _now();
    final Map<String, Object?> values = p
        .copyWith(createdAt: current.createdAt)
        .toInsertMap()
      ..[Db.cUpdatedAt] = now;

    try {
      await _db.update(
        Db.permanence,
        values,
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[record.id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException(
          'يوجد سجل مداومة لهذا الموظف في التاريخ والفترة نفسيهما.',
          techDetail: e.toString(),
          cause: e,
        );
      }
      rethrow;
    }
    return _required(record.id!);
  }

  /// يُدرج أو يُحدّث حسب المفتاح الفريد D-010 —
  /// مربوط: `(date, employee_id, time_slot)`،
  /// وغير مربوط: `(date, matricule, time_slot)`.
  Future<({int id, bool created})> upsert(PermanenceRecord record) async {
    final PermanenceRecord p = _normalize(record);
    final int? linked = p.employeeId ?? await _resolveEmployee(p.matricule);

    final int? existing = linked != null
        ? await _findByKey(date: p.date, employeeId: linked, slot: p.timeSlot)
        : await _findByKey(date: p.date, matricule: p.matricule, slot: p.timeSlot);

    if (existing != null) {
      await update(p.copyWith(id: existing, employeeId: linked));
      return (id: existing, created: false);
    }

    final PermanenceRecord saved =
        await insert(p.copyWith(employeeId: linked));
    return (id: saved.id!, created: true);
  }

  /// يربط سجلاً بموظف يدوياً (شاشة «غير مطابِق»).
  ///
  /// يرفض الربط إذا كان اليوم والفترة محجوزين لموظف آخر — مع
  /// رسالة عربية تشرح التعارض بدل خطأ قيد فريد خام.
  Future<void> link(int id, int employeeId) async {
    final PermanenceRecord? current = await byId(id);
    if (current == null) {
      throw const AppException('سجل المداومة غير موجود.');
    }
    await _requireEmployee(employeeId);

    try {
      await _db.update(
        Db.permanence,
        <String, Object?>{
          Db.cEmployeeId: employeeId,
          Db.cUpdatedAt: _now(),
        },
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException(
          'هذا اليوم والفترة محجوزان لموظف آخر — ربطه سيتعارض '
          'مع سجل قائمة (المفتاح: التاريخ + الموظف + الفترة).',
          techDetail: e.toString(),
          cause: e,
        );
      }
      rethrow;
    }
  }

  /// يفكّ الارتباط — يبقى السجل في القاعدة برقم الترقيم الأصلي.
  Future<void> unlink(int id) async {
    final int n = await _db.update(
      Db.permanence,
      <String, Object?>{Db.cEmployeeId: null, Db.cUpdatedAt: _now()},
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
    if (n == 0) throw const AppException('سجل المداومة غير موجود.');
  }

  /// يحذف سجلاً واحداً.
  ///
  /// المداومة جدول مواعيد لا سجل تاريخي (انظر تعريف الفئة).
  Future<void> remove(int id) async {
    final int n = await _db.delete(
      Db.permanence,
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
    if (n == 0) throw const AppException('سجل المداومة غير موجود.');
  }

  /// يستبدل فترة كاملة (وضع «استبدال الفترة» في الاستيراد).
  ///
  /// يرجع عدد المحذوف — يُستدعى **بعد التأكيد** لا قبله.
  Future<int> deleteRange(String from, String to) async {
    final String f = DateInput.iso(from);
    final String t = DateInput.iso(to);
    if (t.compareTo(f) < 0) {
      throw const AppException('تاريخ النهاية قبل تاريخ البداية.');
    }
    return _db.delete(
      Db.permanence,
      where: '${Db.cDate} >= ? AND ${Db.cDate} <= ?',
      whereArgs: <Object?>[f, t],
    );
  }

  // ── أدوات داخلية ───────────────────────────────────────────

  SqlWhere _where(PermanenceFilter f) {
    final List<SqlWhere> parts = <SqlWhere>[
      if (DateInput.isoOrNull(f.from) != null)
        SqlWhere('p.${Db.cDate} >= ?', <Object?>[DateInput.isoOrNull(f.from)]),
      if (DateInput.isoOrNull(f.to) != null)
        SqlWhere('p.${Db.cDate} <= ?', <Object?>[DateInput.isoOrNull(f.to)]),
      if (f.employeeId != null)
        SqlWhere('p.${Db.cEmployeeId} = ?', <Object?>[f.employeeId]),
      if (f.matricule != null && f.matricule!.trim().isNotEmpty)
        SqlWhere('p.${Db.cMatricule} = ?', <Object?>[f.matricule!.trim()]),
      if (f.section != null && f.section!.trim().isNotEmpty)
        SqlWhere('p.${Db.cSection} = ?', <Object?>[f.section!.trim()]),
      if (f.timeSlot != null)
        SqlWhere('p.${Db.cTimeSlot} = ?', <Object?>[f.timeSlot]),
      if (f.unmatchedOnly)
        const SqlWhere('p.${Db.cEmployeeId} IS NULL', <Object?>[]),
      _text(f.text),
    ];
    return SqlWhere.combine(parts, logic: 'AND');
  }

  /// نص حرّ بكل الكلمات (AND) — يغطي الموظف (مطبَّع)، الرقم،
  /// واسم المداوم كما ورد في الملف.
  SqlWhere _text(String raw) {
    final List<String> tokens = TextNormalizer.tokens(raw);
    if (tokens.isEmpty) return SqlWhere.none;

    final List<SqlWhere> perToken = <SqlWhere>[];
    for (final String t in tokens) {
      final String pattern = '%${SearchQueryBuilder.escapeLike(t)}%';
      perToken.add(
        SqlWhere(
          "LOWER(COALESCE(e.${Db.cSearchText}, '')) LIKE ? ESCAPE '\\' "
          "OR LOWER(COALESCE(p.${Db.cMatricule}, '')) LIKE ? ESCAPE '\\' "
          "OR LOWER(COALESCE(p.${Db.cPermanencier}, '')) LIKE ? ESCAPE '\\'",
          <Object?>[pattern, pattern, pattern],
        ),
      );
    }
    return SqlWhere.combine(perToken, logic: 'AND');
  }

  /// يوحّد المدخل: تاريخ ورقم ترقيم إلزاميان، ومفتاح الفترة
  /// يعود إلى `start_time` إن لم يُملأ.
  static PermanenceRecord _normalize(PermanenceRecord r) {
    final String matricule = r.matricule.trim();
    if (matricule.isEmpty) {
      throw const AppException('رقم matricule إلزامي ولا يمكن أن يكون فارغاً.');
    }
    final String? start = r.startTime?.trim();
    final String? end = r.endTime?.trim();
    final String slot = r.timeSlot.trim().isNotEmpty
        ? r.timeSlot.trim()
        : (start ?? '');

    return r.copyWith(
      date: DateInput.iso(r.date),
      matricule: matricule,
      startTime: start,
      endTime: end,
      clearStart: (start ?? '').isEmpty,
      clearEnd: (end ?? '').isEmpty,
      timeSlot: slot,
    );
  }

  Future<int?> _resolveEmployee(String matricule) async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.employees,
      columns: <String>[Db.cId],
      where: '${Db.cMatricule} = ?',
      whereArgs: <Object?>[matricule],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[Db.cId] as int;
  }

  Future<int?> _findByKey({
    required String date,
    int? employeeId,
    String? matricule,
    required String slot,
  }) async {
    final (String where, List<Object?> args) = employeeId != null
        ? (
            '${Db.cDate} = ? AND ${Db.cEmployeeId} = ? AND ${Db.cTimeSlot} = ?',
            <Object?>[date, employeeId, slot],
          )
        : (
            '${Db.cDate} = ? AND ${Db.cMatricule} = ? AND ${Db.cTimeSlot} = ?',
            <Object?>[date, matricule, slot],
          );
    final List<Map<String, Object?>> rows = await _db.query(
      Db.permanence,
      columns: <String>[Db.cId],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[Db.cId] as int;
  }

  Future<void> _requireEmployee(int id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.employees,
      columns: <String>[Db.cId],
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) throw const AppException('الموظف غير موجود.');
  }

  Future<PermanenceRecord> _required(int id) async {
    final PermanenceRecord? r = await byId(id);
    if (r == null) throw const AppException('سجل المداومة غير موجود.');
    return r;
  }

  static String _placeholders(int n) =>
      List<String>.filled(n, '?').join(',');
}
