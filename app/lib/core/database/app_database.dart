import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../constants/db_constants.dart';
import 'schema.dart';
import 'seed_data.dart';

/// نقطة الوصول الوحيدة إلى SQLite.
///
/// المسؤوليات:
///  - فتح/غلق القاعدة
///  - تنفيذ `PRAGMA` (foreign_keys, WAL)
///  - `onCreate` / `onUpgrade` مع نظام migration (قاعدة 60)
///  - زراعة البيانات الأولية
///  - توفير `Transaction` لعمليات الاستيراد (قاعدة 82)
///
/// **لا يحتوي على منطق أعمال** — ذلك دور repositories.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  Database get db => _db;

  // ── Singleton ────────────────────────────────────────────────
  static AppDatabase? _instance;

  /// يفتح القاعدة (أو يعيد المفتوحة) ويشغّل الـ migration.
  static Future<AppDatabase> instance() async {
    if (_instance != null) return _instance!;
    final Database db = await _open();
    _instance = AppDatabase._(db);
    return _instance!;
  }

  /// للاختبارات: حقن قاعدة جاهزة بدلاً من فتح ملف حقيقي.
  static AppDatabase fromDatabase(Database db) => AppDatabase._(db);

  /// يعيد تعيين الـ singleton (للاختبارات فقط).
  static void resetInstance() => _instance = null;

  static String? _cachedPath;

  /// مسار ملف القاعدة — يُحسب مرة واحدة.
  static Future<String> get databasePath async {
    if (_cachedPath != null) return _cachedPath!;
    final Directory dir = await getApplicationDocumentsDirectory();
    _cachedPath = '${dir.path}/${Db.dbFileName}';
    return _cachedPath!;
  }

  static Future<Database> _open() async {
    _useDesktopFactory();
    final String path = await databasePath;
    return openDatabase(
      path,
      version: Db.schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// على الحاسوب لا توجد قناة `sqflite` أصلية → نُبدِّل المحرّك
  /// الافتراضي إلى **FFI** نفسه المستعمل في الاختبارات (D-003)،
  /// فيكون نفس SQL على الجهاز وعلى سطح المكتب.
  ///
  /// على أندرويد/iOS لا يتغيّر شيء إطلاقاً. الاختبار يمرّ هنا
  /// أيضاً (Windows) فلا يختلف سلوك `flutter test` عن الإنتاج.
  static void _useDesktopFactory() {
    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
  }

  // ── PRAGMAs ──────────────────────────────────────────────────
  static Future<void> _onConfigure(Database db) async {
    // قاعدة 69: منع orphan records.
    await db.execute('PRAGMA foreign_keys = ON');
    // أداء أفضل مع الكتابة المتزامنة.
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
  }

  // ── الإنشاء الأول ───────────────────────────────────────────
  static Future<void> _onCreate(Database db, int version) async {
    await createSchema(db);
    await seed(db);
  }

  /// ينشئ كل الجداول والمؤشرات في [db].
  ///
  /// مثل [seed] — **مصدر واحد** للمحلّ الإنتاجي وللاختبارات.
  static Future<void> createSchema(Database db) async {
    final Batch batch = db.batch();
    for (final String stmt in Schema.createStatements) {
      batch.execute(stmt);
    }
    await batch.commit(noResult: true);
  }

  // ── الترقية (قاعدة 60) ──────────────────────────────────────
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // نموذج للتوسع: عند الإصدار 2 نضيف هنا MigrationV2.
    //
    // if (oldVersion < 2) {
    //   await MigrationV2.apply(db);
    // }
    debugPrint(
      '[DB] migration $oldVersion -> $newVersion '
      '(no pending migrations)',
    );
  }

  // ── Seed ─────────────────────────────────────────────────────

  /// يزرع البيانات الأولية في [db].
  ///
  /// **منطقة مصدر واحدة** — تُستدعى من `onCreate` ومن اختبارات
  /// `sqflite_common_ffi`، فلا يمكن أن ينحرف الـ seed عن المخطط.
  static Future<void> seed(Database db) async {
    final String now = SeedData.now;
    final Batch batch = db.batch();

    for (final List<Object?> row in SeedData.statusTypes) {
      batch.insert(
        Db.statusTypes,
        <String, Object?>{
          Db.cName: row[0],
          Db.cNameFr: row[1],
          Db.cPriority: row[2],
          Db.cSortOrder: row[3],
          Db.cIsTerminal: row[4],
          Db.cIsActive: 1,
          Db.cCreatedAt: now,
          Db.cUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final List<Object?> row in SeedData.leaveTypes) {
      batch.insert(
        Db.leaveTypes,
        <String, Object?>{
          Db.cNameAr: row[0],
          Db.cNameFr: row[1],
          Db.cDefaultDuration: row[2],
          Db.cDurationUnit: row[3],
          'count_start_day': row[4],
          'include_weekends': row[5],
          'include_holidays': row[6],
          'day_count_mode': row[7],
          'return_day_mode': row[8],
          Db.cSortOrder: row[9],
          Db.cIsActive: 1,
          Db.cCreatedAt: now,
          Db.cUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);

    // ربط أنواع الرخص بالوضعيات المقابلة.
    final Batch linkBatch = db.batch();
    for (final MapEntry<String, String> e
        in SeedData.leaveTypeToStatus.entries) {
      linkBatch.execute(
        '''
UPDATE ${Db.leaveTypes}
   SET ${Db.cStatusTypeId} = (
         SELECT ${Db.cId} FROM ${Db.statusTypes} WHERE ${Db.cName} = ?
       )
 WHERE ${Db.cNameAr} = ?
''',
        <Object?>[e.value, e.key],
      );
    }
    await linkBatch.commit(noResult: true);

    // افتراضات settings.
    for (final MapEntry<String, String> e
        in <String, String>{
          Db.keyLocale: 'ar',
          Db.keyPinEnabled: '0',
          Db.keyBiometricEnabled: '0',
          Db.keyAutoLockMinutes: '5',
          Db.keyAutoLockEnabled: '1',
          Db.keyNotificationsEnabled: '1',
        }.entries) {
      await db.insert(
        Db.settings,
        <String, Object?>{
          Db.cKey: e.key,
          Db.cValue: e.value,
          Db.cUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ── عمومات ───────────────────────────────────────────────────

  /// تنفيذ transaction واحدة — تُستخدم في الاستيراد والـ backup (قاعدة 82).
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      _db.transaction(action);

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? args,
  ]) =>
      _db.rawQuery(sql, args);

  Future<void> rawExecute(String sql, [List<Object?>? args]) =>
      _db.execute(sql, args);

  Future<void> close() async {
    await _db.close();
    _instance = null;
    _cachedPath = null;
  }
}
