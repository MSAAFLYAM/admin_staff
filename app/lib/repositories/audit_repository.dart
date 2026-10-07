import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../models/audit_log_entry.dart';

/// مستودع سجل التدقيق (قاعدة 87).
///
/// كل تعديل مهم يُسجَّل هنا. **لا حذف أبداً** — السجل يبقى.
class AuditRepository {
  AuditRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static String _now() => DateTime.now().toIso8601String();

  // ── الكتابة ─────────────────────────────────────────────────

  /// يسجّل عملية واحدة.
  ///
  /// [oldValue]/[newValue] يُخزَّنان كنص JSON/ملخّص.
  Future<void> log({
    required String action,
    required String entityType,
    int? entityId,
    String? description,
    String? oldValue,
    String? newValue,
    Transaction? txn,
  }) async {
    final Map<String, Object?> row = <String, Object?>{
      Db.cAction: action,
      Db.cEntityType: entityType,
      Db.cEntityId: entityId,
      Db.cDescription: description,
      Db.cOldValue: oldValue,
      Db.cNewValue: newValue,
      Db.cCreatedAt: _now(),
    };
    if (txn != null) {
      await txn.insert(Db.auditLogs, row);
    } else {
      await _db.insert(Db.auditLogs, row);
    }
  }

  /// يسجّل عدة عمليات في دفعة واحدة (أداء أفضل أثناء الاستيراد).
  Future<void> logBatch(
    List<AuditLogEntry> entries, {
    Transaction? txn,
  }) async {
    if (entries.isEmpty) return;
    if (txn != null) {
      final Batch b = txn.batch();
      for (final AuditLogEntry e in entries) {
        b.insert(Db.auditLogs, e.toInsertMap());
      }
      await b.commit(noResult: true);
      return;
    }
    final Batch b = _db.batch();
    for (final AuditLogEntry e in entries) {
      b.insert(Db.auditLogs, e.toInsertMap());
    }
    await b.commit(noResult: true);
  }

  /// اختصار لتسجيل إنشاء/تعديل/حذف منطقي.
  Future<void> logCreate(
    String entityType,
    int id,
    String description, {
    Transaction? txn,
  }) =>
      log(
        action: 'create',
        entityType: entityType,
        entityId: id,
        description: description,
        txn: txn,
      );

  Future<void> logUpdate(
    String entityType,
    int id,
    String description, {
    String? oldValue,
    String? newValue,
    Transaction? txn,
  }) =>
      log(
        action: 'update',
        entityType: entityType,
        entityId: id,
        description: description,
        oldValue: oldValue,
        newValue: newValue,
        txn: txn,
      );

  Future<void> logImport(
    String kind,
    String description, {
    Transaction? txn,
  }) =>
      log(
        action: 'import',
        entityType: kind,
        description: description,
        txn: txn,
      );

  Future<void> logExport(
    String kind,
    String description, {
    Transaction? txn,
  }) =>
      log(
        action: 'export',
        entityType: kind,
        description: description,
        txn: txn,
      );

  Future<void> logBackup(
    String description, {
    Transaction? txn,
  }) =>
      log(
        action: 'backup',
        entityType: 'backup',
        description: description,
        txn: txn,
      );

  Future<void> logRestore(
    String description, {
    Transaction? txn,
  }) =>
      log(
        action: 'restore',
        entityType: 'backup',
        description: description,
        txn: txn,
      );

  Future<void> logSecurity(
    String description, {
    Transaction? txn,
  }) =>
      log(
        action: 'security',
        entityType: 'settings',
        description: description,
        txn: txn,
      );

  // ── القراءة ─────────────────────────────────────────────────

  Future<List<AuditLogEntry>> recent({int limit = 100, int offset = 0}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.auditLogs,
      orderBy: '${Db.cId} DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(AuditLogEntry.fromMap).toList();
  }

  Future<List<AuditLogEntry>> forEntity(
    String entityType,
    int entityId,
  ) async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.auditLogs,
      where: '${Db.cEntityType} = ? AND ${Db.cEntityId} = ?',
      whereArgs: <Object?>[entityType, entityId],
      orderBy: '${Db.cId} DESC',
    );
    return rows.map(AuditLogEntry.fromMap).toList();
  }

  Future<List<AuditLogEntry>> byAction(String action, {int limit = 200}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.auditLogs,
      where: '${Db.cAction} = ?',
      whereArgs: <Object?>[action],
      orderBy: '${Db.cId} DESC',
      limit: limit,
    );
    return rows.map(AuditLogEntry.fromMap).toList();
  }

  /// بحث نصّي في الوصف.
  Future<List<AuditLogEntry>> search(String query, {int limit = 200}) async {
    final String q = '%$query%';
    final List<Map<String, Object?>> rows = await _db.query(
      Db.auditLogs,
      where: '${Db.cDescription} LIKE ? OR ${Db.cOldValue} LIKE ? '
          'OR ${Db.cNewValue} LIKE ?',
      whereArgs: <Object?>[q, q, q],
      orderBy: '${Db.cId} DESC',
      limit: limit,
    );
    return rows.map(AuditLogEntry.fromMap).toList();
  }

  Future<int> count() async {
    final List<Map<String, Object?>> r =
        await _db.rawQuery('SELECT COUNT(*) AS n FROM ${Db.auditLogs}');
    return (r.first['n'] as int?) ?? 0;
  }

  /// تنظيف سجلات أقدم من [days] — **يتطلب تأكيداً صريحاً** في الواجهة.
  Future<int> purgeOlderThan(int days) async {
    final DateTime cutoff =
        DateTime.now().subtract(Duration(days: days));
    final String cutoffIso = cutoff.toIso8601String();
    return _db.delete(
      Db.auditLogs,
      where: '${Db.cCreatedAt} < ?',
      whereArgs: <Object?>[cutoffIso],
    );
  }
}
