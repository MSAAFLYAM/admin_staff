# CHANGELOG.md — سجل التغييرات

كل تغيير جوهري في المشروع يُسجَّل هنا.

---

## [0.1.0] — 2026-10-03

### PHASE 0 — تحليل البيئة ✅

**البيئة المكتشفة:**

| العنصر | الحالة |
|---|---|
| OS | Windows 10 Pro |
| Flutter | ❌ غير مثبّت |
| Dart | ❌ غير مثبّت |
| JDK | ❌ غير مثبّت |
| Android SDK | ❌ غير مثبّت |
| Git | ✅ 2.54.0 |
| winget | ✅ 1.29.380 |
| choco | ✅ 2.7.2 |
| مساحة C: | 14.7 GB حرة |
| مساحة D: | 4.6 GB حرة |
| الشبكة | ✅ Flutter storage, dl.google.com, pub.dev متاحة |

**القرارات:**
- D-001: Flutter stable 3.47.6 (Dart 3.13.5)
- D-002: Riverpod لإدارة الحالة
- D-003: sqflite + sqflite_common_ffi
- D-004: تخزين Calendar Date كنص ISO-8601

**الأدوات المثبّتة:**

| الأداة | الإصدار | التكلفة |
|---|---|---|
| Temurin JDK | 17.0.20.1+1 | $0 |
| Android cmdline-tools | 13114758 | $0 |
| Android platform-tools | latest | $0 |
| Android platform | android-35 | $0 |
| Android build-tools | 35.0.0 | $0 |
| Flutter SDK | 3.47.6 stable | $0 |

**ملاحظة أداء:** `Invoke-WebRequest` كان بـ 105 KB/s،
تم التبديل إلى `curl.exe` → 5.5 MB/s (×52 أسرع).

---

### PHASE 1 — المشروع + Theme + Localization + Navigation ✅

**ملفات تم إنشاؤها:**

**التوثيق:**
- `README.md`
- `COSTS.md`
- `TESTING.md`
- `CHANGELOG.md`
- `docs/ARCHITECTURE.md`
- `docs/DATABASE.md`
- `docs/IMPORT_FORMAT.md`
- `docs/LEAVE_RULES.md`
- `docs/DECISIONS.md`

**عيّنات البيانات:**
- `sample_employees.csv` — 15 موظفاً
- `sample_permanence.csv` — 18 سجل مداومة

---

### PHASE 2 — SQLite Schema + Models + Repositories ✅

**القاعدة:**

- `lib/core/constants/db_constants.dart` — أسماء الجداول/الأعمدة
- `lib/core/database/schema.dart` — **مصدر واحد** لـ DDL
- `lib/core/database/seed_data.dart` — بيانات البداية (حالة/رخصة)
- `lib/core/database/app_database.dart` — `createSchema` و`seed`
  **منشوران** كدوال ثابتة يستعملهما الإنتاج **والاختبار معاً**،
  فلا يمكن أن ينحرف الاختبار عن المخطط

**النماذج:** `reference_entries.dart` (Section/Grade/FunctionEntry)،
`status_type.dart`، `employee.dart`، `leave.dart`،
`permanence_record.dart`، `audit_log_entry.dart`

**المستودعات:** `reference_repository`، `employee_repository`،
`audit_repository`

**الأدوات:** `app_date.dart`، `validators.dart`، `text_normalizer.dart`،
`debouncer.dart`، `app_exception.dart` (رسائل عربية، لا أخطاء SQLite خام)

---

### PHASE 3 — البحث والتصفية (Core) ✅

**`lib/core/query/search_query.dart`**

- `SearchQuery` / `FilterSet` / `FilterCriterion` + `SearchQueryBuilder`
- بحث نصي بكل الكلمات (AND بين الكلمات، OR بين الأعمدة)
- `LIKE` مهرَّب + `ESCAPE '\'` + كل القيم في `args` (لا حقن SQL)
- ترقيم داخل SQL (`LIMIT`/`OFFSET`) — لا تحميل الكل في الذاكرة
- **مجموعات متداخلة** `FilterCriterion.group` لـ `A AND (B OR C)` (D-018)

**عمود `search_text` المطبَّع** (قاعدة 61 / D-014)

| المشكلة | `LIKE '%احمد%'` لا يطابق `أحمد` — `LOWER()` في SQLite لاتينية فقط |
|---|---|
| الحل | نطبّع عند الكتابة ونخزّن النتيجة في `search_text` |
| المتطابقات | `employees`، `sections`، `grades`، `functions` |
| الفائدة | 4 أعمدة بدل 11 → أسرع **و** صحيحة للعربية والفرنسية |

يتضمّن طيّ الحروف اللاتينية المُشكَّلة: `générale = generale`.

**إصلاحات جوهرية في هذه المرحلة:**

1. **`_reindex` في مسار تحديث الاستيراد** — ملف يحوي `matricule`
   فقط كان سيكتب `search_text` ناقصاً ويطمس الاسم العربي.
   الحل: إعادة بناء النص من الصف **المدموج** (الوارد + المحفوظ).
2. **`ReferenceRepository` داخل `Transaction`** — استيراد ينشئ
   قسماً جديداً كان يعلّق إلى الأبد (`database has been locked`).
   الحل: كل الدوال تقبل `DatabaseExecutor? txn` (D-019).
3. **`_buildLookup` طلب `name_fr` من جدول لا يملكه** —
   `no such column: name_fr` عند أول استيراد فيه قسم جديد.
4. **`upsertEntry`/`createEntry` لم يكتبا `search_text`.**

**الاختبارات:** `test/unit/search_query_test.dart` (34) +
`test/integration/employee_search_test.dart` (47) على SQLite حقيقي
عبر `sqflite_common_ffi` — لا محاكي، لا توقعات على النص.

---

### PHASE 4 — استيراد CSV (تكامل) ✅

`test/integration/csv_import_test.dart` — 7 اختبارات تمرّ بمسار
الإنتاج الكامل: معاينة بلا كتابة، إدراج جديد، إنشاء قسم بـ
`search_text`، **تحديث جزئي لا يطمس الحقول غير الواردة**، ثبات
`created_at`، تكرار `matricule` في الملف الواحد.

`test/unit/text_normalizer_test.dart` — 20 اختباراً لقاعدة 25.

---

### PHASE 5 — الوضعيات المشتقة والتعارضات ✅

**الملفات الجديدة:**

| الملف | الدور |
|---|---|
| `lib/services/status_resolver.dart` | D-006 / قاعدة 44 — منطق نقي بلا SQLite |
| `lib/services/conflict_detector.dart` | D-007 / قاعدة 45 — كشف التداخل |
| `lib/repositories/status_repository.dart` | `status_history` + الاشتقاق |

**قواعد الاشتقاق (منطق `StatusResolver`):**

1. المصدر: `status_history` ← `leaves` ← `employees.current_status_id`
2. ثم `priority` تنازلياً (من الجدول، **ليس** من الكود — قاعدة 13/84)
3. ثم أحدث `start_date`
4. تعادل أولوية داخل المصدر نفسه → `isAmbiguous = true`
   فتعرض الواجهة `Conflict Detected` ولا تُطبِّق تلقائياً (قاعدة 45)

**قواعد التعارض (`ConflictDetector`) — كلها نقيّة:**

- الفترتان شاملتان: التلامس في يوم واحد = تداخل
- الطرف المفتوح (`end_date = NULL`) = لا نهاية له
- الرخص الملغاة (`is_cancelled = 1`) تُتجاهل
- المقارنة تتم داخل الجدول نفسه فقط — لا مقارنة معرّفات بين جدولين
- رسالة عربية جاهزة تحوي فترة التداخل بالضبط

**قاعدة الأداء:** `derivedForAll()` تبني اشتقاق **كل** الموظفين
بـ **3 استعلامات فقط** (لا `N+1`) — للوحة وقوائم النتائج.

**قاعدة 14/D-008:** `endOpenEntry` و`closeEntry` يكتبان `end_date`،
وليس هناك `DELETE` واحد في الملف كله.

**الاختبارات:**

| الملف | الاختبارات |
|---|---:|
| `unit/status_resolver_test.dart` | 15 |
| `unit/conflict_detector_test.dart` | 21 |
| `integration/status_repository_test.dart` | 28 |

---

### PHASE 6 — مستودع الرخص ✅

**الملفات الجديدة/المعدَّلة:**

| الملف | الدور |
|---|---|
| `lib/repositories/leave_repository.dart` | جديد — قراءة/كتابة `leaves` + الحساب + التعارض |
| `lib/repositories/status_repository.dart` | أُضيف `overlapping(from, to)` |
| `lib/services/conflict_detector.dart` | أُضيف `ConflictException` |
| `lib/core/query/search_query.dart` | `escapeLike` صار علنياً (مصدر واحد للهروب) |

**فصل المهام (لا خوارزمية في المستودع):**

| السؤال | من يجيب |
|---|---|
| ما تاريخ النهاية والعودة؟ | `LeaveCalculator` (قاعدة 18) |
| ما المدة ووحدة العدّ ووضعية العودة؟ | `leave_types` من الجدول (قاعدة 17) |
| هل هناك تداخل؟ | `ConflictDetector` (قاعدة 45) |
| ماذا تكتب في القاعدة؟ | `LeaveRepository` وحده |

**قاعدة 45 — الحفظ لا يتم إلا بعد قرار المستخدم:**

`create`/`update` يستدعيان `conflictsFor` أولاً؛ عند وجود تعارض
يُرمى `ConflictException` حاملة **القائمة كاملة** (النوع، الرسالة،
فترة التداخل) ورسالة تبدأ بـ `Conflict Detected`. المرور إلى
الكتابة يتطلب `userConfirmed: true` — أي أن الواجهة عرضت الحوار
وافق المستخدم. لا تطبيق تلقائي.

**قاعدة الأداء:** `conflictsFor` و`overlapping` تقرآن **صفوف
الفترة فقط** عبر فهارس `leaves(employee_id, start_date, end_date)`
و `status_history(employee_id, start_date, end_date)` — لا مسح
جدول، ولا `N+1`.

**قاعدة 31/D-008:** `cancel` يضبط `is_cancelled = 1`، و`uncancel`
يعيده إلى `0`، ولا يوجد `DELETE` واحداً في الملف.

**قاعدة 18 (المحرّك مصدر الحقيقة):** `update` يعيد بناء السجل
بالمحرّك قبل الكتابة — لا يمكن أن تختلّ `end_date`/`return_date`
عن حسابها. كما لا يمكن نقل رخصة لموظف آخر (المعرّف يُقرأ من
الصف المحفوظ لا من المدخل).

**قاعدة 61:** `search` يبني `COUNT` و`SELECT` على نفس شرط
`SqlWhere` مع `LIMIT/OFFSET` داخل SQL، والنص الحرّ يمرّ عبر
`escapeLike` **نفس** استعمال البحث العام.

**الاختبارات:** `test/integration/leave_repository_test.dart` —
35 اختباراً على SQLite حقيقي (حصريّة تكامل، لا وحدات مكرّرة).

---

### PHASE 7 — مستودع المداومة ✅

**الملفات الجديدة/المعدَّلة:**

| الملف | الدور |
|---|---|
| `lib/repositories/permanence_repository.dart` | جديد — قراءة/كتابة `permanence` + المطابقة |
| `lib/core/utils/date_input.dart` | جديد — مصدر واحد لتوحيد التاريخ + رسائله |
| `lib/models/permanence_record.dart` | `copyWith` تقبل `derivedStatusName` |

**قاعدة 10 / D-010 — المفتاح الثلاثي:**

`(date, employee_id, time_slot)` — والمفتاح يأتي من `start_time`
حين لا يُملأ. ثلاثة سلوكيات مقصودة:

1. **مربوط** → الفريد يعمل: نفس اليوم والفترة لموظف واحد = رفض
   برسالة عربية تشرح التعارض.
2. **غير مربوط** (`employee_id IS NULL`) → الفريد الجزئي لا
   يغطيه، فيُطابَق بـ `(date, matricule, time_slot)` عند `upsert`.
3. **فترتان مختلفتان** لموظف واحد في اليوم → مقبولان (الفترة
   جزء من المفتاح).

**قاعدة الاستيراد (لا إنشاء موظفين):** `insert` تبحث عن
`matricule` في `employees` وتربط إن وُجد، وإلا تبقى
`employee_id = NULL` — لا استعلام إدراج موظف واحد في الملف،
ويُثبَّت ذلك باختبار يقيس `COUNT(*)` قبل وبعد.

**لماذا `DELETE` هنا ولا في غيره؟** المداومة جدول **مواعيد**
يُستبدل كاملاً بملف أسبوعي جديد (وضع «استبدال الفترة»)، لا
سجلاً تاريخياً — `employees`/`leaves`/`status_history` تبقى
مالكة دائماً (D-008).

**قاعدة 61:** `LEFT JOIN employees` لا `INNER` — وإلا
اختفى «غير مطابِق» من القوائم بالضبط حين يحتاجها المستخدم.
والترتيب **زمني تصاعدي** لأن المداومة مواعيد لا تاريخ.

**الاشتقاق:** `forDate` تملأ `derived_status_name` باستعلام
اشتقاق **واحد** لكامل اليوم (لا استعلام لكل صف).

**الاختبارات:** `test/integration/permanence_repository_test.dart`
— 28 اختباراً.

---

### PHASE 8 — مستودع الإعدادات ✅

**الملفات:** `lib/repositories/settings_repository.dart` (جديد).

| القاعدة | التطبيق |
|---|---|
| لا رقم مُثبَّت في الكود | الافتراضيات تُقرأ من `AppDatabase.seed`؛ `fallback` يُستدعى فقط عند غياب المفتاح |
| قاعدة 49 | قيمة تالفة (`abc` في auto-lock، `yes` في علم، JSON مكسور) → افتراضي **بلا استثناء** |
| قاعدة 42 | `writeMany` داخل معاملة واحدة — لا إعداد ناقص |
| الأمان | `clearPinSecrets` يحذف `pin_hash`+`pin_salt` معاً |

واجهات نوعية (`locale()`، `flag()`، `autoLockMinutes()`)
حتى لا تنشر الواجهات نصوص `'1'`/`'0'` في كل مكان.

**التوحيد المشترك:** `DateInput.iso` / `DateInput.isoOrNull`
صار المصدر الوحيد لرسالة التاريخ غير الصالح — استُعمل في
`status_repository` و`leave_repository` و`permanence_repository`
بلا نسخة ثانية.

**الاختبارات:** `test/integration/settings_repository_test.dart`
— 19 اختباراً.

---

### PHASE 9 — مستودع اللوحة ✅

**الملفات:** `lib/repositories/dashboard_repository.dart` (جديد)
— `DashboardSummary` + `summary({on})` + `bySection({activeOnly})`.

**لقطة واحدة لا بطاقة واحدة استعلاماً** — كل أرقام الشاشة تُحسب
في مناداة واحدة، بلا `N+1`، وكلها على فهارس `date` /
`end_date` / `return_date` / `is_active`.

**كل رقم من الجداول لا من الكود (قاعدة 17/84):**

| الرقم | مصدره |
|---|---|
| النشطون / المعطَّلون | `employees.is_active` |
| الحالات (في الخدمة، موقوف، …) | اشتقاق `StatusRepository.derivedForAll(on:)` مرتَّب بـ `status_types.priority` |
| مداومة اليوم / غير المربوطة | `permanence.date` |
| الرخص المنتهية اليوم/غداً/بعد 3 أيام | `leaves.end_date` + `is_cancelled = 0` |
| العائدون اليوم | `leaves.return_date` |
| التنبيهات | تعارضات الاشتقاق + غير المربوطة |

**قرار:** تجميع الوضعيات **يُستبعد منه غير النشط** —
`status_history` قد يحمل سجلاً مفتوحاً لموظف أُرشف، وإلا
لظهر في «في الخدمة» بعد تقاعده. والمفتاح `0` يعني صراحةً
«بلا وضعية» حتى لا يُحسب النقص تحت اسم وضعية حقيقية.

**التعادل في الترتيب لا عشوائي:** `topStatuses` يفرز تنازلياً
حسب العدد ثم تصاعدياً حسب رقم الوضعية — قرار صغير يمنع أن
تتقلّب القائمة بين تحميلين.

**قاعدة 45:** تعادل أولوية داخل المصدر الواحد → `ambiguousCount`
يُعرض تنبيهاً ولا يُطبَّق، والمجموع لا يزيد (المعضوم يُحسب مرة
واحدة) — مُثبَّت باختبار.

**الاختبارات:** `test/integration/dashboard_repository_test.dart`
— 13 اختباراً، **وبقاعدة جديدة في كل اختبار** لأن اللوحة تعدّ
عدّاً عامّاً: العدّ المتراكم بين الحالات كان سيخفي الخطأ.

---

### PHASE 10 — مستودع الفلاتر المحفوظة ✅

**الملفات:**
- `lib/models/saved_filter.dart` (جديد) — `SavedFilter` + `SavedFilterKind`.
- `lib/repositories/filter_repository.dart` (جديد).
- `lib/core/constants/db_constants.dart` — ثابتا عمود جديدَين
  `cCriteria` / `cLogic` (المخطط §10 كان موجوداً أصلاً).

**المخطط المرجع لا الرأي (قاعدة 72):** `saved_filters` جدول في
`docs/DATABASE.md` §10 وفي `schema.dart` منذ المرحلة 3. النسخة
الأولى من هذه المرحلة حفظت الفلاتر في `settings` كـ JSON **بمفتاح
اسمه `saved_filters` — نفس اسم الجدول** — فأُعيدت كاملة على
الجدول الفعلي. لا تغيير في `schema_version`.

**الاستعلام يُحفظ كاملاً لا كنصّ:** عمود `criteria` يحمل JSON فيه
النوع + النص + `include_inactive` + قائمة المعايير (ومعاييرها
**المتداخلة** D-018 بكل منطقها)، وعمود `logic` يحمل منطق المجموعة
العليا وحده — لا ازدواج مصدر بين العمود والـ JSON. ولا عمود `kind`
في المخطط، والنوع داخل JSON لا يستحق عموداً ولا هجرة.

**الاسم فريد عالمياً:** `uq_saved_filter_name` يغطي الجدول كله،
فالفحص يسبق الكتابة بقارئ غير حساس لحالة الأحرف (أشدّ من القيد
نفسه) — ولا يرى المستخدم `UNIQUE constraint failed` أبداً
(قاعدة 49). والاعتراض الوحيد: نفس الاسم بين شاشتين مرفوض.

**التحقق قبل الكتابة (بلا نصف حالة):** اسم فارغ → رفض؛ استعلام
فارغ (لا نص ولا معايير) → رفض؛ والمعرّف من `AUTOINCREMENT` فيخرج
من الاعتبار تغيير الاسم كلياً.

**الترتيب والحدود:** أبجدياً `COLLATE NOCASE` ثم بالمعرّف حتى تبقى
القائمة ثابتة بين التحميلين. والحذف مسموح هنا (لا عمود `is_active`
في المخطط) تماماً كـ `permanence` — الفلاتر تفضيلات لا تاريخ
(D-008). وكل عملية تقبل `txn` حسب D-019.

**صفّ تالف لا يُسقط القائمة:** JSON فاسد / صيغة خاطئة / نوع مجهول
/ اسم فارغ → يُتجاهَل الصف ويُقرأ الباقي؛ ولو طُلب الصف التالف
بالتحديد → `null` لا استثناء (قاعدة 49)، و`count()` يعدّ الجدول
كما هو ولا يفرّيه.

**الاختبارات:** `test/integration/filter_repository_test.dart`
— 20 اختباراً، وكل اختبار يبدأ بجدول فارغ (الحذف بـ SQL لا عبر
المسترد — وإلا بقيت الصفوف التالفة غير مرئية تلوث العدّ).

---

### PHASE 11 — خدمة النسخ الاحتياطي والاستعادة ✅

**الملف:** `lib/services/backup_service.dart` (جديد)
— `BackupService` + `BackupInfo` + `RestoreReport`.

**التشفير حقيقي لا اسمي (D-012):** AES-256-GCM بمفتاح مشتقّ من
كلمة مرور المستخدم عبر PBKDF2-HMAC-SHA256 (**120 ألف تكرار**،
ملحّ عشوائي 16 بايت ورقم عشوائي 12 بايت لكل نسخة). لا مفتاح
يُخزَّن ولا يُكتب في الكود ولا يمرّ بـ Git — والململف يحمل الملحّ
ورقم العشوائية فقط.

**صيغة الملف v1:**
`"ASBK" | الإصدار | طول الترويسة(uint32 BE) | ترويسة JSON | الشيفرة`

**الترويسة غير مشفّرة عمداً** حتى يستطيع التطبيق عرض تاريخ النسخة
وعدّ صفوفها **قبل** سؤال المستخدم عن كلمة المرور — ولا تحوي إلا
بيانات تقنية (`salt`/`nonce`/`checksum`/`counts`). أمّا
**SHA-256 على الشيفرة** فيُتحقّق منه **قبل** فك التشفير: ملف مبتور
يُرفض برسالة عربية بلا أي حساب، وملف تالف الترويسة لا يرى
استثناء خام أبداً.

**الاستعادة استبدال نقطة زمنية داخل معاملة واحدة:** حذف الجداول
**عكس ترتيب الإدراج** (الابن أولاً) ثم إدراج بالآباء أولاً،
وأي صفّ فاشل يُسقط المعاملة كلها — مُثبَّت باختبار بصفّ مكرر
ترجع فيه كل الأعداد كما كانت.

**رفض قبل اللمس:** إصدار مخطط أقدم/أحدث، جدول مجهول، عمود غير
موجود في `PRAGMA table_info` — كله يُرفض قبل فتح المعاملة.

**settings بقائمة بيضاء:** المُصرَّح به أربعة مفاتيح استيراد
وحدود فاصلة فقط؛ `locale` و`pin_hash` و`pin_salt` و`biometric`
و`auto_lock` و`notifications` **لا تُصدَّر ولا تُستعاد** — ملف PIN
من جهاز آخر كان سيقفل المستخدم خارج تطبيقه.

**التدقيق:** قيد `backup` بعد الكتابة، وقيد `restore` داخل
المعاملة نفسها بعد التطبيق — والسجل يعود بنسخة النسخة ثم يحمل
قيد الاستعادة.

**الاختبارات:** `test/integration/backup_restore_test.dart`
— 19 اختباراً (إنشاء/كشف/رفض/استعادة/إعدادات/تدقيق/صيغ خاطئة).

---

### PHASE 12 — خدمة الأمان ✅

**الملف:** `lib/services/security_service.dart` (جديد)
— `SecurityService` + واجهة `BiometricAuth` + `LocalAuthBiometric`.

**الرمز مُجزَّأ لا مخزَّن (D-012):** PBKDF2-HMAC-SHA256 بـ 120 ألف
تكرار وملحّ عشوائي **جديد** 16 بايت مع كل تغيير، والمخرَّج
base64 في `settings` (`pin_hash` + `pin_salt`) **داخل `writeMany`
واحدة** — لا يمكن أن يُكتب رمز بلا ملحّ. المقارنة بزمن ثابت لا
تسرّب طول المخرَّج.

**قواعد الشكل:** من 4 إلى 6 أرقام ASCII فقط، تُرفض برسالة عربية
**قبل** أي كتابة؛ أمّا `verifyPin` فلا يرمي أبداً — غير مفعّل،
مفتاح مفقود، وإدخال غير صالح كلّها `false`. المحاولة الخاطئة
تُدوَّن في `audit_logs` والصحيحة لا تضيف فشلاً.

**البصمة خلف واجهة قابلة للحقن:** `BiometricAuth` (دعم/تسجيل/
استدعاء) ويحقن التطبيق قارئاً وهمياً في الاختبارات، والافتراضي
`LocalAuthBiometric` يلتفّ على `local_auth` ويحوّل أي خطأ منصّة
إلى `false`. السبب النصّي **يأتي من الواجهة مترجماً** — لا نصّ
مُضمَّن في الخدمة. التفعيل يتطلب جهازاً داعماً وإلا `AppException`
عربية، وغير المفعّل لا يُستدعى المزوّد أصلاً.

**القفل التلقائي يفهم «معطّل»:** مفتاح جديد `auto_lock_enabled`
(مزرع بـ `1`) لأن `auto_lock_minutes = 0` تُعامَل قاعدة الإعدادات
كقيمة غير منطقية لا كإطفاء — فـ `autoLockDuration()` تعيد
`Duration.zero` عند الإطفاء. الخيارات {1, 5, 15} وحدها، واختيار
زمن يعيد التفعيل تلقائياً.

**التدقيق:** كل تغيير (إنشاء/تغيير/إلغاء رمز، تفعيل/تعطيل البصمة،
تفعيل/تعطيل القفل، تغيير زمنه) يُدوَّن بـ `logSecurity` **بلا أي
سرّ** — والاختبار يفحص `isNot(contains('1234'))`.

**ملفات مُلمسة:** `Db.keyAutoLockEnabled` + بذر الافتراضي +
وصيفا `autoLockEnabled`/`setAutoLockEnabled` في `SettingsRepository`
(بلا تدقيق هناك — التدقيق طبقة الخدمات). وحُذف `class SavedFilter`
الميت من `audit_log_entry.dart` الذي كان سينتج اسماً مكرّراً مع
`models/saved_filter.dart` (خطأ #12).

**الاختبارات:** `test/integration/security_service_test.dart`
— 24 اختباراً (أولية/إنشاء/رفض/تغيير/قفل/بصمة/تدقيق).

---

## [1.0.0] — 2026-10-07

### PHASE 13 — واجهات المستخدم الكاملة ✅

**السبب:** البرنامج كان يعمل لكنه يعرض «لا بيانات» لأن كل التبويبات
كانت أماكن محجوزة (placeholders) — والآن كل شاشة موصولة بالمستودعات
والخدمات الموجودة.

**طبقة جديدة:**

| الملف | الوظيفة |
|---|---|
| `lib/core/providers/app_providers.dart` | حقن واحد للقاعدة + كل المستودعات + `CsvImportService`/`BackupService`/`SecurityService` + عدّاد `dbRevisionProvider` |
| `lib/core/widgets/ui_kit.dart` | `LoadingView` / `ErrorView` / `EmptyState` / `SectionCard` / `InfoRow` / `StatCard` / `showAppSnack` / `confirmAction` / `errorText` — بلا منطق أعمال |

**الشاشات:** لوحة القيادة (أرقام + تنبيهات + إجراءات سريعة)، الموظفون
(بحث حرّ + فلاتر الأقسام/الدرجات/الوضعيات + ترقيم لا نهائي + إضافة/تعديل/أرشفة)،
بطاقة الموظف (4 تبويبات: معلومات/وضعيات/رخص/مداومة)، المداومة (تنقّل يومي
+ إضافة + ربط 🔗 + حذف)، الرخص (جارية/قادمة/منتهية + معاينة حساب حيّة +
معالجة `ConflictException` بخيار «حفظ على أي حال»)، الاستيراد (معالج
نوع ← ملف ← معاينة ← تنفيذ)، الإعدادات (لغة، PIN، بصمة، قفل تلقائي،
تصدير CSV، مراجع، نسخ احتياطي/استعادة، حول)، المراجع (إضافة/تعطيل)،
وقفل الدخول `LockGate` مع القفل التلقائي على عودة التطبيق من الخلفية.

**قرارات تقنية داخلية:**

- **`dbRevisionProvider`**: عدّاد يرتفع بعد كل كتابة — لوحة القيادة
  و`statusTypesProvider` يراقبانه فتُعاد قراءتهما تلقائياً بعد أي إضافة
  (بدون استماع يدوي ولا `invalidate` متناثر).
- **`LeaveRepository.types()`/`createType()`**: كانت الشاشة بلا مصدر
  لأنواع الرخص — أُضيفا بأسلوب المستودعات نفسها (البحث عن تكرار الاسم
  عربي + المدد كلها من الصف).
- **`app_localizations_x.dart` يصدّر `AppLocalizations`** حتى يكفي
  استيراد واحد في كل شاشة (كان ينتج `unnecessary_import`).
- **file_picker v13**: `FilePicker.pickFiles()` / `FilePicker.getDirectoryPath()`
  ثابتتان بلا `.platform`، والنتيجة `List<PlatformFile>` مع `readAsBytes()`.
- **اختبار الواجهة أصبح حقيقياً**: قاعدة FFI في الذاكرة عبر
  `appDatabaseProvider.overrideWith` + دورات `runAsync` (تأخير حقيقي ←
  `pump`) — وإلا علّق `pumpAndSettle` لأن نتائج SQLite لا تعود داخل
  الزمن الوهمي لـ `testWidgets`.

**الاختبارات:** 463/463 (منها اختبار واجهة يفحص شريط التنقل الخمسة).
**`flutter analyze`:** ✅ صفر ملاحظات.

### البناء ✅

- **APK:** `flutter build apk --release` → `ADMIN_STAFF_v1.0.0.apk`
  (موقّع بمفتاح التثبيت → تثبيت مباشر)، نسخة على سطح المكتب.
- **ويندوز:** `flutter build windows --release` → `admin_staff.exe`.

**وثائق:** `AIDE_ET_ASSISTANCE.txt` (دليل استخدام عربي/فرنسي: التثبيت،
كل شاشة، أعمدة CSV، النسخ الاحتياطي، حل المشاكل) — بجانب `README.md`
و`docs\*` و`CHANGELOG.md` و`TESTING.md`.

---

## [الحالة الحالية]

| | |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **463/463** |
| التكلفة | **$0** |
