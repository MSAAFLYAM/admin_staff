import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../../repositories/audit_repository.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/filter_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../repositories/permanence_repository.dart';
import '../../repositories/reference_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/status_repository.dart';
import '../../services/backup_service.dart';
import '../../services/import/csv_import_service.dart';
import '../../services/security_service.dart';

/// قاعدة البيانات — تُفتح **مرة واحدة** في عمر التطبيق.
///
/// كل الشاشات تراقبها عبر `.when(...)` فلا يُبنى أي مستودع قبل
/// جاهزية القاعدة (D-023: على سطح المكتب يُبدَّل المحرّك تلقائياً).
final FutureProvider<AppDatabase> appDatabaseProvider =
    FutureProvider<AppDatabase>((ref) => AppDatabase.instance());

// ── المستودعات (كلها خفيفة، تُبنى فوق نفس القاعدة) ─────────────

final Provider<AuditRepository> auditRepositoryProvider =
    Provider<AuditRepository>(
  (ref) => AuditRepository(ref.watch(appDatabaseProvider).requireValue),
);

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider).requireValue),
);

final Provider<ReferenceRepository> referenceRepositoryProvider =
    Provider<ReferenceRepository>(
  (ref) => ReferenceRepository(ref.watch(appDatabaseProvider).requireValue),
);

final Provider<StatusRepository> statusRepositoryProvider =
    Provider<StatusRepository>(
  (ref) => StatusRepository(ref.watch(appDatabaseProvider).requireValue),
);

final Provider<EmployeeRepository> employeeRepositoryProvider =
    Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(ref.watch(appDatabaseProvider).requireValue),
);

final Provider<FilterRepository> filterRepositoryProvider =
    Provider<FilterRepository>(
  (ref) => FilterRepository(ref.watch(appDatabaseProvider).requireValue),
);

final Provider<LeaveRepository> leaveRepositoryProvider =
    Provider<LeaveRepository>(
  (ref) => LeaveRepository(
    ref.watch(appDatabaseProvider).requireValue,
    ref.watch(statusRepositoryProvider),
  ),
);

final Provider<PermanenceRepository> permanenceRepositoryProvider =
    Provider<PermanenceRepository>(
  (ref) => PermanenceRepository(
    ref.watch(appDatabaseProvider).requireValue,
    ref.watch(statusRepositoryProvider),
  ),
);

final Provider<DashboardRepository> dashboardRepositoryProvider =
    Provider<DashboardRepository>(
  (ref) => DashboardRepository(
    ref.watch(appDatabaseProvider).requireValue,
    ref.watch(statusRepositoryProvider),
  ),
);

// ── الخدمات ────────────────────────────────────────────────────

final Provider<CsvImportService> csvImportServiceProvider =
    Provider<CsvImportService>(
  (ref) => CsvImportService(
    ref.watch(appDatabaseProvider).requireValue,
    ref.watch(referenceRepositoryProvider),
    ref.watch(auditRepositoryProvider),
  ),
);

final Provider<BackupService> backupServiceProvider =
    Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(appDatabaseProvider).requireValue,
    audit: ref.watch(auditRepositoryProvider),
  ),
);

final Provider<SecurityService> securityServiceProvider =
    Provider<SecurityService>(
  (ref) => SecurityService(
    ref.watch(appDatabaseProvider).requireValue,
    audit: ref.watch(auditRepositoryProvider),
  ),
);

// ── مراجعة البيانات ────────────────────────────────────────────

/// عدّاد يرتفع بعد **كل** كتابة في القاعدة — تراقبه شاشات التبويب
/// (لوحة القيادة مثلاً) فتُعاد قراءتها تلقائياً بعد أي إضافة/تعديل.
class DbRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final NotifierProvider<DbRevision, int> dbRevisionProvider =
    NotifierProvider<DbRevision, int>(DbRevision.new);
