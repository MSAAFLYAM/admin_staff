import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';
import '../core/utils/text_normalizer.dart';
import '../models/reference_entries.dart';
import '../models/status_type.dart';

/// مستودع الجداول المرجعية (sections / grades / functions / status_types).
///
/// **قاعدة:** لا نص حرّ في الواجهة — كل قيمة تمرّ من هنا.
/// الـ lookup يتم بـ SQL على الفهرس (لا تحميل الكل في الذاكرة).
class ReferenceRepository {
  ReferenceRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// المُنفِّذ: المعطى (الـ Transaction) إن وُجد، وإلا القاعدة الجذرية.
  ///
  /// **لماذا هذا ضروري؟** sqflite لا تسمح باستعمال الكائن الجذري
  /// داخل `transaction()` — ينتهي الأمر بـ *deadlock* ("database has
  /// been locked"). أي استدعاء أثناء استيراد يجب أن يمرّ عبر
  /// الـ `Transaction` نفسها.
  /// المُنفِّذ الفعلي لهذا الاستدعاء.
  DatabaseExecutor _x(DatabaseExecutor? txn) => txn ?? _db;

  static String _now() => DateTime.now().toIso8601String();

  // ── جلب القوائم ─────────────────────────────────────────────

  Future<List<ReferenceEntry>> sections({bool activeOnly = false}) =>
      _list(Db.sections, activeOnly: activeOnly);

  Future<List<ReferenceEntry>> grades({bool activeOnly = false}) =>
      _list(Db.grades, activeOnly: activeOnly);

  Future<List<ReferenceEntry>> functions({bool activeOnly = false}) =>
      _list(Db.functions, activeOnly: activeOnly);

  Future<List<StatusType>> statusTypes({bool activeOnly = false}) async {
    final String where = activeOnly ? 'WHERE ${Db.cIsActive} = 1' : '';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT * FROM ${Db.statusTypes} $where '
      'ORDER BY ${Db.cSortOrder}, ${Db.cPriority} DESC',
    );
    return rows.map(StatusType.fromMap).toList();
  }

  Future<List<ReferenceEntry>> _list(
    String table, {
    bool activeOnly = false,
  }) async {
    final String where = activeOnly ? 'WHERE ${Db.cIsActive} = 1' : '';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT * FROM $table $where ORDER BY ${Db.cName}',
    );
    return rows.map(ReferenceEntry.fromMap).toList();
  }

  // ── البحث بالاسم (يستخدمه الاستيراد والواجهة) ───────────────

  /// يبحث عن مدخل بالاسم — مطابقة تامة أولاً ثم `LIKE`.
  ///
  /// يُرجع `null` إذا لم يُعثر عليه. **لا ينشئ أبداً.**
  /// مرّر [txn] داخل عملية استيراد وإلا تعطّل القفل (deadlock).
  Future<int?> findIdByName(
    String table,
    String name, {
    DatabaseExecutor? txn,
  }) async {
    final String needle = name.trim();
    if (needle.isEmpty) return null;
    final DatabaseExecutor db = _x(txn);

    // مطابقة تامة (حساسة لحالة الأحرف لأنها الأدق).
    final List<Map<String, Object?>> exact = await db.query(
      table,
      columns: <String>[Db.cId],
      where: '${Db.cName} = ? OR ${Db.cNameAr} = ?',
      whereArgs: <Object?>[needle, needle],
      limit: 1,
    );
    if (exact.isNotEmpty) return exact.first[Db.cId] as int;

    // مطابقة غير حساسة للحالة.
    final List<Map<String, Object?>> ci = await db.rawQuery(
      'SELECT ${Db.cId} FROM $table '
      'WHERE LOWER(${Db.cName}) = LOWER(?) OR LOWER(${Db.cNameAr}) = LOWER(?) '
      'LIMIT 1',
      <Object?>[needle, needle],
    );
    if (ci.isNotEmpty) return ci.first[Db.cId] as int;

    // مطابقة جزئية — يبقى تحذيراً لا قراراً.
    final List<Map<String, Object?>> partial = await db.rawQuery(
      'SELECT ${Db.cId} FROM $table '
      'WHERE ${Db.cName} LIKE ? OR ${Db.cNameAr} LIKE ? '
      'LIMIT 2',
      <Object?>['%$needle%', '%$needle%'],
    );
    if (partial.length == 1) return partial.first[Db.cId] as int;
    return null;
  }

  Future<int?> findSectionId(String name, {DatabaseExecutor? txn}) =>
      findIdByName(Db.sections, name, txn: txn);
  Future<int?> findGradeId(String name, {DatabaseExecutor? txn}) =>
      findIdByName(Db.grades, name, txn: txn);
  Future<int?> findFunctionId(String name, {DatabaseExecutor? txn}) =>
      findIdByName(Db.functions, name, txn: txn);

  /// الوضعية بالاسم — تُطابق `name` أو `name_fr`.
  Future<int?> findStatusId(String name, {DatabaseExecutor? txn}) async {
    final String needle = name.trim();
    if (needle.isEmpty) return null;
    final List<Map<String, Object?>> rows = await _x(txn).rawQuery(
      'SELECT ${Db.cId} FROM ${Db.statusTypes} '
      'WHERE ${Db.cName} = ? OR ${Db.cNameFr} = ? '
      '   OR LOWER(${Db.cName}) = LOWER(?) '
      '   OR LOWER(${Db.cNameFr}) = LOWER(?) '
      'LIMIT 1',
      <Object?>[needle, needle, needle, needle],
    );
    return rows.isEmpty ? null : rows.first[Db.cId] as int;
  }

  // ── الإنشاء والاستيراد ──────────────────────────────────────

  /// هل هذا الجدول يملك عمود `search_text` المطبَّع؟
  ///
  /// يُستدعى [createEntry] و[upsertEntry] أيضاً على جداول بلا عمود
  /// بحث نصي مثل `status_types` / `leave_types`.
  static bool _hasSearchText(String table) =>
      table == Db.sections || table == Db.grades || table == Db.functions;

  /// ينشئ مدخلاً جديداً في جدول مرجعي إن لم يكن موجوداً.
  ///
  /// يُرجع المعرّف الموجود إن كان الاسم مكرراً (لا تكرار أبداً).
  Future<int> createEntry(
    String table,
    String name, {
    String? nameAr,
    DatabaseExecutor? txn,
  }) async {
    final String clean = name.trim();
    if (clean.isEmpty) {
      throw const AppException('لا يمكن إنشاء مدخل باسم فارغ.');
    }
    final int? existing = await findIdByName(table, clean, txn: txn);
    if (existing != null) return existing;

    final String? ar = (nameAr ?? '').trim().isEmpty ? null : nameAr!.trim();
    final int id = await _x(txn).insert(table, <String, Object?>{
      Db.cName: clean,
      Db.cNameAr: ar,
      if (_hasSearchText(table))
        Db.cSearchText: TextNormalizer.searchText(<String?>[clean, ar]),
      Db.cIsActive: 1,
      Db.cCreatedAt: _now(),
      Db.cUpdatedAt: _now(),
    });
    return id;
  }

  /// ينشئ/يحدّث مدخل ويسمح بإعادة تعيين الاسم.
  Future<int> upsertEntry(
    String table, {
    int? id,
    required String name,
    String? nameAr,
    bool isActive = true,
    DatabaseExecutor? txn,
  }) async {
    final String clean = name.trim();
    if (clean.isEmpty) {
      throw const AppException('الاسم مطلوب ولا يمكن أن يكون فارغاً.');
    }
    if (id == null) {
      return createEntry(table, clean, nameAr: nameAr, txn: txn);
    }
    final String? ar = (nameAr ?? '').trim().isEmpty ? null : nameAr!.trim();
    await _x(txn).update(
      table,
      <String, Object?>{
        Db.cName: clean,
        Db.cNameAr: ar,
        if (_hasSearchText(table))
          Db.cSearchText: TextNormalizer.searchText(<String?>[clean, ar]),
        Db.cIsActive: isActive ? 1 : 0,
        Db.cUpdatedAt: _now(),
      },
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
    return id;
  }

  /// يبحث أو ينشئ — يُستخدم أثناء الاستيراد.
  ///
  /// [created] يُضبط true إذا أُنشئ مدخل جديد (للتقارير).
  Future<({int id, bool created})> resolveOrCreate(
    String table,
    String name, {
    String? nameAr,
    bool createIfMissing = true,
    DatabaseExecutor? txn,
  }) async {
    final String clean = name.trim();
    if (clean.isEmpty) {
      return (id: 0, created: false);
    }
    final int? existing = await findIdByName(table, clean, txn: txn);
    if (existing != null) return (id: existing, created: false);
    if (!createIfMissing) return (id: 0, created: false);
    final int id = await createEntry(table, clean, nameAr: nameAr, txn: txn);
    return (id: id, created: true);
  }

  // ── إحصاءات ─────────────────────────────────────────────────

  Future<int> count(String table) async {
    final List<Map<String, Object?>> r = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM $table',
    );
    return (r.first['n'] as int?) ?? 0;
  }

  /// هل الاسم مستخدم حالياً في جدول مرجعي آخر؟ (منع الحذف)
  Future<bool> isReferenced(String table, int id) async {
    switch (table) {
      case Db.sections:
        return _referenced(Db.employees, Db.cSectionId, id);
      case Db.grades:
        return _referenced(Db.employees, Db.cGradeId, id);
      case Db.functions:
        return _referenced(Db.employees, Db.cFunctionId, id);
      case Db.statusTypes:
        final bool a = await _referenced(Db.employees, Db.cStatusId, id);
        if (a) return true;
        final bool b = await _referenced(Db.statusHistory, Db.cStatusTypeId, id);
        if (b) return true;
        return _referenced(Db.leaveTypes, Db.cStatusTypeId, id);
      default:
        return false;
    }
  }

  Future<bool> _referenced(String table, String column, int id) async {
    final List<Map<String, Object?>> r = await _db.rawQuery(
      'SELECT 1 FROM $table WHERE $column = ? LIMIT 1',
      <Object?>[id],
    );
    return r.isNotEmpty;
  }

  /// تعطيل (soft) بدل الحذف — قاعدة 70.
  Future<void> deactivate(String table, int id) => _db.update(
        table,
        <String, Object?>{
          Db.cIsActive: 0,
          Db.cUpdatedAt: _now(),
        },
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[id],
      );
}
