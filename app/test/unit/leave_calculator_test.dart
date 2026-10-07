import 'package:admin_staff/core/constants/db_constants.dart';
import 'package:admin_staff/models/leave.dart';
import 'package:admin_staff/services/leave_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات محرك حساب الرخص (TESTING.md §3).
///
/// **القاعدة الذهبية:** كل نتيجة متوقعة تُشتق من [LeaveRuleConfig]
/// المرفوع في الاختبار — لا من قيمة ثابتة داخل المحرك.
void main() {
  // إعداد موحّد: عطلة نهاية الأسبوع = الجمعة + السبت (الجزائر).
  LeaveRuleConfig cfg({
    double duration = 1,
    String unit = Db.unitDays,
    bool countStartDay = true,
    bool includeWeekends = false,
    bool includeHolidays = false,
    String dayCountMode = Db.modeCalendar,
    String returnDayMode = Db.returnNextWorking,
  }) =>
      LeaveRuleConfig(
        duration: duration,
        unit: unit,
        countStartDay: countStartDay,
        includeWeekends: includeWeekends,
        includeHolidays: includeHolidays,
        dayCountMode: dayCountMode,
        returnDayMode: returnDayMode,
        weekendDays: const <int>{5, 6}, // الجمعة + السبت
      );

  String d(DateTime x) =>
      '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

  DateTime date(int y, int m, int day) => DateTime(y, m, day);

  group('الوحدة = ساعات', () {
    // H1: 48 ساعة، count_start_day = 1، تبدأ 03/10
    //     → 48h = 2 يوم → النهاية = 03/10 + (2-1) = 04/10
    test('H1: 48 ساعة مع احتساب يوم البداية', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: cfg(duration: 48, unit: Db.unitHours),
      );
      expect(d(r.endDate), '2026-10-04');
    });

    // H2: 48 ساعة، count_start_day = 0 → يوم البداية غير محتسب
    //     → النهاية = 03/10 + 2 = 05/10
    test('H2: 48 ساعة بدون احتساب يوم البداية', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: cfg(duration: 48, unit: Db.unitHours, countStartDay: false),
      );
      // تاريخ البداية المُدخل يبقى كما هو؛ غير المحتسب هو الحساب فقط.
      expect(d(r.startDate), '2026-10-03');
      expect(d(r.endDate), '2026-10-05');
      expect(r.spanDays, 3);
    });

    // H3: 24 ساعة = 1 يوم → النهاية = نفس اليوم
    test('H3: 24 ساعة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: cfg(duration: 24, unit: Db.unitHours),
      );
      expect(d(r.endDate), '2026-10-03');
    });

    // H4: 12 ساعة → ceil(12/24) = 1 يوم
    test('H4: 12 ساعة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: cfg(duration: 12, unit: Db.unitHours),
      );
      expect(d(r.endDate), '2026-10-03');
      expect(r.spanDays, 1);
    });

    // H5: 72 ساعة من 30/12/2026 → 3 أيام → 01/01/2027 (عبور السنة)
    test('H5: 72 ساعة تعبر نهاية السنة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 12, 30),
        rule: cfg(duration: 72, unit: Db.unitHours),
      );
      expect(d(r.endDate), '2027-01-01');
      expect(r.spanDays, 3);
    });
  });

  group('أيام + calendar', () {
    // C1: 1 يوم مع احتساب البداية → نفس اليوم
    test('C1: يوم واحد', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: cfg(duration: 1),
      );
      expect(d(r.endDate), '2026-10-03');
    });

    // C2: 3 أيام مع احتساب البداية → 03,04,05 → 05/10
    test('C2: 3 أيام مع احتساب يوم البداية', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: cfg(duration: 3),
      );
      expect(d(r.endDate), '2026-10-05');
      expect(r.spanDays, 3);
    });

    // C3: 3 أيام بدون احتساب → الأيام المحتسبة 04,05,06 → 06/10
    test('C3: 3 أيام بدون احتساب يوم البداية', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: cfg(duration: 3, countStartDay: false),
      );
      expect(d(r.startDate), '2026-10-03');
      expect(d(r.endDate), '2026-10-06');
      expect(r.spanDays, 4); // 03..06 لكن 03 غير محتسب
    });

    // C4: 15 يوماً من 01/10 → 15/10
    test('C4: 15 يوماً', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: cfg(duration: 15),
      );
      expect(d(r.endDate), '2026-10-15');
    });

    // C5: 2 يوم في فبراير (سنة غير كبيسة 2026) من 26/02 → 27/02
    test('C5: نهاية فبراير', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 2, 26),
        rule: cfg(duration: 2),
      );
      expect(d(r.endDate), '2026-02-27');
    });

    // C6: 5 أيام من 30/12/2026 → 03/01/2027 (عبور السنة)
    test('C6: عبور السنة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 12, 30),
        rule: cfg(duration: 5),
      );
      expect(d(r.endDate), '2027-01-03');
      expect(r.spanDays, 5);
    });

    // C7: يوم واحد في 31/12 → 31/12
    test('C7: يوم واحد في آخر السنة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 12, 31),
        rule: cfg(duration: 1),
      );
      expect(d(r.endDate), '2026-12-31');
    });

    // C8: عبور منتصف الشهر
    test('C8: عبور منتصف الشهر', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 1, 30),
        rule: cfg(duration: 4),
      );
      expect(d(r.endDate), '2026-02-02');
    });
  });

  group('أيام + working', () {
    // 2026-10-01 = الخميس
    // W1: 3 أيام عمل من الخميس 01/10 مع تخطي الجمعة+السبت
    //     الخميس(1) → الأحد(2) → الاثنين(3) = 05/10
    test('W1: 3 أيام عمل تخطي الجمعة والسبت', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: cfg(duration: 3, dayCountMode: Db.modeWorking),
      );
      expect(d(r.endDate), '2026-10-05');
      expect(r.countedDuration, 3);
      expect(r.workingDaysUsed, isTrue);
      // الأيام المستبعدة: الجمعة 02/10 والسبت 03/10
      expect(r.excludedDays.length, 2);
    });

    // W2: يوم واحد يبدأ يوم جمعة → الجمعة مستبعدة → السبت مستبعد
    //     → الأحد 04/10
    test('W2: يوم واحد يبدأ في جمعة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 2), // جمعة
        rule: cfg(duration: 1, dayCountMode: Db.modeWorking),
      );
      expect(d(r.startDate), '2026-10-02');
      expect(d(r.endDate), '2026-10-04'); // الأحد
      expect(r.excludedDays.length, 2); // الجمعة + السبت
    });

    // W3: 5 أيام عمل من 01/10
    //     الخميس(1) الأحد(2) الاثنين(3) الثلاثاء(4) الأربعاء(5)
    //     = 07/10
    test('W3: 5 أيام عمل', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: cfg(duration: 5, dayCountMode: Db.modeWorking),
      );
      expect(d(r.endDate), '2026-10-07');
    });

    // W4: includeWeekends = true → كل الأيام تُحتسب
    test('W4: احتساب نهاية الأسبوع', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: cfg(
          duration: 7,
          dayCountMode: Db.modeWorking,
          includeWeekends: true,
        ),
      );
      expect(d(r.endDate), '2026-10-07');
      expect(r.excludedDays, isEmpty);
    });

    // W5: العطل الرسمية تُحترم عندما يكون include_holidays = 0
    test('W5: تخطي العطل الرسمية عند تفعيل الخيار', () {
      final Set<DateTime> holidays = <DateTime>{
        DateTime(2026, 10, 5), // الاثنين
      };
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: cfg(duration: 3, dayCountMode: Db.modeWorking),
        holidays: holidays,
      );
      // الخميس(1) → الأحد(2) → الثلاثاء(3) لأن الاثنين عطلة
      expect(d(r.endDate), '2026-10-06');
      expect(r.excludedDays, contains(DateTime(2026, 10, 5)));
    });

    // W6: include_holidays = true → العطلة تُحتسب
    test('W6: احتساب العطل الرسمية', () {
      final Set<DateTime> holidays = <DateTime>{
        DateTime(2026, 10, 5),
      };
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: cfg(
          duration: 3,
          dayCountMode: Db.modeWorking,
          includeHolidays: true,
        ),
        holidays: holidays,
      );
      // الخميس(1) الأحد(2) الاثنين(3) = 05/10
      expect(d(r.endDate), '2026-10-05');
    });
  });

  group('حساب تاريخ العودة (returnDate)', () {
    // 2026-10-09 = جمعة
    // R1: immediate → 10/10 (السبت)
    test('R1: عودة مباشرة بعد جمعة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 8),
        rule: cfg(
          duration: 2,
          returnDayMode: Db.returnImmediate,
        ),
      );
      expect(d(r.endDate), '2026-10-09');
      expect(d(r.returnDate), '2026-10-10');
    });

    // R2: next_working_day بعد الجمعة → السبت مستبعد → الأحد 11/10
    test('R2: عودة لأول يوم عمل بعد جمعة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 8),
        rule: cfg(duration: 2, returnDayMode: Db.returnNextWorking),
      );
      expect(d(r.endDate), '2026-10-09');
      expect(d(r.returnDate), '2026-10-11'); // الأحد
    });

    // R3: endDate = سبت → الأحد 11/10
    test('R3: عودة بعد سبت', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 9), // جمعة
        rule: cfg(duration: 2, returnDayMode: Db.returnNextWorking),
      );
      expect(d(r.endDate), '2026-10-10'); // سبت
      expect(d(r.returnDate), '2026-10-11'); // الأحد
    });

    // R4: endDate = الأحد → الاثنين 12/10
    test('R4: عودة بعد يوم أحد', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 11), // الأحد
        rule: cfg(duration: 1, returnDayMode: Db.returnNextWorking),
      );
      expect(d(r.endDate), '2026-10-11');
      expect(d(r.returnDate), '2026-10-12'); // الاثنين
    });

    // R5: العطلة الرسمية تؤثر على العودة عند تفعيل include_holidays
    test('R5: تخطي عطلة رسمية في تاريخ العودة', () {
      final Set<DateTime> holidays = <DateTime>{
        DateTime(2026, 10, 12), // الاثنين
      };
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 11), // الأحد
        rule: cfg(duration: 1, returnDayMode: Db.returnNextWorking),
        holidays: holidays,
      );
      expect(d(r.returnDate), '2026-10-13'); // الثلاثاء
    });

    // R6: includeWeekends = true → السبت يوم عمل، فالعودة سبت
    test('R6: احتساب نهاية الأسبوع يغيّر العودة', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 8),
        rule: cfg(
          duration: 2,
          includeWeekends: true,
          returnDayMode: Db.returnNextWorking,
        ),
      );
      expect(d(r.endDate), '2026-10-09');
      expect(d(r.returnDate), '2026-10-10'); // السبت محتسب الآن
    });
  });

  group('الحالات الحدية (Validation)', () {
    test('E1: مدة صفر مرفوضة', () {
      expect(
        () => LeaveCalculator.calculate(
          startDate: date(2026, 10, 3),
          rule: cfg(duration: 0),
        ),
        throwsA(isA<LeaveCalculationException>()),
      );
    });

    test('E2: مدة سالبة مرفوضة', () {
      expect(
        () => LeaveCalculator.calculate(
          startDate: date(2026, 10, 3),
          rule: cfg(duration: -3),
        ),
        throwsA(isA<LeaveCalculationException>()),
      );
    });

    test('E3: مدة كسرية تُقرّب للأعلى', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: cfg(duration: 0.5),
      );
      expect(d(r.endDate), '2026-10-03');
      expect(r.spanDays, 1);
    });

    test('E4: NaN مرفوض', () {
      expect(
        () => LeaveCalculator.calculate(
          startDate: date(2026, 10, 3),
          rule: cfg(duration: double.nan),
        ),
        throwsA(isA<LeaveCalculationException>()),
      );
    });

    test('E5: أيام عمل بمدة كبيرة جداً لا تعلق', () {
      expect(
        () => LeaveCalculator.calculate(
          startDate: date(2026, 10, 3),
          rule: cfg(duration: 99999, dayCountMode: Db.modeWorking),
        ),
        throwsA(isA<LeaveCalculationException>()),
      );
    });
  });

  group('القيم الافتراضية من seed (قاعدة 17)', () {
    // هذه الاختبارات تؤكد أن المحرك يعمل بأي قيمة تأتي من القاعدة،
    // وليست مقيّدة بثوابت داخل الكود.
    test('وفاة أصل = 3 أيام من 01/10 → 03/10', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: const LeaveRuleConfig(
          duration: 3,
          unit: Db.unitDays,
          countStartDay: true,
          dayCountMode: Db.modeCalendar,
          returnDayMode: Db.returnNextWorking,
        ),
      );
      expect(d(r.endDate), '2026-10-03');
    });

    test('وفاة فرع = 2 يوم من 01/10 → 02/10', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: const LeaveRuleConfig(duration: 2),
      );
      expect(d(r.endDate), '2026-10-02');
    });

    test('ازدياد مولود = 15 يوماً من 01/10 → 15/10', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: const LeaveRuleConfig(duration: 15),
      );
      expect(d(r.endDate), '2026-10-15');
    });

    test('ترحال داخل المدينة = 1 يوم', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: const LeaveRuleConfig(duration: 1),
      );
      expect(d(r.endDate), '2026-10-03');
    });

    test('ترحال خارج المدينة = 3 أيام', () {
      final LeaveCalculationResult r = LeaveCalculator.calculate(
        startDate: date(2026, 10, 3),
        rule: const LeaveRuleConfig(duration: 3),
      );
      expect(d(r.endDate), '2026-10-05');
    });

    test('تعديل المدة في القاعدة يغيّر النتيجة فوراً', () {
      // نفس النوع لكن بمدة مختلفة → نتيجة مختلفة.
      // هذا يثبت أن المحرك لا يhard-code القيم.
      final LeaveCalculationResult r1 = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: const LeaveRuleConfig(duration: 3),
      );
      final LeaveCalculationResult r2 = LeaveCalculator.calculate(
        startDate: date(2026, 10, 1),
        rule: const LeaveRuleConfig(duration: 30),
      );
      expect(d(r1.endDate), '2026-10-03');
      expect(d(r2.endDate), '2026-10-30');
      expect(d(r1.endDate), isNot(d(r2.endDate)));
    });
  });

  group('اكتشاف التعارض (Rule 45)', () {
    test('فترتان متداخلتان', () {
      final bool o = LeaveCalculator.overlaps(
        date(2026, 10, 1),
        date(2026, 10, 5),
        date(2026, 10, 3),
        date(2026, 10, 10),
      );
      expect(o, isTrue);
    });

    test('فترتان غير متداخلتين', () {
      final bool o = LeaveCalculator.overlaps(
        date(2026, 10, 1),
        date(2026, 10, 5),
        date(2026, 10, 6),
        date(2026, 10, 10),
      );
      expect(o, isFalse);
    });

    test('تلامس في يوم واحد = تداخل', () {
      final bool o = LeaveCalculator.overlaps(
        date(2026, 10, 1),
        date(2026, 10, 5),
        date(2026, 10, 5),
        date(2026, 10, 8),
      );
      expect(o, isTrue);
    });

    test('نفس اليوم بالضبط = تداخل', () {
      final bool o = LeaveCalculator.overlaps(
        date(2026, 10, 3),
        date(2026, 10, 3),
        date(2026, 10, 3),
        date(2026, 10, 3),
      );
      expect(o, isTrue);
    });
  });
}
