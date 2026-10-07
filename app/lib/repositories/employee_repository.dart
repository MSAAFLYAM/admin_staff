import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';
import '../core/query/search_query.dart';
import '../models/employee.dart';

/// صفحة نتائج البحث.
class EmployeePage {
  const EmployeePage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<Employee> items;
  final int total;
  final int offset;
  final int limit;

  bool get hasMore => offset + items.length < total;
  bool get isEmpty => items.isEmpty;
  int get pageCount => limit <= 0 ? 1 : ((total + limit - 1) ~/ limit);
  int get currentPage => limit <= 0 ? 0 : (offset ~/ limit);
}

/// ★ مستودع الموظفين (قواعد 39 و61).
///
/// **قاعدة الأداء:** كل البحث يتم داخل SQL على الفهارس —
/// لا تحميل كل الموظفين ثم فلترة في Dart.
class EmployeeRepository {
  EmployeeRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static String _now() => DateTime.now().toIso8601String();

  /// الـ JOINs المشتركة بين العدّ والجلب — **موضع واحد** لا تكرار.
  ///
  /// `s` = sections، `g` = grades، `f` = functions، `st` = status_types.
  static const String _joins = '''
  LEFT JOIN ${Db.sections} s  ON s.${Db.cId} = e.${Db.cSectionId}
  LEFT JOIN ${Db.grades}   g  ON g.${Db.cId} = e.${Db.cGradeId}
  LEFT JOIN ${Db.functions} f  ON f.${Db.cId} = e.${Db.cFunctionId}
  LEFT JOIN ${Db.statusTypes} st ON st.${Db.cId} = e.${Db.cStatusId}
''';

  /// جملة `SELECT` الموحدة مع أسماء المراجع للعرض.
  static const String _baseSelect = '''
SELECT e.*,
       s.${Db.cName}  AS section_name,
       g.${Db.cName}  AS grade_name,
       f.${Db.cName}  AS function_name,
       st.${Db.cName}  AS status_name,
       st.${Db.cNameFr} AS status_name_fr,
       st.${Db.cPriority} AS status_priority
  FROM ${Db.employees} e
$_joins''';

  /// عدّ الصفوف المطابقة — **نفس** الـ JOINs ونفس شرط WHERE.
  static const String _countSelect = '''
SELECT COUNT(*) AS n
  FROM ${Db.employees} e
$_joins''';

  // ── البحث والتصفية ──────────────────────────────────────────

  /// يبحث بصفحة واحدة (LIMIT/OFFSET داخل SQL).
  Future<EmployeePage> search(SearchQuery query) async {
    final SqlWhere where = SearchQueryBuilder.build(query);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.clause}';

    // العدد أولاً (أرخص من جلب الصفوف) — بنفس الـ JOINs وشرط WHERE.
    final List<Map<String, Object?>> countRows = await _db.rawQuery(
      '$_countSelect $whereSql',
      where.args,
    );
    final int total = (countRows.first['n'] as int?) ?? 0;

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_baseSelect $whereSql '
      'ORDER BY e.${Db.cNomFr} COLLATE NOCASE, e.${Db.cPrenomFr} COLLATE NOCASE, '
      'e.${Db.cNomAr}, e.${Db.cId} '
      'LIMIT ? OFFSET ?',
      <Object?>[...where.args, query.limit, query.offset],
    );

    return EmployeePage(
      items: rows.map(Employee.fromMap).toList(),
      total: total,
      offset: query.offset,
      limit: query.limit,
    );
  }

  /// بحث سريع بالـ matricule (شاشة الاستيراد/المداومة).
  Future<Employee?> findByMatricule(String matricule) async {
    final String clean = matricule.trim();
    if (clean.isEmpty) return null;
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_baseSelect WHERE e.${Db.cMatricule} = ? LIMIT 1',
      <Object?>[clean],
    );
    return rows.isEmpty ? null : Employee.fromMap(rows.first);
  }

  /// بحث متعدد بالـ matricules (لربط المداومة دفعة واحدة).
  Future<Map<String, int>> matriculeIds(Iterable<String> matricules) async {
    final List<String> clean =
        matricules.map((String m) => m.trim()).where((String m) => m.isNotEmpty)
            .toSet()
            .toList();
    if (clean.isEmpty) return <String, int>{};

    final Map<String, int> out = <String, int>{};
    // نقسم إلى دفعات لتجاوز حدّ متغيّرات SQLite.
    for (int i = 0; i < clean.length; i += 500) {
      final List<String> chunk = clean.sublist(
        i,
        i + 500 > clean.length ? clean.length : i + 500,
      );
      final List<Map<String, Object?>> rows = await _db.rawQuery(
        'SELECT ${Db.cId}, ${Db.cMatricule} FROM ${Db.employees} '
        'WHERE ${Db.cMatricule} IN '
        '(${List<String>.filled(chunk.length, '?').join(',')})',
        chunk,
      );
      for (final Map<String, Object?> r in rows) {
        out[(r[Db.cMatricule] as String?) ?? ''] = r[Db.cId] as int;
      }
    }
    return out;
  }

  /// يجلب موظفاً بالمعرّف مع كل حقول العرض.
  Future<Employee?> findById(int id) async {
    final List<Map<String, Object?>> rows =
        await _db.rawQuery('$_baseSelect WHERE e.${Db.cId} = ? LIMIT 1',
            <Object?>[id]);
    return rows.isEmpty ? null : Employee.fromMap(rows.first);
  }

  /// عدد الموظفين النشطين (للوحة القيادة).
  Future<int> countActive() async {
    final List<Map<String, Object?>> r = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${Db.employees} WHERE ${Db.cIsActive} = 1',
    );
    return (r.first['n'] as int?) ?? 0;
  }

  Future<int> countAll() async {
    final List<Map<String, Object?>> r = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${Db.employees}',
    );
    return (r.first['n'] as int?) ?? 0;
  }

  /// اقتراحات البحث التلقائي (حدّ صغير — تُستدعى بعد debounce).
  Future<List<Employee>> suggest(String text, {int limit = 8}) async {
    final SqlWhere where = SearchQueryBuilder.textClause(text);
    final String whereSql = where.isEmpty
        ? 'WHERE e.${Db.cIsActive} = 1'
        : 'WHERE ${where.clause} AND e.${Db.cIsActive} = 1';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_baseSelect $whereSql ORDER BY e.${Db.cId} LIMIT ?',
      <Object?>[...where.args, limit],
    );
    return rows.map(Employee.fromMap).toList();
  }

  // ── الكتابة ─────────────────────────────────────────────────

  /// يinsert موظفاً جديداً.
  ///
  /// يرمي [AppException] برسالة عربية إذا كان `matricule` مكرراً.
  Future<int> insert(Employee employee) async {
    if (employee.matricule.trim().isEmpty) {
      throw const AppException('حقل Matricule إلزامي ولا يمكن أن يكون فارغاً.');
    }
    try {
      final Map<String, Object?> values = employee.toInsertMap()
        ..[Db.cCreatedAt] = _now()
        ..[Db.cUpdatedAt] = _now();
      return await _db.insert(Db.employees, values);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException(
          'رقم matricule "${employee.matricule}" مستخدم لموظف آخر.',
          techDetail: e.toString(),
          cause: e,
        );
      }
      rethrow;
    }
  }

  /// يحدّث موظفاً — **لا يمسّ `created_at` ولا أي تاريخ سابق**.
  Future<void> update(Employee employee) async {
    final int? id = employee.id;
    if (id == null) {
      throw const AppException('لا يمكن تحديث سجل بدون معرّف.');
    }
    try {
      final Map<String, Object?> values = employee.toInsertMap()
        ..remove(Db.cCreatedAt)
        ..[Db.cUpdatedAt] = _now();
      final int n = await _db.update(
        Db.employees,
        values,
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[id],
      );
      if (n == 0) {
        throw const AppException('لم يعد هذا الموظف موجوداً.');
      }
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException(
          'رقم matricule "${employee.matricule}" مستخدم لموظف آخر.',
          techDetail: e.toString(),
          cause: e,
        );
      }
      rethrow;
    }
  }

  /// حذف **منطقي** فقط — السجل وتاريخه يبقيان (قاعدة 70).
  Future<void> deactivate(int id) async {
    await _db.update(
      Db.employees,
      <String, Object?>{
        Db.cIsActive: 0,
        Db.cUpdatedAt: _now(),
      },
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// إعادة تفعيل موظف معطَّل.
  Future<void> activate(int id) async {
    await _db.update(
      Db.employees,
      <String, Object?>{
        Db.cIsActive: 1,
        Db.cUpdatedAt: _now(),
      },
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// مسح فيزيائي — **يستهلك صلاحية فقط** (الواجهة تخفيه افتراضياً).
  ///
  /// التاريخ المرتبط يُحذف بـ `CASCADE`؛ لهذا هو آخر الخيارات.
  Future<void> hardDelete(int id) async {
    await _db.delete(
      Db.employees,
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
  }
}
