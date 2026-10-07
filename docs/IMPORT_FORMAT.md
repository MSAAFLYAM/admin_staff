# IMPORT_FORMAT.md — الصيغ الرسمية لملفات CSV

هذا الملف هو المرجع الرسمي لما يقبله التطبيق عند الاستيراد.

---

## 1. Encoding

| البند | القيمة |
|---|---|
| Encoding المفضل | **UTF-8** |
| مدعوم أيضاً | UTF-8 **مع BOM** (يتم إزالة BOM تلقائياً)، UTF-16 LE |
| مرفوض | ترميزات غير قابلة للتمييز → رسالة خطأ واضحة |

تطبيق BOM تلقائياً ضروري لتوافق Excel عند تصدير/استيراد العربية.

---

## 2. Delimiter

النظام **لا يفترض** أن الملف مفصول بفاصلة.

يكتشف التلقائي ويسمح بالتحديد اليدوي:

| الرمز | الحرف |
|---|---|
| `Comma` | `,` |
| `Semicolon` | `;` |
| `Tab` | `\t` |
| `Pipe` | `\|` |

**الكشف الآلي:** يُحسب أسطر رأسية (header) بأعلى عدد أعمدة متسقة
عبر عدة delimiter مرشّحة، ويُختَر أعلى نتيجة.
يُعرض الدلّيتر المكتشف في شاشة Preview ويُسمح بتغييره.

---

## 3. تنسيقات التاريخ المقبولة

عند **الاستيراد** تُقبل الصيغ التالية (تُكتشف آلياً ويُعرض التنسيق المتعرَّف عليه):

| التنسيق | مثال | ملاحظة |
|---|---|---|
| `YYYY-MM-DD` | `2026-10-03` | **المعيار الداخلي** (ISO-8601) |
| `DD/MM/YYYY` | `03/10/2026` | مقبول |
| `DD-MM-YYYY` | `03-10-2026` | مقبول |
| `DD.MM.YYYY` | `03.10.2026` | مقبول |
| `YYYY/MM/DD` | `2026/10/03` | مقبول |
| `DD/MM/YY` | `03/10/26` | مقبول (20xx) |

- أي تنسيق آخر → رفض السجل مع رسالة: `تنسيق تاريخ غير معروف: "xxx"`
- داخل قاعدة البيانات يُخزَّن دائماً `YYYY-MM-DD` (قاعدة 80).
- خطأ منطقي (يوم 32، شهر 13) → رفض مع رسالة واضحة.

**التوقيت (`horaire`)** يُقبل بـ:

`HH:mm`, `H:mm`, `HH:mm:ss`, `HH:mm - HH:mm`, `HH:mm-HH:mm`, `HH:mm à HH:mm`

يُخزَّن `start_time` و`end_time` منفصلان بصيغة `HH:mm`.

---

## 4. Employees CSV

### 4.1 الأعمدة الرسمية (بالترتيب المقترح)

```csv
nom_ar,prenom_ar,nom_fr,prenom_fr,matricule,section,fonction,qualite,grade,ppr,telephone_mobile,statut
بن عيسى,أحمد,BEN AISSA,Ahmed,12547,RH,Chef de service,Chef,Principal 2ème grade,0987654321,0555123456,في الخدمة
```

| # | العمود | الحقل في DB | إلزامي | النوع |
|---|---|---|---|---|
| 1 | `nom_ar` | `employees.nom_ar` | اختياري | TEXT |
| 2 | `prenom_ar` | `employees.prenom_ar` | اختياري | TEXT |
| 3 | `nom_fr` | `employees.nom_fr` | اختياري* | TEXT |
| 4 | `prenom_fr` | `employees.prenom_fr` | اختياري* | TEXT |
| 5 | `matricule` | `employees.matricule` | **نعم** | TEXT (UNIQUE) |
| 6 | `section` | → `sections.name` | لا | TEXT |
| 7 | `fonction` | → `functions.name` | لا | TEXT |
| 8 | `qualite` | `employees.quality` | لا | TEXT |
| 9 | `grade` | → `grades.name` | لا | TEXT |
| 10 | `ppr` | `employees.ppr` | لا | TEXT |
| 11 | `telephone_mobile` | `employees.mobile_phone` | لا | TEXT |
| 12 | `statut` | → `status_types.name` | لا | TEXT |

\* يكفي وجود اسم عربي **أو** فرنسي على الأقل، وإلا يُرفض السجل
بسبب غياب الاسم كلياً.

### 4.2 قواعد التحقق (Validation)

| القاعدة | النتيجة |
|---|---|
| `matricule` فارغ | ❌ رفض: "حقل Matricule إلزامي ولا يمكن أن يكون فارغاً" |
| `matricule` مكرر **داخل الملف** | ❌ رفض: "Matricule مكرر في الملف" |
| كلا الاسمين (عربي/فرنسي) فارغ | ❌ رفض: "يجب إدخال الاسم بالعربية أو الفرنسية" |
| `ppr` غير صالح (غير رقمي مع رموز) | ⚠️ تحذير — يُقبل كنص |
| كل الأعمدة فارغة في الصف | ❌ تجاهل الصف (صف فارغ) |
| ملف فارغ (0 صفوف) | ❌ "الملف فارغ" |
| عمود `matricule` غير موجود | ❌ "العمود Matricule غير موجود. استخدم شاشة Column Mapping" |

### 4.3 منطق التكرار (Duplicate Detection)

لكل سجل يُقرأ، يُبحث عن موظف **موجود مسبقاً** بهذا الترتيب:

1. `matricule` مطابق تماماً ← **تحديث** (Update)
2. ثم `ppr` مطابق تماماً و`ppr` غير فارغ ← **تحديث**
3. لا يوجد ← **جديد** (Insert)

> **قاعدة حاسمة:** عند التحديث **لا يُمسح التاريخ السابق**.
> `created_at` يبقى أصلياً، و`status_history` و`leaves` و`permanence`
> و`audit_logs` لا تُتأثر إطلاقاً.

**التكرار داخل الملف نفسه** (سطران يحملان نفس `matricule`
أو نفس `ppr`): يُرفض **الصف الثاني** برسالة
`"Matricule مكرر في الملف (موجود في الصف N)"` — لا يُكتب مرتين.
يُعرض ضمن الصفوف المرفوضة ويُسجَّل في `ImportResult.errors`.

### 4.4 مخرجات شاشة Preview

```
اسم الملف:        employees_oct.csv
Delimiter:        ;
Encoding:         UTF-8
تنسيق التاريخ:    DD/MM/YYYY
عدد السجلات:      250

إجمالي السجلات:            250   totalRows
سجلات جديدة:               210   insertCount
سجلات سيتم تحديثها:         35   updateCount
سجلات بها أخطاء:             5   errorCount   (5 مكررات في الملف)
```

> المجموع `210 + 35 + 5 = 250` — **لا شيء يضيع** بين المعاينة
> والتنفيذ.

ثم **Confirm Import** — لا تُغيَّر قاعدة البيانات قبل التأكيد (قاعدة 9).

---

## 5. Permanence CSV

### 5.1 الأعمدة الرسمية

```csv
date,permanencier,matricule,section,grade,hpad,telephone_mobile,horaire
2026-10-05,BEN AISSA Ahmed,12547,RH,Principal 2ème grade,H-01,0555123456,08:00 - 16:00
```

| # | العمود | الحقل في DB | إلزامي |
|---|---|---|---|
| 1 | `date` | `permanence.date` | **نعم** |
| 2 | `permanencier` | `permanence.permanencier` (اسم عرض) | لا |
| 3 | `matricule` | **مفتاح الربط** → `employees.matricule` | **نعم** |
| 4 | `section` | `permanence.section` | لا |
| 5 | `grade` | `permanence.grade` | لا |
| 6 | `hpad` | `permanence.hpad` | لا |
| 7 | `telephone_mobile` | `permanence.mobile_phone` | لا |
| 8 | `horaire` | → `start_time` + `end_time` | لا |

### 5.2 قواعد الربط (Rule 22)

```
لكل صف:  matricule = "12547"
          ↓
   SELECT id FROM employees WHERE matricule = '12547'
          ↓
   ┌─── وُجد ──→ employee_id = <id>   ✅ مرتبط
   └─── لم يُوجد ──→ employee_id = NULL  ⚠️ يدخل "Unmatched Employees"
```

> **لا يُنشأ موظف تلقائياً أبداً** بدون إذن المستخدم صراحةً.

شاشة Unmatched تعرض:
- عدد السجلات غير المربوطة
- قائمة الـ matricule غير الموجودة
- خيار: `تجاهل` / `ربط يدوي` / `إنشاء الموظفين المفقودين (تصدير فقط)`

### 5.3 منع التكرار (Rule 23)

فهرس فريد: `(date, employee_id, time_slot)`

- نفس التاريخ + نفس الموظف + نفس الفترة → **تخطي** (يُحسب كـ `مكرر`)
- نفس التاريخ + نفس الموظف + فترة مختلفة → **مقبول** ✅
- `employee_id IS NULL` → الفهرس لا يُفعّل (SQLite NULL لا يتعارض)

### 5.4 سياسات الاستيراد (Rule 42)

يجب أن يختار المستخدم واحدة قبل التنفيذ:

| الخيار | السلوك |
|---|---|
| **Add New Week** (افتراضي) | إضافة السجلات الجديدة فقط، لا يمسّ الموجود |
| **Update Existing Week** | تحديث السجلات الموجودة لنفس الفترة |
| **Replace Selected Date Range** | ⚠️ يحذف سجلات الفترة المحددة أولاً ثم يستورد — **يلزم Confirmation Dialog** |

> **لا تُحذف المداومات القديمة أبداً** بافتراضي الاستيراد (قاعدة 42).

---

## 6. ملاحظات عامة

- كل الصفوف تُقرأ ثم تُتحقق **قبل** الكتابة.
- أي فشل داخل Transaction → rollback كامل.
- سجلات الرفض تُعرض في شاشة Preview مع رقم الصف وسبب الرفض.
- النصوص العربية تُحفظ كما هي (لا أي تحويل).
- الحقول الفارغة تُخزَّن `NULL` وليست `""`.
