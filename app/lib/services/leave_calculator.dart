import '../core/utils/app_date.dart';
import '../models/leave.dart';

/// وحدة المدة.
enum DurationUnit {
  hours('hours'),
  days('days');

  const DurationUnit(this.dbValue);
  final String dbValue;

  static DurationUnit fromDb(String? v) => v == 'hours'
      ? DurationUnit.hours
      : DurationUnit.days;
}

/// طريقة احتساب الأيام.
enum DayCountMode {
  calendar('calendar'),
  working('working');

  const DayCountMode(this.dbValue);
  final String dbValue;

  static DayCountMode fromDb(String? v) =>
      v == 'working' ? DayCountMode.working : DayCountMode.calendar;
}

/// طريقة حساب تاريخ العودة.
enum ReturnDayMode {
  immediate('immediate'),
  nextWorkingDay('next_working_day');

  const ReturnDayMode(this.dbValue);
  final String dbValue;

  static ReturnDayMode fromDb(String? v) => v == 'immediate'
      ? ReturnDayMode.immediate
      : ReturnDayMode.nextWorkingDay;
}

/// نتيجة الحساب — يُرجعها [LeaveCalculator.calculate].
class LeaveCalculationResult {
  const LeaveCalculationResult({
    required this.startDate,
    required this.endDate,
    required this.returnDate,
    required this.countedDuration,
    required this.unit,
    this.excludedDays = const <DateTime>[],
    this.workingDaysUsed = false,
  });

  final DateTime startDate;
  final DateTime endDate;
  final DateTime returnDate;

  /// المدة المحتسبة فعلياً (قد تختلف عن [LeaveRuleConfig.duration]
  /// في وضع الأيام العاملة).
  final double countedDuration;

  final DurationUnit unit;

  /// الأيام التي تم تخطّيها (weekends / holidays) — لعرضها للمستخدم.
  final List<DateTime> excludedDays;

  final bool workingDaysUsed;

  int get spanDays => AppDate.daysBetween(startDate, endDate) + 1;

  @override
  String toString() =>
      'LeaveCalculation(${AppDate.format(startDate)} → '
      '${AppDate.format(endDate)} → return ${AppDate.format(returnDate)})';
}

/// خطأ في مدخلات الحساب — يُعرض للمستخدم بلغة مفهومة.
class LeaveCalculationException implements Exception {
  const LeaveCalculationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// ★ **محرك حساب الرخص** (Rule 18).
///
/// مستقل تماماً عن الـ UI — لا يستورد أي حزمة Flutter.
/// يستقبل تاريخ البداية + المدة + إعدادات القاعدة،
/// ويرجع تاريخ النهاية وتاريخ العودة.
///
/// **لا hard-coded:** كل المدد والقواعد تأتي من [LeaveRuleConfig].
///
/// خوارزميات مدعومة:
///  - `hours` → تُحوّل إلى أيام تقويم مكافئة (`ceil(hours / 24)`)
///  - `days` + `calendar` → عدّ تقويم مباشر
///  - `days` + `working` → عدّ أيام عمل فقط مع تخطي weekends/holidays
///
/// العودة:
///  - `immediate` → `endDate + 1 day`
///  - `next_working_day` → أول يوم عام بعد `endDate`
abstract final class LeaveCalculator {
  /// يحسب تاريخ النهاية والعودة.
  ///
  /// يرمي [LeaveCalculationException] عند مدخلات غير صالحة.
  static LeaveCalculationResult calculate({
    required DateTime startDate,
    required LeaveRuleConfig rule,
    Set<DateTime>? holidays,
  }) {
    // ── التحقق (قاعدة 40) ────────────────────────────────────
    if (rule.duration.isNaN || rule.duration.isInfinite) {
      throw const LeaveCalculationException('قيمة مدة غير صالحة.');
    }
    if (rule.duration < 0) {
      throw const LeaveCalculationException('المدة لا يمكن أن تكون سالبة.');
    }
    if (rule.duration == 0) {
      throw const LeaveCalculationException('المدة يجب أن تكون أكبر من صفر.');
    }

    final DateTime start = AppDate.dateWithNoTime(startDate);
    final Set<DateTime> holidaySet =
        (holidays ?? const <DateTime>{}).map(AppDate.dateWithNoTime).toSet();

    // ── 1) حساب تاريخ النهاية ────────────────────────────────
    final _EndResult end;
    if (rule.isHours) {
      end = _endForHours(start, rule);
    } else if (rule.isWorkingDays) {
      end = _endForWorkingDays(start, rule, holidaySet);
    } else {
      end = _endForCalendarDays(start, rule);
    }

    // ── 2) حساب تاريخ العودة ─────────────────────────────────
    final DateTime returnDate = _returnDate(
      end.date,
      rule,
      holidaySet,
    );

    return LeaveCalculationResult(
      startDate: start,
      endDate: end.date,
      returnDate: returnDate,
      countedDuration: end.countedDuration,
      unit: DurationUnit.fromDb(rule.unit),
      excludedDays: end.excludedDays,
      workingDaysUsed: rule.isWorkingDays,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  الوحدة = ساعات
  // ════════════════════════════════════════════════════════════
  //
  //  الساعات تُعامل كعدد أيام تقويم مكافئ: ceil(hours / 24).
  //  مثال: 48 ساعة تبدأ 03/10 → 2 يوم → النهاية 04/10.
  static _EndResult _endForHours(
    DateTime start,
    LeaveRuleConfig rule,
  ) {
    final double hours = rule.duration;
    if (hours <= 0) {
      throw const LeaveCalculationException('المدة يجب أن تكون أكبر من صفر.');
    }
    if (hours > 24 * 3650) {
      throw const LeaveCalculationException('قيمة ساعات غير صالحة.');
    }

    final int equivalentDays = (hours / 24).ceil();

    // countStartDay = true → اليوم الأول محتسب.
    // countStartDay = false → نبدأ من اليوم التالي.
    final int offset = rule.countStartDay ? equivalentDays - 1 : equivalentDays;
    final DateTime end = AppDate.addDays(start, offset < 0 ? 0 : offset);

    return _EndResult(
      date: end,
      countedDuration: hours,
      excludedDays: const <DateTime>[],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  أيام + تقويم (calendar)
  // ════════════════════════════════════════════════════════════
  //
  //  countStartDay = true :  endDate = start + (duration - 1)
  //  countStartDay = false:  endDate = start + duration
  static _EndResult _endForCalendarDays(
    DateTime start,
    LeaveRuleConfig rule,
  ) {
    final int days = _wholeDays(rule.duration);
    final int offset = rule.countStartDay ? days - 1 : days;
    final DateTime end = AppDate.addDays(start, offset < 0 ? 0 : offset);

    return _EndResult(
      date: end,
      countedDuration: rule.duration,
      excludedDays: const <DateTime>[],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  أيام + أيام عمل (working)
  // ════════════════════════════════════════════════════════════
  //
  //  نعدّ الأيام العاملة فقط حتى نصل إلى المدة المطلوبة.
  static _EndResult _endForWorkingDays(
    DateTime start,
    LeaveRuleConfig rule,
    Set<DateTime> holidays,
  ) {
    final int target = _wholeDays(rule.duration);
    final List<DateTime> excluded = <DateTime>[];

    DateTime cursor = start;
    int counted = 0;

    // إذا كان يوم البداية غير محتسب، نبدأ من اليوم التالي.
    if (!rule.countStartDay) {
      cursor = AppDate.addDays(cursor, 1);
    }

    // حلقة أمان: أقصى عدد من المحاولات.
    const int maxIterations = 3650 * 2;
    int guard = 0;

    while (counted < target) {
      if (++guard > maxIterations) {
        throw const LeaveCalculationException(
          'تعذر حساب المدة: تجاوز الحد الأقصى للمحاولات. راجع إعدادات نوع الرخصة.',
        );
      }

      final bool isWeekend = !rule.includeWeekends &&
          AppDate.isWeekendDay(cursor, weekendDays: rule.weekendDays);
      final bool isHoliday =
          !rule.includeHolidays && holidays.contains(cursor);

      if (isWeekend || isHoliday) {
        excluded.add(cursor);
        cursor = AppDate.addDays(cursor, 1);
        continue;
      }

      counted++;
      if (counted >= target) break;
      cursor = AppDate.addDays(cursor, 1);
    }

    return _EndResult(
      date: cursor,
      countedDuration: counted.toDouble(),
      excludedDays: excluded,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  تاريخ العودة
  // ════════════════════════════════════════════════════════════
  static DateTime _returnDate(
    DateTime endDate,
    LeaveRuleConfig rule,
    Set<DateTime> holidays,
  ) {
    if (rule.isImmediateReturn) {
      // المباشرة: اليوم التالي مهما كان نوعه (R1).
      return AppDate.addDays(endDate, 1);
    }

    // next_working_day: أول يوم عام بعد تاريخ النهاية.
    DateTime cursor = AppDate.addDays(endDate, 1);
    const int maxIterations = 365;
    int guard = 0;

    while (true) {
      if (++guard > maxIterations) {
        // لم نجد يوم عمل خلال سنة — نعيد اليوم التالي كما هو.
        return AppDate.addDays(endDate, 1);
      }
      final bool isWeekend = !rule.includeWeekends &&
          AppDate.isWeekendDay(cursor, weekendDays: rule.weekendDays);
      final bool isHoliday =
          !rule.includeHolidays && holidays.contains(cursor);
      if (!isWeekend && !isHoliday) return cursor;
      cursor = AppDate.addDays(cursor, 1);
    }
  }

  // ── مساعدات ──────────────────────────────────────────────────

  /// يقرّب للأعلى للقيم الكسرية (0.5 يوم → 1 يوم).
  static int _wholeDays(double v) {
    final int r = v.ceil();
    return r < 1 ? 1 : r;
  }

  /// يفحص تداخل فترتين (قاعدة 45) — مساعد للاستخدام في الواجهات.
  static bool overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) =>
      AppDate.overlaps(aStart, aEnd, bStart, bEnd);
}

class _EndResult {
  const _EndResult({
    required this.date,
    required this.countedDuration,
    required this.excludedDays,
  });

  final DateTime date;
  final double countedDuration;
  final List<DateTime> excludedDays;
}
