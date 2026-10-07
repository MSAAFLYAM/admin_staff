import 'package:intl/intl.dart';

/// معالجة التواريخ الموحدة (قاعدة 53 و80).
///
/// **القاعدة:** كل تواريخ الرخص الإدارية تُخزَّن وتُعامل
/// كـ *Calendar Date* بصيغة `YYYY-MM-DD` — ليست timestamp.
/// هذا يمنع مشاكل timezone/ DST نهائياً.
abstract final class AppDate {
  /// التنسيق الداخلي الموحد.
  static const String iso = 'yyyy-MM-dd';

  // ── التنسيق ─────────────────────────────────────────────────

  /// يحوّل [date] إلى `YYYY-MM-DD`.
  static String format(DateTime date) {
    final DateTime d = dateWithNoTime(date);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// `[date]` بدون وقت (midnight).
  static DateTime dateWithNoTime(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// **اليوم** كـ calendar date.
  static DateTime today([DateTime? now]) =>
      dateWithNoTime(now ?? DateTime.now());

  // ── التحليل ─────────────────────────────────────────────────

  /// أنماط التاريخ المقبولة عند الاستيراد (قاعدة 80).
  static final List<DateFormat> _inputFormats = <DateFormat>[
    DateFormat('yyyy-MM-dd'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd.MM.yyyy'),
    DateFormat('d/M/yyyy'),
    DateFormat('d-M-yyyy'),
    DateFormat('d.M.yyyy'),
    DateFormat('dd/MM/yy'),
    DateFormat('d/M/yy'),
  ];

  /// يحلّل نص تاريخ بأي تنسيق مدعوم.
  ///
  /// يُرجع `null` إذا لم يتعرّف على أي تنسيق.
  /// **لا يرمي استثناءات أبداً.**
  static DateTime? tryParse(String? raw) {
    if (raw == null) return null;
    final String value = raw.trim();
    if (value.isEmpty) return null;

    // تنسيق داخلي — الأسرع.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      try {
        final List<int> p = value.split('-').map(int.parse).toList();
        return _valid(p[0], p[1], p[2]);
      } catch (_) {
        return null;
      }
    }

    for (final DateFormat f in _inputFormats) {
      try {
        final DateTime d = f.parseStrict(value);
        return _valid(d.year, d.month, d.day);
      } catch (_) {
        // نجرب التنسيق التالي.
      }
    }
    return null;
  }

  /// يتحقق من صلاحية (year, month, day) ويعيد تاريخاً بدون وقت.
  /// يرفض يوم 32 أو شهر 13 أو 31/02.
  static DateTime _valid(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2200) {
      throw const FormatException('invalid date parts');
    }
    final DateTime date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) {
      throw const FormatException('nonexistent date');
    }
    return date;
  }

  /// يحلّل ويرمي استثناء عند الفشل — للاستخدام مع رسائل الخطأ.
  static DateTime parseStrict(String raw) {
    final DateTime? d = tryParse(raw);
    if (d == null) {
      throw FormatException('invalid date: $raw');
    }
    return d;
  }

  // ── عمليات ──────────────────────────────────────────────────

  /// هل يقع [day] داخل الفترة `[from, to]` (شاملة الطرفين)؟
  static bool isBetween(DateTime day, DateTime from, DateTime to) {
    final DateTime d = dateWithNoTime(day);
    final DateTime f = dateWithNoTime(from);
    final DateTime t = dateWithNoTime(to);
    final bool ordered = f.isBefore(t) || f.isAtSameMomentAs(t);
    final DateTime start = ordered ? f : t;
    final DateTime end = ordered ? t : f;
    return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
        (d.isBefore(end) || d.isAtSameMomentAs(end));
  }

  /// هل تتداخل فترتان؟ (يُستخدم في اكتشاف التعارض — Rule 45)
  static bool overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final DateTime as = dateWithNoTime(aStart);
    final DateTime ae = dateWithNoTime(aEnd);
    final DateTime bs = dateWithNoTime(bStart);
    final DateTime be = dateWithNoTime(bEnd);
    return !as.isAfter(be) && !bs.isAfter(ae);
  }

  /// إضافة أيام تقويم.
  static DateTime addDays(DateTime date, int days) =>
      dateWithNoTime(date).add(Duration(days: days));

  /// الفرق بالأيام (من أول يوم إلى الثاني).
  static int daysBetween(DateTime a, DateTime b) {
    final DateTime from = dateWithNoTime(a);
    final DateTime to = dateWithNoTime(b);
    return to.difference(from).inDays;
  }

  // ── أيام الأسبوع ( الجزائر: الجمعة + السبت ) ──────────────

  /// أيام العطلة الأسبوعية الافتراضية.
  /// `DateTime.monday = 1` … `friday = 5`, `saturday = 6`, `sunday = 7`.
  static const Set<int> defaultWeekendDays = <int>{5, 6};

  static bool isWeekendDay(
    DateTime date, {
    Set<int> weekendDays = defaultWeekendDays,
  }) =>
      weekendDays.contains(dateWithNoTime(date).weekday);

  // ── بداية/نهاية الأسبوع ─────────────────────────────────────

  /// بداية الأسبوع المحتسبة (السبت في الجزائر افتراضياً نظراً
  /// لكون نهاية الأسبوع الجمعة+السبت؛ نبدأ بالسبت لتوافق التقويم).
  static DateTime startOfWeek(
    DateTime date, {
    int firstWeekday = DateTime.saturday,
  }) {
    final DateTime d = dateWithNoTime(date);
    final int diff = (d.weekday - firstWeekday + 7) % 7;
    return d.subtract(Duration(days: diff));
  }

  static DateTime endOfWeek(
    DateTime date, {
    int firstWeekday = DateTime.saturday,
  }) =>
      addDays(startOfWeek(date, firstWeekday: firstWeekday), 6);

  // ── تنسيق للعرض ─────────────────────────────────────────────

  /// تنسيق مختصر لعرض القوائم: `03/10/2026`.
  static String display(String? isoDate) {
    final DateTime? d = tryParse(isoDate);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  /// تنسيق عربي/فرنسي حسب locale — للعناوين الطويلة.
  static String displayLocalized(
    String? isoDate,
    String languageCode, {
    String fallback = '—',
  }) {
    final DateTime? d = tryParse(isoDate);
    if (d == null) return fallback;
    return DateFormat.yMMMd(languageCode).format(d);
  }

  // ── أوقات المداومة ──────────────────────────────────────────

  static final RegExp _timeRe =
      RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?$');

  /// يتحقق من صيغة `HH:mm` (أو `H:mm` / `HH:mm:ss`).
  static String? normalizeTime(String? raw) {
    if (raw == null) return null;
    final String v = raw.trim().replaceAll('.', ':');
    if (v.isEmpty) return null;
    final RegExpMatch? m = _timeRe.firstMatch(v);
    if (m == null) return null;
    final int h = int.parse(m.group(1)!);
    final String mm = m.group(2)!;
    return '${h.toString().padLeft(2, '0')}:$mm';
  }

  /// يستخرج وقت البداية والنهاية من نص `horaire`.
  ///
  /// يدعم: `08:00 - 16:00`, `08:00-16:00`, `08:00 à 16:00`,
  /// `08:00`, `8h00 - 16h00`.
  static (String?, String?) parseSchedule(String? raw) {
    if (raw == null) return (null, null);
    String v = raw.trim();
    if (v.isEmpty) return (null, null);
    v = v.replaceAll(RegExp(r'\bh\b'), ':').replaceAll('–', '-');

    final List<String> parts = v.split(RegExp(r'\s*-\s*|\s+à\s+|\s+to\s+'));
    if (parts.length >= 2) {
      return (normalizeTime(parts[0]), normalizeTime(parts[1]));
    }
    return (normalizeTime(v), null);
  }
}
