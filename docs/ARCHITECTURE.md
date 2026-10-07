# ARCHITECTURE.md — هندسة المشروع

**Clean Architecture / Feature-based**

---

## 1. الفلسفة

```
┌──────────────────────────────────────────────┐
│                  UI (Widgets)                │  ← لا منطق أعمال
├──────────────────────────────────────────────┤
│            Presentation (Controllers)        │  ← Riverpod Notifiers
├──────────────────────────────────────────────┤
│              Domain (Business Logic)         │  ← Services حرة من Flutter
├──────────────────────────────────────────────┤
│        Data (Repositories + DataSource)      │  ← SQLite
├──────────────────────────────────────────────┤
│           Core (DB, Theme, Utils, DI)        │
└──────────────────────────────────────────────┘
```

**قاعدة حاسمة:** لا منطق أعمال داخل `Widget`.
كل `Widget` يستهلك حالة جاهزة ولا يحسب شيئاً.

---

## 2. شجرة المجلدات

```
lib/
├── main.dart                        # نقطة الدخول فقط
├── app.dart                         # MaterialApp + Routing + Theme
│
├── core/
│   ├── constants/                   # ثوابت (أرقام، أسماء جداول)
│   │   ├── app_constants.dart
│   │   └── db_constants.dart
│   ├── database/
│   │   ├── app_database.dart        # sqflite setup + migrations
│   │   ├── schema.dart              # DDL كنصوص
│   │   ├── seed_data.dart           # بيانات أولية
│   │   └── migrations/
│   │       └── migration_v1.dart
│   ├── error/
│   │   ├── app_exception.dart       # أخطاء مفهومة للمستخدم
│   │   └── failure.dart
│   ├── theme/
│   │   ├── app_theme.dart           # Dark Administrative UI
│   │   ├── app_colors.dart
│   │   ├── app_spacing.dart
│   │   └── app_typography.dart
│   ├── utils/
│   │   ├── date_utils.dart          # parse/format/yyyy-mm-dd
│   │   ├── text_normalizer.dart     # بحث عربي/فرنسي
│   │   ├── validators.dart
│   │   ├── debouncer.dart
│   │   └── csv/
│   │       ├── csv_parser.dart      # delimiter detection + quoting
│   │       └── csv_writer.dart      # UTF-8 BOM
│   └── logging/
│       └── app_logger.dart          # بلا بيانات حساسة
│
├── models/                          # نماذج قابلة للتحويل JSON/Map
│   ├── employee.dart
│   ├── section.dart
│   ├── grade.dart
│   ├── function_entry.dart
│   ├── status_type.dart
│   ├── status_history_entry.dart
│   ├── leave_type.dart
│   ├── leave.dart
│   ├── permanence_record.dart
│   ├── holiday.dart
│   ├── audit_log_entry.dart
│   ├── saved_filter.dart
│   └── import_report.dart
│
├── repositories/                    # العقد بين الطبقات
│   ├── employee_repository.dart
│   ├── reference_repository.dart    # sections/grades/functions
│   ├── status_repository.dart
│   ├── leave_repository.dart
│   ├── permanence_repository.dart
│   ├── dashboard_repository.dart
│   ├── audit_repository.dart
│   ├── settings_repository.dart
│   └── filter_repository.dart
│
├── services/                        # منطق الأعمال النقي
│   ├── leave_calculator.dart        # ★ محرك الحساب
│   ├── status_resolver.dart         # ★ الحالات المستنتجة
│   ├── conflict_detector.dart       # ★ اكتشاف التعارض
│   ├── csv_import_service.dart      # ★ الاستيراد + Transaction
│   ├── csv_column_mapper.dart       # ★ Column Mapping
│   ├── backup_service.dart          # ★ تشفير + checksum
│   ├── security_service.dart        # ★ PIN + Biometric
│   ├── export_service.dart          # ★ CSV Export
│   ├── report_service.dart
│   ├── notification_service.dart
│   └── search/
│       ├── search_query.dart        # بناء SQL
│       └── filter_engine.dart       # AND/OR
│
├── features/
│   ├── auth/                        # PIN + Biometric + Auto-lock
│   │   ├── providers/
│   │   └── screens/
│   │
│   ├── splash/
│   │
│   ├── dashboard/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   │
│   ├── employees/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   ├── employees_list_screen.dart
│   │   │   ├── employee_form_screen.dart
│   │   │   ├── employee_profile_screen.dart   # 5 Tabs
│   │   │   └── advanced_search_screen.dart
│   │   └── widgets/
│   │
│   ├── permanence/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   │
│   ├── leaves/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   │
│   ├── import/
│   │   ├── providers/
│   │   ├── screens/                # Preview + Mapping + Result
│   │   └── widgets/
│   │
│   ├── settings/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   │
│   ├── backup/
│   ├── reports/
│   └── shell/                      # Bottom navigation shell
│
├── localization/
│   ├── app_localizations.dart
│   └── l10n/
│       ├── app_ar.arb
│       └── app_fr.arb
│
└── widgets/                        # عناصر عامة قابلة لإعادة الاستخدام
    ├── app_text_field.dart
    ├── app_button.dart
    ├── app_card.dart
    ├── app_dialog.dart
    ├── app_empty_state.dart
    ├── app_error_view.dart
    ├── app_chip.dart
    ├── app_date_field.dart
    ├── app_search_field.dart
    ├── employee_card.dart
    ├── status_badge.dart
    ├── section_header.dart
    └── back_button.dart
```

---

## 3. تدفق البيانات

```
Screen (Widget)
   │  watch / read
   ▼
Riverpod Provider (AsyncNotifier)
   │  استدعاء
   ▼
Repository (عقدة)
   │  SQL
   ▼
AppDatabase (sqflite)
   │
   ▼
SQLite file: app_database.db
```

**مثال ملموس:**

```dart
// employees_list_screen.dart  →  UI فقط
final employeesProvider = AsyncNotifierProvider<
    EmployeesListNotifier, EmployeesListState>(...);

class EmployeesListNotifier extends AsyncNotifier<EmployeesListState> {
  @override
  Future<EmployeesListState> build() async {
    final repo = ref.read(employeeRepositoryProvider);
    return repo.search(SearchQuery.initial());
  }
}
```

---

## 4. حقن التبعيات (DI)

كل شيء عبر **Riverpod Providers** — لا `GetIt`، لا `service_locator`.

```dart
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl(ref.watch(databaseProvider));
});
```

**الفائدة:** في الاختبارات نستبدل `databaseProvider` بقاعدة FFI
أو بـ repository وهمي — بدون تغيير أي widget.

---

## 5. طبقات النماذج

```dart
class Employee {
  final int? id;
  final String matricule;
  final String? nomAr;
  ...
  const Employee({...});

  Employee copyWith({...});                  // للتعديل
  Map<String, dynamic> toMap();              // للـ SQLite/Backup
  factory Employee.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toJson();
  factory Employee.fromJson(Map<String, dynamic> json);
}
```

> النماذج **pure Dart** — لا استيراد `flutter/material`.

---

## 6. معالجة الأخطاء (قاعدة 49)

```dart
class AppException implements Exception {
  final String userMessage;    // يُعرض للمستخدم
  final String? techDetail;    # يُسجَّل فقط في Debug
}
```

**المستخدم يرى:**
> "تعذر استيراد الملف لأن العمود Matricule غير موجود."

**الـ log يرى:**
> `[ERROR] CsvImportService: missing required column 'matricule' (headers: [...])`

لا يظهر `SQLiteException` أو `Null Pointer` أبداً في الواجهة.

---

## 7. Localization (قاعدة 4)

```dart
// ❌ خاطئ
Text('إجمالي الموظفين')

// ✅ صحيح
Text(context.l10n.totalEmployees)
```

- `flutter gen-l10n` يولّد الكود من `app_ar.arb` / `app_fr.arb`.
- الافتراضية: **عربية (RTL)**.
- `MaterialApp.locale` يتحوّل بين `ar` و`fr`.
- كل نص من الملفات — **صفر نصوص داخل الكود**.

---

## 8. التنقل (Rule 6)

```
ShellScreen (IndexedStack + NavigationBar)
├── 0: DashboardScreen
├── 1: EmployeesScreen        ← Navigator داخلي
│      ├── EmployeesListScreen
│      ├── EmployeeProfileScreen   (Push)
│      └── EmployeeFormScreen      (Push)
├── 2: PermanenceScreen       ← Navigator داخلي
├── 3: LeavesScreen           ← Navigator داخلي
└── 4: SettingsScreen         ← Navigator داخلي

AuthGate (فوق كل شيء)
└── LockScreen / BiometricGate
```

- زر رجوع واضح (`AppBar` + `BackButton`) في كل شاشة push.
- حالة كل وجهة محفوظة (`IndexedStack`) → الرجوع لا يفقد الفلتر
  (قاعدة 68).

---

## 9. الأداء (قاعدة 39)

| المشكلة | الحل |
|---|---|
| ListView طويلة | `ListView.builder` + pagination (50/صفحة) |
| بحث أثناء الكتابة | `Debouncer(300ms)` |
| فحص آلاف الصفوف | فهارس SQL + `WHERE` على مستوى القاعدة |
| إعادة بناء شاملة | `select` محدّث + `family` providers |
| Dashboard ثقيل | استعلامات مجمّعة مع `COUNT` في SQL وليس في Dart |

---

## 10. قابلية التوسع (قاعدة 88)

البنية تسمح بإضافة لاحقاً **دون كسر الموجود**:

| الميزة مستقبلاً | كيف تُضاف |
|---|---|
| Cloud Sync | `SyncAdapter` جديد يستهلك نفس الـ repositories |
| Multi User + Roles | جدول `users` + `role` في `audit_logs` |
| Web Dashboard | نفس الـ services عبر HTTP layer منفصل |
| iOS | لا شيء خاص بـ Android في `lib/` |
| API | `RemoteDataSource` بجانب `LocalDataSource` |
| Smart Query | `SmartQueryParser` → نفس `SearchQuery` |
| Local Notifications | `NotificationService` موجود كـ stub نظيف |

**النسخة الأولى لا تبني أي من هذا** — لكن الطرق مفتوحة.

---

## 11. قاعدة البيانات مقابل الواجهة

```
CSV  ──(استيراد، Transaction)──▶  SQLite  ──(SQL)──▶  UI
 ↑                                   │
 │ لا يُقرأ مباشرة أبداً            ├── Dashboard (COUNT)
 │                                   ├── Search (WHERE + INDEX)
 └── مصدر تحديث فقط                 ├── Reports (GROUP BY)
                                     └── Export (SELECT)
```

> **CSV = مصدر استيراد/تحديث. SQLite = قاعدة البيانات الرئيسية.**
