# TESTING.md — خطة الاختبارات

---

## 1. هيكل الاختبارات

```
test/
├── unit/
│   ├── leave_calculator_test.dart        ★ محرك الرخص
│   ├── csv_parser_test.dart              ★ تحليل CSV
│   ├── csv_column_mapper_test.dart       ★ مطابقة الأعمدة
│   ├── date_utils_test.dart              ★ منطق التاريخ
│   ├── search_query_test.dart            ★ بناء البحث
│   ├── filter_engine_test.dart           ★ AND/OR
│   ├── duplicate_detection_test.dart     ★ اكتشاف التكرار
│   ├── status_resolver_test.dart         ★ الحالات المستنتجة
│   ├── conflict_detector_test.dart       ★ التعارضات
│   ├── validators_test.dart
│   ├── text_normalizer_test.dart
│   └── models/
│       └── employee_model_test.dart
│
├── database/
│   ├── schema_test.dart                  ★ DDL + فهارس
│   ├── employee_repository_test.dart
│   ├── leave_repository_test.dart
│   ├── permanence_repository_test.dart
│   ├── status_history_repository_test.dart
│   ├── audit_log_test.dart
│   └── migration_test.dart
│
├── integration/
│   ├── csv_import_employees_test.dart    ★ استيراد كامل
│   ├── csv_import_permanence_test.dart   ★ ربط المداومة
│   ├── backup_restore_test.dart          ★ نسخ/استرجاع
│   └── full_workflow_test.dart
│
└── widget/
    ├── employees_list_screen_test.dart
    ├── employee_card_test.dart
    ├── dashboard_screen_test.dart
    ├── empty_state_test.dart
    └── advanced_search_screen_test.dart
```

---

## 2. قاعدة: الاختبارات تعمل بدون محاكي

`sqflite_common_ffi` يشغّل SQLite حقيقياً على Windows/Linux/macOS.

```dart
// test/helpers/test_db.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> setUpFfi() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
```

**النتيجة:** نفس SQL يُختبَر هنا وعلى الجهاز.

---

## 3. اختبارات Leave Calculator (قاعدة 52)

**القاعدة الذهبية:** كل نتيجة متوقعة تُشتق من `LeaveRuleConfig`
المرفوع في الاختبار — **وليس من قيمة ثابتة في الكود**.

### 3.1 الوحدة `hours`

| # | المدة | count_start_day | startDate | endDate المتوقع |
|---|---|---|---|---|
| H1 | 48 ساعة | 1 | 2026-10-03 | 2026-10-04 |
| H2 | 48 ساعة | 0 | 2026-10-03 | 2026-10-05 |
| H3 | 24 ساعة | 1 | 2026-10-03 | 2026-10-03 |
| H4 | 12 ساعة | 1 | 2026-10-03 | 2026-10-03 |
| H5 | 72 ساعة | 1 | 2026-12-30 | 2027-01-01 |

### 3.2 الوحدة `days` + `calendar`

| # | المدة | count_start_day | startDate | endDate |
|---|---|---|---|---|
| C1 | 1 يوم | 1 | 2026-10-03 | 2026-10-03 |
| C2 | 3 أيام | 1 | 2026-10-03 | 2026-10-05 |
| C3 | 3 أيام | 0 | 2026-10-03 | 2026-10-06 |
| C4 | 15 يوماً | 1 | 2026-10-01 | 2026-10-15 |
| C5 | 2 يوم | 1 | 2026-02-27 (سنة كبيسة) | 2026-02-28 |
| C6 | 5 أيام | 1 | 2026-12-30 | 2027-01-03 |
| C7 | 1 يوم | 1 | 2026-12-31 | 2026-12-31 |

### 3.3 الوحدة `days` + `working`

| # | المدة | weekends | startDate (يوم) | endDate |
|---|---|---|---|---|
| W1 | 3 أيام عمل | Fri+Sat off | 2026-10-01 (Thu) | 2026-10-05 (Mon) |
| W2 | 1 يوم عمل | Fri+Sat off | 2026-10-03 (Fri) | 2026-10-04 (Sat)→ skipped → 2026-10-06 (Sun) |
| W3 | 5 أيام عمل | Fri+Sat off | 2026-10-01 (Thu) | 2026-10-08 (Thu) |
| W4 | 15 يوم عمل | Fri+Sat off | 2026-10-01 (Thu) | يُحسب آلياً |

### 3.4 returnDate

| # | endDate | return_day_mode | weekends | returnDate |
|---|---|---|---|---|
| R1 | 2026-10-09 (Fri) | immediate | — | 2026-10-10 (Sat) |
| R2 | 2026-10-09 (Fri) | next_working_day | Fri+Sat | 2026-10-11 (Sun) |
| R3 | 2026-10-10 (Sat) | next_working_day | Fri+Sat | 2026-10-11 (Sun) |
| R4 | 2026-10-11 (Sun) | next_working_day | Fri+Sat | 2026-10-12 (Mon) |

### 3.5 العطل الرسمية

| # | include_holidays | holiday موجود في endDate+1 | returnDate |
|---|---|---|---|
| HOL1 | 0 | نعم | يتجاوزها (لا يُحتسب) |
| HOL2 | 1 | نعم | يتخطاها → اليوم التالي |

### 3.6 الحالات الحدية

| # | الحالة | النتيجة |
|---|---|---|
| E1 | مدة 0 | خطأ: "المدة يجب أن تكون أكبر من صفر" |
| E2 | مدة سالبة | خطأ |
| E3 | مدة 0.5 يوم | مقبول (يُقرَّب لأعلى) |
| E4 | مدة 48 ساعة بـ `duration_unit = days` وقيمة 48 | يُعامل كـ 48 يوماً |

---

## 4. اختبارات CSV Parser (قاعدة 51)

| # | المدخل | النتيجة |
|---|---|---|
| P1 | `a,b,c\n1,2,3` | delimiter = `,`, صفّان |
| P2 | `a;b;c\n1;2;3` | delimiter = `;` |
| P3 | "a\tb\tc" | delimiter = TAB |
| P4 | `"Smith, John",x` | اقتباس → فاصلة داخل الحقل محفوظة |
| P5 | `"say ""hi""",x` | اقتباس مزدوج مُ escaped |
| P6 | `\r\n` line endings | مدعوم |
| P7 | UTF-8 BOM في البداية | يُزال تلقائياً |
| P8 | نص عربي `بن عيسى` | لا يتشوه (UTF-8) |
| P9 | ملف فارغ | خطأ "الملف فارغ" |
| P10 | صف أعمدته أقل من الرأس | الصف مرفوض مع السبب |
| P11 | 15 عموداً لرأس 12 | الزائدة تُهمل مع تحذير |
| P12 | delimiter غامض `a,b;c` | يُختار الأكثر اتساقاً |

---

## 5. اختبارات البحث (Rule 25)

| # | الاستعلام | النتائج المتوقعة |
|---|---|---|
| S1 | `Ahmed` | `Ahmed Mohamed`, `AHMED ALI` |
| S2 | `أحمد` | `أحمد محمد` |
| S3 | `  ahmed  ` (مسافات) | = `ahmed` |
| S4 | `AHMED` | = `ahmed` (غير حساس) |
| S5 | `12547` | بحث بـ matricule |
| S6 | `0555` (بادئة هاتف) | بحث جزئي بالهاتف |
| S7 | `zzzz` | لا نتائج → Empty State |
| S8 | `محمد` + `قسم` | بحث مركب |

---

## 6. اختبارات الفلترة (Rule 27)

| # | المعايير | المنطق |
|---|---|---|
| F1 | Section=RH AND Status=En service | تقاطع |
| F2 | Section=RH OR Section=Finances | اتحاد |
| F3 | Section=RH AND (Status=Maladie OR Status=Suspendu) | مركب |
| F4 | تاريخ بدء → تاريخ نهاية | نطاق |
| F5 | بدون معايير | كل السجلات |

---

## 7. اختبارات اكتشاف التكرار (Rule 10)

| # | الحالة | النتيجة |
|---|---|---|
| D1 | matricule جديد | Insert (جديد) |
| D2 | matricule موجود | Update (لا يمسّ التاريخ) |
| D3 | matricule جديد + ppr موجود | Update عبر ppr |
| D4 | matricule مكرر داخل الملف | رفض الصف الثاني |
| D5 | ppr فارغ + matricule جديد | Insert |
| D6 | ملف: 250 صف (210جديد + 35تحديث + 5مكرر) | الأرقام مطابقة |

---

## 8. اختبارات قاعدة البيانات

| # | الاختبار |
|---|---|
| DB1 | كل الجداول تُنشأ |
| DB2 | كل الفهارس موجودة |
| DB3 | Foreign Keys مفعّلة |
| DB4 | حذف موظف → cascade لـ status_history/leaves |
| DB5 | matricule مكرر → `Conflict` من SQLite |
| DB6 | `is_active = 0` لا يحذف السجل |
| DB7 | بحث بفهرس على 5000 موظف < 200ms |
| DB8 | Migration v1 → v2 تحتفظ بالبيانات |

---

## 9. اختبارات Backup/Restore (Rule 33)

| # | الاختبار |
|---|---|
| B1 | إنشاء backup → الملف موجود + `schema_version` |
| B2 | SHA-256 checksum صحيح |
| B3 | تخريب بايت → "ملف تالف" ويُرفض |
| B4 | كلمة مرور خاطئة → يُرفض |
| B5 | backup v1 → restore على v1 → كل الجداول مطابقة |
| B6 | restore يلغي أي بيانات متبقية بعد النجاح |
| B7 | كل عملية backup تُسجَّل في audit_logs |

---

## 10. أوامر التشغيل

```bash
# كل الاختبارات
flutter test

# وحدة فقط
flutter test test/unit

# تغطية
flutter test --coverage

# اختبار تكاملي (يحتاج جهاز/محاكي)
flutter test integration_test

# تحليل الجودة
flutter analyze

# بناء APK
flutter build apk --release
```

---

## 11. معايير القبول

- ✅ `flutter analyze` → **0 errors, 0 warnings**
- ✅ `flutter test` → **كل الاختبارات خضراء**
- ✅ `flutter build apk --release` → **يبني بدون خطأ**
- ✅ لا يوجد `TODO` أو `Coming Soon` في وظائف مكتملة
- ✅ كل زر يعمل فعلياً مع SQLite حقيقي

---

## 12. الحالة الفعلية (يُحدَّث بعد كل مرحلة)

**الأمر والنتيجة:**

```
flutter analyze   → No issues found
flutter test      → 463/463 ✅  (الزمن ≈ 55 ثانية)
```

| الملف | الاختبارات | الحالة |
|---|---:|---|
| `unit/leave_calculator_test.dart` | 40 | ✅ |
| `unit/search_query_test.dart` | 34 | ✅ |
| `unit/text_normalizer_test.dart` | 20 | ✅ |
| `unit/status_resolver_test.dart` | 15 | ✅ |
| `unit/conflict_detector_test.dart` | 21 | ✅ |
| `unit/csv_parser_test.dart` | 27 | ✅ |
| `unit/csv_column_mapper_test.dart` | 21 | ✅ |
| `unit/csv_writer_test.dart` | 17 | ✅ |
| `unit/import_planner_test.dart` | 27 | ✅ |
| `integration/employee_search_test.dart` | 47 | ✅ |
| `integration/status_repository_test.dart` | 28 | ✅ |
| `integration/leave_repository_test.dart` | 35 | ✅ |
| `integration/permanence_repository_test.dart` | 28 | ✅ |
| `integration/settings_repository_test.dart` | 19 | ✅ |
| `integration/dashboard_repository_test.dart` | 13 | ✅ |
| `integration/filter_repository_test.dart` | 20 | ✅ |
| `integration/backup_restore_test.dart` | 19 | ✅ |
| `integration/security_service_test.dart` | 24 | ✅ |
| `integration/csv_import_test.dart` | 7 | ✅ |
| `widget_test.dart` | 1 | ✅ |
| **المجموع** | **463** | ✅ |

### ما تغطيه الاختبارات فعلياً

- **قاعدة 61 (البحث):** كل حالة S1–S8 تُشغَّل على SQLite حقيقي
  (`sqflite_common_ffi`) لا على نص مولّد — 47 اختباراً تكاملياً
  تشمل الترقيم، العمليات، والحقن.
- **قاعدة 25 (التطبيع):** `text_normalizer_test` يثبّت أن
  **الطرفين** يتطابقان: `أحمد = احمد`، `générale = generale`،
  `المالية = الماليه`.
- **قاعدة 9 (الاستيراد):** مسار إنتاج كامل (معاينة بلا كتابة →
  تنفيذ → سجل) بما فيه **التحديث الجزئي** الذي لا يطمس الحقول
  غير الواردة في الملف.
- **قواعد 44/84 (الاشتقاق):** `status_resolver_test` (نقي) +
  `status_repository_test` (SQLite حقيقي) يثبتان أن **المصدر يسبق
  الأولوية**، وأن أولوية الوضعية **تُقرأ من الجدول** — فتعديلها
  من الواجهة يغيّر الفائز فوراً (اختبار يغيّر `priority` ثم يعيده).
- **قاعدة 45 (التعارض):** التلامس بيوم واحد = تداخل، الطرف
  المفتوح، الرخص الملغاة، والمعرّفات المتطابقة بين جدولين
  **لا** تُلغي المقارنة.
- **قواعد 17/18 (المحرّك والجدول):** `leave_repository_test`
  يثبت أن مدة «عطلة إدارية» تأتي من `leave_types` لا من الكود
  — يغيّر `duration` إلى 5 فيتغيّر تاريخ النهاية، وأن وحدة
  الساعات تبقى ساعات (`48h` لا `2d`) في `raw_duration`.
- **قاعدة 31/D-008 (الإلغاء):** بعد `cancel` يبقى `total = 1`
  بفلتر `includeCancelled`، و`created_at` كما كان — أي أن
  `uncancel` وحده يعيد الحالة ولا يوجد `DELETE`.
- **قاعدة 45 (الرفض بلا نصف كتابة):** كل رفض تعارض يعقبه فحص
  أن العدد لم يزد، وفحص أن `startDate` القديم ما زال كما هو
  بعد `update` مرفوض.
- **قاعدة 10/D-010 (المداومة):** الفريد مُختبر من ثلاث زوايا —
  نفس المفتاح مرتين → قيد فريد **برسالة عربية**؛ فترتان
  مختلفتان لنفس الموظف → سجلان مقبولان؛ ربط سجل بموظف محجوز
  لغيره → رفض برسالة تشرح التعارض لا `UNIQUE constraint failed`.
  ورقم ترقيم مجهول **لا ينشئ موظفاً** — يُقاس `COUNT(*)`
  قبل الكتابة وبعدها.
- **الافتراضيات من القاعدة لا من الكود:** `settings_repository_test`
  يقرأ `locale/pin/auto_lock` من الجدول المزروع، ويتحقق أن قيمة
  تالفة (`abc` في زمن القفل، `yes` في علم، JSON مكسور)
  تُعامَل كافتراضي **دون رمي** — المستخدم لا يرى `FormatException`.
- **اللقطة الواحدة للوحة:** `dashboard_repository_test` يفتح
  **قاعدة جديدة في كل اختبار** لأن اللوحة تعدّ عدّاً عامّاً —
  العدّ المتراكم كان سيخفي الخطأ بدل أن يكشفه. يُثبَّت أن
  مجموع `statusCounts` يساوي عدد النشطين **بالضبط** (بلا وضعية =
  المفتاح `0`)، وأن المعطَّلين والمداومة لغير اليوم والرخص
  الملغاة لا تدخل العدّ، وأن تعادل أولوية **داخل المصدر الواحد**
  يظهر كتنبيه ولا يُحسب مرتين.
- **قاعدة 14/D-008:** اختبار الإغلاق يتحقق أن العدد **لا ينقص**
  بعد `endOpenEntry` — الإغلاق ليس حذفاً.
- **الأمن:** حقن SQL يُجرَّب على قاعدة حقيقية (`DROP TABLE`،
  `' OR '1'='1`، `%`، `_`) وتبقى البيانات سليمة.
- **الفلاتر المحفوظة:** `filter_repository_test` يثبت أن الاستعلام
  المحفوظ يعود **كاملاً** (معيار متداخل `group` + منطق `OR`)، وأن
  الصف يُكتب بمخططه §10 (`criteria` JSON و`logic` عمود مستقل)،
  وأن **الاسم فريد عالمياً** كما يفرض `uq_saved_filter_name` —
  الفحص يسبق الكتابة فلا يرى المستخدم `constraint failed`. ويقيس
  حياد الجدول عملياً: 8 عمليات متوازية → 8 صفوف فعلاً؛ وسبعة
  صفوف تالفة (JSON فاسد، صيغة خاطئة، نوع مجهول، اسم فارغ) تُتجاهَل
  واحداً تلو الآخر حتى لو طُلب الصف التالف بالتحديد.
- **النسخ الاحتياطي (D-012):** `backup_restore_test` يشغّل التشفير
  فعلياً: يبحث في الملف عن الرقم والاسم والهاتف و**كلمة المرور**
  فلا يجد شيئاً؛ يقلب بايتاً في الشيفرة فلا تقبل البصمة SHA-256؛
  ويقلب بايتاً في الترويسة فلا يظهر إلا `AppException` عربية.
  الذرّية مُثبتة بالعكس: ملف بصفّ مكرر (`UNIQUE`) يفشل داخل
  المعاملة **فيعدّ الموظفين كما كانوا (2) والمراجع كما كانت (9)**
  — لا حذف جزئي. وسياسة `settings` مُثبَّتة أيضاً: مفتاح الاستيراد
  يعود من النسخة، و`locale` و`pin_hash` و`auto_lock` **لا يعودون
  أبداً**.
- **الأمن (D-012/D-022):** `security_service_test` يشغّل PBKDF2
  فعلياً (120 ألف تكرار) ويقيس أن **لا رمز صريح في المخزَّن**
  (بحث `1234` داخل المجزّأة يفشل)، وأن الملحّ **عشوائي** — نفس
  الرمز مرتين يعطي مخرَّجين مختلفين يتحقّقان معاً — وأن المقارنة
  بزمن ثابت. إدخال غير صالح (`123`، `12a4`، عربي-هندي `١٢٣٤`)
  يُرمي `AppException` عربية **قبل أي كتابة**، أمّا `verifyPin`
  فلا يرمي أبداً ويعدّي `false`. البصمة مُحاطة بواجهة تُحقن
  بقارئ وهمي، فيُثبت أن المنصّة **غير مفعّلة لا تُستدعى أصلاً**
  (عدّاد الاستدعاء = 0)، وأن سبب الترجمة يصل كما هو، وأن إخفاق
  المنصّة يعود `false` لا استثناء. القفل التلقائي: الافتراضي 5
  دقائق، الخيارات {1, 5, 15} وحدها، والـ«معطّل» = `Duration.zero`
  مع **إعادة تفعيل** عند اختيار زمن جديد. وفي كل ذلك يبقى سجل
  التدقيق خالياً من الرمز (`isNot(contains('1234'))`).

### أخطاء حقيقية كشفتها الاختبارات والتدقيق (وليست توقعات خاطئة)

1. `LIKE '%احمد%'` لا يطابق `أحمد` → عمود `search_text` (D-014).
2. مسار تحديث الاستيراد يكتب `search_text` ناقصاً →
   إعادة البناء من الصف المدموج.
3. `ReferenceRepository` استعملت الجذرية داخل `Transaction` →
   **علّق دائم** عند أول استيراد ينشئ مرجعاً (D-019).
4. `_buildLookup` طلب `name_fr` من `sections` →
   `no such column`.
5. `upsertEntry`/`createEntry` لم تكتبا `search_text`.
6. `endOpenEntry` كُتبت بـ `UPDATE ... WHERE h.employee_id` على
   `db.update()` → SQL غير صالح (لا اسم جدول مُرقَّم) →
   حوِّلت إلى `rawUpdate`.
7. مقارنة معرّف سجل الوضعية بمعرّف رخصة **بين جدولين** كانت
   تُلغي تعارضاً حقيقياً → أُلغيت المقارنة بين الجدولين.
8. `PermanenceRepository._from` كان ينتهي عند `employee_id`
   **بلا مسافة** فصار `employee_idWHERE (...)` → `syntax error`.
   أُضيف سطر جديد في نهاية المكوّن نفسه، فصار `$_select`
   و`COUNT(*)` يستعملان النهاية نفسها بشرط واحد.
9. `FilterRepository._read` (في النسخة الأولى) كانت تُرجع
   `const <SavedFilter>[]` لصفّ/مفتاح غائب → قائمة **غير قابلة
   للتعديل** → أول `add` يرمي `Cannot add to an unmodifiable
   list`. أُلغيت `const` لأن القائمة تُملأ لاحقاً.
10. النسخة الأولى حفظت الفلاتر في `settings` كـ JSON **بمفتاح
    اسمه `saved_filters` — نفس اسم الجدول** الموجود في المخطط §10
    → تعارض مباشر مع قاعدة 72 (المخطط المرجع)، مع تجاهل قيد
    `uq_saved_filter_name`. أُعيدت كاملة على الجدول الفعلي.
11. `local_auth` 3.0.2 **لا تصدِّر** `AuthenticationOptions` —
    استدعاء `authenticate(options: ...)` رمى
    `undefined_named_parameter` + `creation_with_non_type`. صار
    الاستدعاء مسطّحاً: `biometricOnly: true` و
    `persistAcrossBackgrounding: true`.
12. `models/audit_log_entry.dart` كان يحوي **عرضاً ميتاً** من مرحلة
    سابقة: `class SavedFilter` يطابق جدول `saved_filters` بترتيب
    حقول مختلف. بعد إضافة `models/saved_filter.dart` صار **صنفان
    متطابقاً بنفس الاسم** في `lib/models/` → أي ملف يستورد الاثنين
    كان سيفشل `ambiguous_import`. حُذف الميت (لم يستعمله شيء).

### لم تُكتب بعد (المراحل التالية)

`date_utils_test`، `filter_engine_test`، `duplicate_detection_test`،
`validators_test`، وحقّقات الواجهة.
