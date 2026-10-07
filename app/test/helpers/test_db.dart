import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/models/employee.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// تجهيز SQLite حقيقي عبر `sqflite_common_ffi` — **بدون محاكي**.
///
/// نفس الـ SQL يعمل هنا (Windows/Linux/macOS) وعلى الجهاز.
Future<void> setUpFfi() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// يفتح قاعدة **في الذاكرة** مع المخطط والبيانات الأولية.
///
/// يستدعي [AppDatabase.createSchema] و[AppDatabase.seed] **بنفسيهما** —
/// لا نسخة ثانية من الـ seed، فلا يمكن أن ينحرف الاختبار عن الإنتاج.
///
/// نستخدم `inMemoryDatabasePath` حتى لا نترك ملفات في القرص
/// ولا تتعارض اختبارات متوازية.
Future<Database> openTestDb() async {
  return databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: Db.schemaVersion,
      singleInstance: false,
      onConfigure: (Database d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database d, int version) async {
        await AppDatabase.createSchema(d);
        await AppDatabase.seed(d);
      },
    ),
  );
}

/// يغلق القاعدة و**يلغي الـ singleton** حتى لا تتسرب بين الاختبارات.
Future<void> closeTestDb(Database db) async {
  await db.close();
  AppDatabase.resetInstance();
}

/// أرقام ترقيم الموظفين من قائمة [Employee].
List<String> matriculesOf(List<Employee> items) =>
    items.map((Employee e) => e.matricule).toList();

/// أرقام ترقيم الموظفين في صفوف SQL الخام.
List<String> matriculesOfRows(List<Map<String, Object?>> rows) => rows
    .map((Map<String, Object?> r) => (r['matricule'] as String?) ?? '')
    .toList();
