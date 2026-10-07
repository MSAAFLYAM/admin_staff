# DATABASE.md — مخطط قاعدة البيانات SQLite

**schema_version = 1**

كل الجداول تُنشأ في `onCreate`، وكل الترقّيات عبر `Migration`
في `onUpgrade`. النسخ الاحتياطية تحمل `schema_version`
حتى يمكن ترقية نسخة قديمة (قاعدة 60).

---

## قواعد عامة

- **Foreign Keys = ON** دائماً (`PRAGMA foreign_keys = ON`).
- لا **orphan records** إطلاقاً (قاعدة 69).
- **Soft Delete** فقط: `is_active` / `is_cancelled` (قاعدة 70).
- التواريخ: `TEXT` بصيغة `YYYY-MM-DD`.
- الأوقات: `TEXT` بصيغة `HH:mm`.
- `matricule`, `ppr`, `mobile_phone`, `section`, `grade` → **TEXT**.
- الطوابع الزمنية: `TEXT` ISO-8601 UTC.

---

## 1. `settings`

> مفتاح/قيمة عام للتخزين الإعدادي (لغة، حفظ آخر mapping، أولوية، …).

```sql
CREATE TABLE settings (
  key         TEXT PRIMARY KEY,
  value       TEXT,
  updated_at  TEXT NOT NULL
);
```

---

## 2. `sections` / `grades` / `functions`

> جداول مرجعية (قاعدة 12). لا نص حر في كل مكان.
> إعادة التسمية لا تكسر التاريخ لأن السجلات تشير بـ `id`.

```sql
CREATE TABLE sections (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  name_ar     TEXT,
  search_text TEXT NOT NULL DEFAULT '',
  is_active   INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE grades (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  name_ar     TEXT,
  search_text TEXT NOT NULL DEFAULT '',
  is_active   INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE functions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  name_ar     TEXT,
  search_text TEXT NOT NULL DEFAULT '',
  is_active   INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
```

---

## 3. `status_types` + `status_history`

### 3.1 `status_types`

> قائمة قابلة للإدارة، **غير hard-coded** (قاعدة 13).
> `priority` يحكم الحالات المتداخلة (قاعدة 84).

```sql
CREATE TABLE status_types (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  name_fr     TEXT,
  priority    INTEGER NOT NULL DEFAULT 0,
  is_terminal INTEGER NOT NULL DEFAULT 0,  -- 1 = حالة نهائية (تقاعد)
  is_active   INTEGER NOT NULL DEFAULT 1,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE UNIQUE INDEX uq_status_name ON status_types(name);
```

**القيم الأولية (Seed):**

| name | name_fr | priority | is_terminal |
|---|---|---|---|
| في الخدمة | En service | 0 | 0 |
| عطلة إدارية | Congé administratif | 20 | 0 |
| رخصة استثنائية | Congé exceptionnel | 20 | 0 |
| رخصة مرضية | Congé maladie | 30 | 0 |
| موقوف | Suspendu | 90 | 0 |
| تصريف الإجازات | Liquidation de congés | 20 | 0 |
| التقاعد النسبي | Retraite progressive | 80 | 0 |
| التقاعد | Retraite | 100 | 1 |
| أخرى | Autre | 10 | 0 |

### 3.2 `status_history`

```sql
CREATE TABLE status_history (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id    INTEGER NOT NULL
                   REFERENCES employees(id) ON DELETE CASCADE,
  status_type_id INTEGER NOT NULL
                   REFERENCES status_types(id),
  start_date     TEXT NOT NULL,
  end_date       TEXT,                       -- NULL = مستمر
  notes          TEXT,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX ix_status_history_emp_dates
  ON status_history(employee_id, start_date, end_date);
CREATE INDEX ix_status_history_status
  ON status_history(status_type_id);
```

**لا يُحذف التاريخ أبداً** (قاعدة 14).

---

## 4. `employees`

```sql
CREATE TABLE employees (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  matricule         TEXT NOT NULL,
  nom_ar            TEXT,
  prenom_ar         TEXT,
  nom_fr            TEXT,
  prenom_fr         TEXT,
  section_id        INTEGER REFERENCES sections(id),
  function_id       INTEGER REFERENCES functions(id),
  quality           TEXT,
  grade_id          INTEGER REFERENCES grades(id),
  ppr               TEXT,
  mobile_phone      TEXT,
  current_status_id INTEGER REFERENCES status_types(id),
  notes             TEXT,
  search_text       TEXT NOT NULL DEFAULT '',
  is_active         INTEGER NOT NULL DEFAULT 1,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);

CREATE UNIQUE INDEX uq_employees_matricule ON employees(matricule);
CREATE UNIQUE INDEX uq_employees_ppr
  ON employees(ppr) WHERE ppr IS NOT NULL AND ppr <> '';
CREATE INDEX ix_employees_nom_fr  ON employees(nom_fr);
CREATE INDEX ix_employees_nom_ar  ON employees(nom_ar);
CREATE INDEX ix_employees_prenom_fr ON employees(prenom_fr);
CREATE INDEX ix_employees_prenom_ar ON employees(prenom_ar);
CREATE INDEX ix_employees_ppr     ON employees(ppr);
CREATE INDEX ix_employees_phone   ON employees(mobile_phone);
CREATE INDEX ix_employees_section ON employees(section_id);
CREATE INDEX ix_employees_grade   ON employees(grade_id);
CREATE INDEX ix_employees_function ON employees(function_id);
CREATE INDEX ix_employees_status  ON employees(current_status_id);
CREATE INDEX ix_employees_active  ON employees(is_active);
CREATE INDEX ix_employees_quality ON employees(quality);
```

> كل حقول البحث الكثيفة مفهرسة (قاعدة 39 و61).

### `search_text` — عمود البحث المطبَّع (قاعدة 61)

| | |
|---|---|
| **المشكلة** | `LIKE '%احمد%'` لا يطابق `أحمد`. `LOWER()` في SQLite لاتينية فقط، ولا توجد دالة تطبيع عربية. |
| **الحل** | نطبّع **مرّة واحدة عند الكتابة** ونخزّن النتيجة في `search_text`. |
| **التطبيع** | `آأإٱ→ا`، `ة→ه`، `ى→ي`، `ؤ→و`، `ئ→ي`، إزالة التشكيل، `toLowerCase`، ضغط المسافات، استبدال الترقيم بمسافة. مصدره الوحيد: `TextNormalizer.searchText()`. |
| **من يملؤها** | `Employee.toInsertMap()`، `Section/Grade/FunctionEntry.toInsertMap()`، `ReferenceRepository.createEntry/upsertEntry`، وخلية استيراد CSV (تُبنى من الصف **المدموج** لا من صف الاستيراد وحده). |
| **يبحث فيها** | `SearchQueryBuilder.textColumns` = `e.search_text`, `s.search_text`, `g.search_text`, `f.search_text`. |
| **الفائدة** | 4 أعمدة بدل 11 → أسرع؛ **و** صحيحة للعربية والفرنسية معاً. |

> لا يُخزَّن داخله المعرّفات الرقمية (`section_id` / `grade_id` /
> `function_id` / `current_status_id`) — تلك تُبحث بفلاتر مخصّصة
> عبر فهارسها، لا بالنص الحرّ.

---

## 5. `leave_types`

```sql
CREATE TABLE leave_types (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  name_ar           TEXT NOT NULL,
  name_fr           TEXT,
  default_duration  REAL NOT NULL DEFAULT 1,
  duration_unit     TEXT NOT NULL DEFAULT 'days'
                      CHECK(duration_unit IN ('hours','days')),
  count_start_day   INTEGER NOT NULL DEFAULT 1,
  include_weekends  INTEGER NOT NULL DEFAULT 0,
  include_holidays  INTEGER NOT NULL DEFAULT 0,
  day_count_mode    TEXT NOT NULL DEFAULT 'calendar'
                      CHECK(day_count_mode IN ('calendar','working')),
  return_day_mode   TEXT NOT NULL DEFAULT 'next_working_day'
                      CHECK(return_day_mode IN
                            ('immediate','next_working_day')),
  status_type_id    INTEGER REFERENCES status_types(id),
  is_active         INTEGER NOT NULL DEFAULT 1,
  sort_order        INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);

CREATE UNIQUE INDEX uq_leave_types_ar ON leave_types(name_ar);
```

> **لا يوجد أي hard-coded duration في الكود** (قاعدة 17).

---

## 6. `leaves`

```sql
CREATE TABLE leaves (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id    INTEGER NOT NULL
                   REFERENCES employees(id) ON DELETE CASCADE,
  leave_type_id  INTEGER NOT NULL
                   REFERENCES leave_types(id),
  start_date     TEXT NOT NULL,
  end_date       TEXT NOT NULL,
  return_date    TEXT,
  duration       REAL,
  duration_unit  TEXT,
  raw_duration   TEXT,              -- "48h" أو "3d" كما أُدخل
  notes          TEXT,
  is_cancelled   INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX ix_leaves_emp_dates
  ON leaves(employee_id, start_date, end_date);
CREATE INDEX ix_leaves_type   ON leaves(leave_type_id);
CREATE INDEX ix_leaves_end    ON leaves(end_date);
CREATE INDEX ix_leaves_return ON leaves(return_date);
CREATE INDEX ix_leaves_start  ON leaves(start_date);
CREATE INDEX ix_leaves_active ON leaves(is_cancelled);
```

> فهرس `end_date` و`return_date` يدعم تنبيهات "تنتهي اليوم/غداً".

---

## 7. `permanence`

```sql
CREATE TABLE permanence (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  date           TEXT NOT NULL,                       -- YYYY-MM-DD
  employee_id    INTEGER REFERENCES employees(id)
                             ON DELETE SET NULL,      -- قد يكون NULL
  matricule      TEXT NOT NULL,                       -- كما ورد
  permanencier   TEXT,                                -- اسم عرض
  section        TEXT,
  grade          TEXT,
  hpad           TEXT,
  mobile_phone   TEXT,
  start_time     TEXT,                                -- HH:mm
  end_time       TEXT,                                -- HH:mm
  time_slot      TEXT NOT NULL DEFAULT '',            -- مشتق للمفتاح
  schedule_text  TEXT,                                -- horaire الأصلي
  source_file    TEXT,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE UNIQUE INDEX uq_perm_date_emp_slot
  ON permanence(date, employee_id, time_slot)
  WHERE employee_id IS NOT NULL;

CREATE INDEX ix_perm_date       ON permanence(date);
CREATE INDEX ix_perm_employee   ON permanence(employee_id, date);
CREATE INDEX ix_perm_matricule  ON permanence(matricule);
CREATE INDEX ix_perm_section    ON permanence(section);
CREATE INDEX ix_perm_start_time ON permanence(start_time);
```

> `time_slot` = `start_time` أو `''`. يسمح بأكثر من مداومة
> لموظف في اليوم نفسه بفترتين مختلفتين، ويمنع التكرار الحقيقي (D-010).

---

## 8. `holidays`

```sql
CREATE TABLE holidays (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  date         TEXT NOT NULL,
  name_ar      TEXT,
  name_fr      TEXT,
  is_recurring INTEGER NOT NULL DEFAULT 0,
  is_active    INTEGER NOT NULL DEFAULT 1,
  created_at   TEXT NOT NULL
);

CREATE UNIQUE INDEX uq_holiday_date ON holidays(date);
```

---

## 9. `audit_logs`

```sql
CREATE TABLE audit_logs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  action      TEXT NOT NULL,      -- CREATE/UPDATE/DELETE/IMPORT/RESTORE/...
  entity_type TEXT NOT NULL,      -- employee/leave/import/...
  entity_id   INTEGER,
  description TEXT,
  old_value   TEXT,               -- JSON
  new_value   TEXT,               -- JSON
  created_at  TEXT NOT NULL
);

CREATE INDEX ix_audit_entity  ON audit_logs(entity_type, entity_id);
CREATE INDEX ix_audit_created ON audit_logs(created_at);
CREATE INDEX ix_audit_action  ON audit_logs(action);
```

> لا تُسجَّل بيانات حساسة (هاتف، صحة) في `description` (قاعدة 58).

---

## 10. `saved_filters`

```sql
CREATE TABLE saved_filters (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  criteria   TEXT NOT NULL,   -- JSON
  logic      TEXT NOT NULL DEFAULT 'AND',   -- AND | OR
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

---

## 11. `import_history`

```sql
CREATE TABLE import_history (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  kind         TEXT NOT NULL,     -- employees | permanence
  file_name    TEXT,
  delimiter    TEXT,
  encoding     TEXT,
  date_format  TEXT,
  mode         TEXT,              -- add/update/replace
  total_rows   INTEGER DEFAULT 0,
  new_rows     INTEGER DEFAULT 0,
  updated_rows INTEGER DEFAULT 0,
  dup_rows     INTEGER DEFAULT 0,
  error_rows   INTEGER DEFAULT 0,
  status       TEXT NOT NULL,     -- success | failed | rolled_back
  message      TEXT,
  created_at   TEXT NOT NULL
);
```

---

## ملخص الفهارس

| الجدول | الفهرس |
|---|---|
| `employees` | matricule (UNIQUE), ppr (UNIQUE partial), nom_fr, nom_ar, prenom_fr, prenom_ar, ppr, phone, section, grade, function, status, active, quality |
| `sections` / `grades` / `functions` | name |
| `status_types` | name (UNIQUE), priority DESC, is_terminal |
| `status_history` | (employee_id, start_date, end_date), status_type_id |
| `leaves` | (employee_id, start_date, end_date), leave_type_id, end_date, return_date, start_date, is_cancelled |
| `permanence` | (date, employee_id, time_slot) UNIQUE partial, date, (employee_id, date), matricule, section, start_time |
| `holidays` | date (UNIQUE) |
| `audit_logs` | (entity_type, entity_id), created_at, action |

> **`search_text` بلا فهرس — وهذا مقصود.** البحث عنه
> `LIKE '%…%'` ببادئة `'%` لا يقرأ فهرس B-tree أصلاً، فالفهرس
> كان سيدفع تكلفة كتابة بلا مقابل. تُخزَّن المطابقة الدقيقة
> والبادئة (`matricule`, `ppr`, `nom_fr`, `nom_ar`, …) على فهارسها
> الأصلية، والتصفية على `section_id` / `current_status_id` / `date`.

---

## ترتيب الإنشاء (Dependency Order)

```
settings
sections, grades, functions
status_types
employees              ← يحتاج sections/grades/functions/status_types
status_history         ← يحتاج employees + status_types
leave_types            ← يحتاج status_types
leaves                 ← يحتاج employees + leave_types
permanence             ← يحتاج employees
holidays
audit_logs
saved_filters
import_history
```
