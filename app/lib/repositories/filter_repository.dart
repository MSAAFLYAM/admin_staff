import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';
import '../core/query/search_query.dart';
import '../models/saved_filter.dart';

/// ★ مستودع الفلاتر المحفوظة — جدول `saved_filters` (المخطط §10).
///
/// **الجدول هو المرجع لا الرأي:** لا عمود `kind` في المخطط، لذا
/// يُخزَّن النوع داخل عمود `criteria` (JSON) — لا هجرة ولا تغيير
/// في `schema_version`. وعمود `logic` يحمل منطق المجموعة العليا
/// (`AND`/`OR`) لا نسخة منه داخل `criteria`؛ فلا ازدواج مصدر.
///
/// **الاسم فريد عالمياً** (`uq_saved_filter_name`) — لهذا يفحص
/// المسترد الاسم قبل الكتابة بقارئ عربي بدل أن يترك قيد `UNIQUE`
/// يرمي `constraint failed` خاماً على المستخدم (قاعدة 49).
///
/// **الحذف مسموح هنا** (لا عمود `is_active` في المخطط) تماماً
/// كـ `permanence`: الفلاتر تفضيلات لا تاريخ (D-008).
class FilterRepository {
  FilterRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static String _now() => DateTime.now().toIso8601String();

  // ── القراءة ─────────────────────────────────────────────────

  /// كل الفلاتر — **مرتبة أبجدياً غير حساسة للحالة** حتى تبقى
  /// القائمة ثابتة بين التحميلين، ثم بالمعرّف لتعادل الاسم.
  ///
  /// **صفّ تالف يُتجاهَل ولا يسقط البقية** (قاعدة 49).
  Future<List<SavedFilter>> all({DatabaseExecutor? txn}) async {
    final List<Map<String, Object?>> rows = await (txn ?? _db).query(
      Db.savedFilters,
      orderBy: '${Db.cName} COLLATE NOCASE ASC, ${Db.cId} ASC',
    );
    return _parseAll(rows);
  }

  Future<SavedFilter?> byId(int id, {DatabaseExecutor? txn}) async {
    final List<Map<String, Object?>> rows = await (txn ?? _db).query(
      Db.savedFilters,
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final List<SavedFilter> parsed = _parseAll(rows);
    return parsed.isEmpty ? null : parsed.first;
  }

  /// فلاتر شاشة واحدة — `kind` داخل JSON لا يستحق فلتراً SQL
  /// (العدد قليل عادةً).
  Future<List<SavedFilter>> forKind(
    SavedFilterKind kind, {
    DatabaseExecutor? txn,
  }) async =>
      (await all(txn: txn))
          .where((SavedFilter f) => f.kind == kind)
          .toList(growable: false);

  Future<int> count({DatabaseExecutor? txn}) async =>
      (await (txn ?? _db).rawQuery('SELECT COUNT(*) c FROM ${Db.savedFilters}'))
          .first['c'] as int? ??
      0;

  // ── الكتابة ─────────────────────────────────────────────────

  /// فلتر جديد بمعرّف يمنحه الجدول.
  Future<SavedFilter> add({
    required String name,
    required SavedFilterKind kind,
    required SearchQuery query,
    DatabaseExecutor? txn,
  }) =>
      save(
        SavedFilter(name: name, kind: kind, query: query),
        txn: txn,
      );

  /// إنشاء أو تحديث **حسب المعرّف** — لا ازدواج بين «إنشاء»
  /// و«تعديل» في الواجهة.
  Future<SavedFilter> save(SavedFilter filter, {DatabaseExecutor? txn}) async {
    final String name = filter.name.trim();
    if (name.isEmpty) {
      throw const AppException('لا يمكن حفظ فلتر باسم فارغ.');
    }
    if (!filter.query.hasQuery) {
      throw const AppException(
        'لا يمكن حفظ فلتر فارغ — عيّن نص بحث أو شريطاً واحداً على الأقل.',
      );
    }

    final DatabaseExecutor db = txn ?? _db;
    await _rejectDuplicateName(db, name, selfId: filter.id);

    final String now = _now();
    final Map<String, Object?> values = <String, Object?>{
      Db.cName: name,
      Db.cCriteria: filter.toCriteria(),
      Db.cLogic: filter.logic,
      Db.cUpdatedAt: now,
    };

    if (filter.isNew) {
      final int id = await _guard(
        () => db.insert(
          Db.savedFilters,
          <String, Object?>{
            ...values,
            Db.cCreatedAt: now,
          },
        ),
        name,
      );
      return filter.copyWith(
        id: id,
        name: name,
        createdAt: now,
        updatedAt: now,
      );
    }

    final int changed = await _guard(
      () => db.update(
        Db.savedFilters,
        values,
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[filter.id],
      ),
      name,
    );
    if (changed == 0) throw const AppException('الفلتر المحفوظ غير موجود.');
    return filter.copyWith(name: name, updatedAt: now);
  }

  /// إعادة تسمية — المعرّف ثابت، والاسم الفريد يبقى شرطاً.
  Future<SavedFilter> rename(
    int id,
    String name, {
    DatabaseExecutor? txn,
  }) async {
    final String clean = name.trim();
    if (clean.isEmpty) throw const AppException('لا يمكن حفظ فلتر باسم فارغ.');

    final DatabaseExecutor db = txn ?? _db;
    await _rejectDuplicateName(db, clean, selfId: id);

    final int changed = await _guard(
      () => db.update(
        Db.savedFilters,
        <String, Object?>{
          Db.cName: clean,
          Db.cUpdatedAt: _now(),
        },
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[id],
      ),
      clean,
    );
    if (changed == 0) throw const AppException('الفلتر المحفوظ غير موجود.');

    final SavedFilter? updated = await byId(id, txn: txn);
    if (updated == null) {
      throw const AppException('تعذّر قراءة الفلتر المحفوظ بعد التحديث.');
    }
    return updated;
  }

  Future<void> remove(int id, {DatabaseExecutor? txn}) async {
    final int gone = await (txn ?? _db).delete(
      Db.savedFilters,
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
    if (gone == 0) throw const AppException('الفلتر المحفوظ غير موجود.');
  }

  // ── أدوات ──────────────────────────────────────────────────

  /// الفحص الذي يستبق قيد `UNIQUE` — الاسم فريد **عالمياً** في
  /// المخطط، فالفحص غير حساس لحالة الأحرف أشدّ لا أخفّ.
  static Future<void> _rejectDuplicateName(
    DatabaseExecutor db,
    String name, {
    required int selfId,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      Db.savedFilters,
      columns: <String>[Db.cId, Db.cName],
    );
    final String key = name.toLowerCase();
    for (final Map<String, Object?> row in rows) {
      final int id = (row[Db.cId] as num?)?.toInt() ?? 0;
      final String other = ((row[Db.cName] as String?) ?? '').toLowerCase();
      if (id != selfId && other == key) {
        throw AppException('يوجد فلتر محفوظ بهذا الاسم بالفعل: $name');
      }
    }
  }

  /// قيد `UNIQUE` أو أي فشل قاعدة → رسالة عربية لا `constraint failed`.
  Future<T> _guard<T>(Future<T> Function() op, String name) async {
    try {
      return await op();
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException('يوجد فلتر محفوظ بهذا الاسم بالفعل: $name');
      }
      throw AppException.wrap(
        e,
        fallbackMessage: 'تعذّر حفظ الفلتر المحفوظ — أعد المحاولة.',
      );
    }
  }

  static List<SavedFilter> _parseAll(Iterable<Map<String, Object?>> rows) {
    final List<SavedFilter> out = <SavedFilter>[];
    for (final Map<String, Object?> row in rows) {
      try {
        out.add(
          SavedFilter.fromRow(
            id: (row[Db.cId] as num?)?.toInt() ?? 0,
            name: (row[Db.cName] as String?) ?? '',
            logic: (row[Db.cLogic] as String?) ?? 'AND',
            criteria: (row[Db.cCriteria] as String?) ?? '',
            createdAt: row[Db.cCreatedAt] as String?,
            updatedAt: row[Db.cUpdatedAt] as String?,
          ),
        );
      } on FormatException {
        // صفّ تالف يُتجاهَل — بقية القائمة تُقرأ.
      } on TypeError {
        // نوع غير متوقع في عمود نصّي — نفس التعامل.
      }
    }
    return out;
  }
}
