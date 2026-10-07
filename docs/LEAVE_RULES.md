# LEAVE_RULES.md — قواعد الرخص ومحرك الحساب

---

## 1. الفلسفة

**لا يوجد أي رقم مُثبت في الكود.**

كل المدد والقواعد تُخزَّن في جدول `leave_types` كـ
**Business Defaults قابلة للتعديل** من واجهة الإدارة.

إضافة نوع رخصة جديد = صف جديد في `leave_types`، **بدون أي تعديل كود**.

---

## 2. حقول `leave_types`

| الحقل | النوع | الوظيفة |
|---|---|---|
| `id` | INTEGER PK | |
| `name_ar` | TEXT | الاسم بالعربية |
| `name_fr` | TEXT | الاسم بالفرنسية |
| `default_duration` | REAL | المدة الافتراضية (قابلة للتعديل) |
| `duration_unit` | TEXT | `hours` \| `days` |
| `count_start_day` | INTEGER 0/1 | هل يُحتسب يوم البداية؟ |
| `include_weekends` | INTEGER 0/1 | هل تُحتسب أيام الجمعة/السبت؟ |
| `include_holidays` | INTEGER 0/1 | هل تُحتسب العطل الرسمية؟ |
| `day_count_mode` | TEXT | `calendar` \| `working` |
| `return_day_mode` | TEXT | `immediate` \| `next_working_day` |
| `status_type_id` | INTEGER FK | الوضعية المشتقة عند تغطية اليوم |
| `is_active` | INTEGER 0/1 | |
| `sort_order` | INTEGER | ترتيب العرض |

---

## 3. القيم الافتراضية (Seed Data)

هذه هي الـ seed values، **قابلة للتعديل كلياً** بعد التركيب:

| الاسم (ع) | الاسم (fr) | المدة | الوحدة | ملاحظة |
|---|---|---|---|---|
| عطلة إدارية | Congé administratif | 30 | days | |
| رخصة مرضية | Congé maladie | 30 | days | |
| رخصة استثنائية | Congé exceptionnel | 15 | days | |
| رخصة 48 ساعة | Permission 48 heures | 48 | **hours** | ⏱️ وحدة الساعات |
| وفاة أصل | Décès ascendant | 3 | days | |
| وفاة فرع | Décès descendant | 2 | days | |
| رخصة الترحال (خارج مدينة التعيين) | Congé de mutation (hors ville) | 3 | days | |
| رخصة الترحال (داخل مدينة التعيين) | Congé de mutation (ville) | 1 | days | |
| ازدياد مولود | Naissance d'enfant | 15 | days | |
| تصريف الإجازات | Liquidation de congés | 30 | days | |
| التقاعد النسبي | Retraite progressive | 0 | days | |
| التقاعد | Retraite | 0 | days | |
| موقوف | Suspendu | 0 | days | |
| أخرى | Autre | 1 | days | |

> القيم المذكورة في المتطلبات (48h / 3d / 2d / 3d / 1d / 15d)
> مُسجّلة هنا كـ **seed**، وليست constants.

---

## 4. محرك الحساب — `leave_calculator.dart`

### 4.1 الواجهة

```dart
LeaveCalculationResult calculate({
  required DateTime startDate,
  required LeaveRuleConfig rule,
  DateTime? holidays,           // قائمة العطل الرسمية
});
```

```dart
class LeaveRuleConfig {
  final double duration;
  final DurationUnit unit;          // hours | days
  final bool countStartDay;
  final bool includeWeekends;
  final bool includeHolidays;
  final DayCountMode dayCountMode;  // calendar | working
  final ReturnDayMode returnDayMode;// immediate | next_working_day
}

class LeaveCalculationResult {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime returnDate;
  final double countedDuration;     // المدة المحتسبة فعلياً
  final DurationUnit unit;
  final List<DateTime> excludedDays; // للتوضيح في الواجهة
}
```

### 4.2 خوارزميات الحساب

#### أ) الوحدة = `hours`

```
endDate = startDate + ceil(duration / 24) يوم - 1 يوم
```
مثال: 48 ساعة تبدأ 03/10/2026 08:00
→ 48 ساعة = 2 يوم → `endDate = 04/10/2026`
→ `returnDate` حسب `return_day_mode`

> ملاحظة: الرخص بالساعات تُعامل كعدد أيام تقويم مكافئ
> (`ceil(hours / 24)`) ما لم يُضبط `count_start_day`.

#### ب) الوحدة = `days` + `dayCountMode = calendar`

```
عدد الأيام المحتسبة = duration
إذا count_start_day = true:
    endDate = startDate + (duration - 1) يوم
إذا count_start_day = false:
    endDate = startDate + duration يوم
```

**مثال 3 أيام، count_start_day = true:**
`03/10` → `03,04,05` → `endDate = 05/10`

**مثال 3 أيام، count_start_day = false:**
`03/10` → `04,05,06` → `endDate = 06/10`

#### ج) الوحدة = `days` + `dayCountMode = working`

```
نبدأ من startDate (أو اليوم التالي إن count_start_day = false)
نعدّ الأيام العاملة فقط:
    skip إذا كان weekend  &&  !includeWeekends
    skip إذا كان holiday  &&  !includeHolidays
نستمر حتى نصل إلى 'duration' يوم
endDate = آخر يوم محتسب
```

**مثال:** 15 يوم عمل تبدأ الخميس 01/10/2026
مع `include_weekends = false` → يتخطى الجمعة/السبت
→ `endDate` ينزلق تلقائياً.

### 4.3 حساب `returnDate`

| `return_day_mode` | النتيجة |
|---|---|
| `immediate` | `returnDate = endDate + 1 يوم` (مهما كان نوع اليوم) |
| `next_working_day` | أول يوم تقويم بعد `endDate` يكون يوماً عاملاً (بمراعاة `include_weekends` / `include_holidays`) |

**مثال:** `endDate = الجمعة 09/10/2026`
- `immediate` → العودة السبت 10/10
- `next_working_day` → العودة الأحد 11/10 (إذا كان الأسبوع يبدأ الأحد)

> تقويم عطل نهاية الأسبوع قابل للتهيئة: `weekendDays = {Friday, Saturday}`
> افتراضياً في الجزائر: **الجمعة + السبت**.

### 4.4 دعم تغيير الشهر والسنة

الخوارزمية تعمل على `DateTime` عادي ولا تفترض حدود الشهر:
`2026-12-30 + 5 أيام = 2027-01-04` — مُختبَر.

---

## 5. الحالات المستنتجة (Rule 44)

### 5.1 منطق الأولوية

```
function deriveStatus(employeeId, today):
    1. activeStatusHistory = SELECT * FROM status_history
         WHERE employee_id = ? AND start_date <= today
           AND (end_date IS NULL OR end_date >= today)
       if not empty:
           pick highest status_types.priority
           return that status

    2. activeLeave = SELECT * FROM leaves
         WHERE employee_id = ? AND is_cancelled = 0
           AND start_date <= today AND end_date >= today
       if not empty:
           return leave_types.status_type_id

    3. return employees.current_status_id
```

### 5.2 مثال عملي

موظف لديه:
- رخصة `01/10 → 05/10`
- اليوم `03/10`

النظام يحسب ← **"في رخصة حالياً"**
حتى لو كان `employees.current_status_id` يقول "في الخدمة".

> البيانات الزمنية هي مصدر الحقيقة.

---

## 6. اكتشاف التعارضات (Rule 45)

قبل حفظ أي رخصة أو تغيير وضعية، يفحص النظام تداخلين:

```
overlap(a, b) = a.start <= b.end AND b.start <= a.end
```

عند التداخل يعرض:

```
⚠️ Conflict Detected

الرخصة الحالية:  رخصة مرضية   01/10/2026 → 05/10/2026
الرخصة الجديدة:  عطلة إدارية   03/10/2026 → 10/10/2026
فترة التداخل:    03/10/2026 → 05/10/2026

[ إلغاء ]  [ حفظ على أي حال ]
```

لا يُطبّق تلقائياً أبداً (قاعدة 45).

---

## 7. العطل الرسمية (Rule 19)

جدول `holidays`:

| الحقل | النوع |
|---|---|
| `id` | INTEGER PK |
| `date` | TEXT `YYYY-MM-DD` |
| `name_ar` | TEXT |
| `name_fr` | TEXT |
| `is_recurring` | INTEGER 0/1 |
| `is_active` | INTEGER 0/1 |

**لا يُستخدم في الحساب** إلا إذا كان `include_holidays = 1`
في نوع الرخصة المعني. حالياً الجدول جاهز وقابل للتعبئة من
`Settings → العطل الرسمية`.

---

## 8. سرعة الإضافة (Rule 47)

إضافة رخصة = 4 خطوات:

```
الموظف  →  نوع الرخصة  →  تاريخ البداية  →  المدة  →  تأكيد
```

التطبيق يحسب تلقائياً:
- `end_date`
- `return_date`
- `duration` المحتسبة

ويعرضها في شاشة التأكيد قبل الحفظ.
