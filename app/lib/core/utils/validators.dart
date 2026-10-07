import 'app_date.dart';

/// فوائد التحقق من المدخلات (قاعدة 40).
///
/// كل دالة تُرجع `null` عند الصحة، أو رسالة خطأ **بلغة مفهومة للمستخدم**
/// (قاعدة 49 — لا أخطاء تقنية مثل SQLiteException).
abstract final class Validators {
  /// حقل إلزامي.
  static String? required(String? v, {String? message}) {
    if (v == null || v.trim().isEmpty) {
      return message ?? 'هذا الحقل إلزامي.';
    }
    return null;
  }

  /// Matricule إلزامي ولا يمكن أن يكون فارغاً (قاعدة 10).
  static String? matricule(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'حقل Matricule إلزامي ولا يمكن أن يكون فارغاً.';
    }
    if (v.trim().length > 64) {
      return 'رقم Matricule طويل جداً (الحد الأقصى 64 حرفاً).';
    }
    return null;
  }

  /// الاسم بالعربية أو الفرنسية — كلاهما فارغ = خطأ.
  static String? name({
    String? nomAr,
    String? prenomAr,
    String? nomFr,
    String? prenomFr,
  }) {
    final bool hasAr = (nomAr ?? '').trim().isNotEmpty ||
        (prenomAr ?? '').trim().isNotEmpty;
    final bool hasFr = (nomFr ?? '').trim().isNotEmpty ||
        (prenomFr ?? '').trim().isNotEmpty;
    if (!hasAr && !hasFr) {
      return 'يجب إدخال الاسم بالعربية أو الفرنسية.';
    }
    return null;
  }

  /// PPR — يُخزَّن نصاً، نقبل أرقاماً وشرطة ومسافة فقط.
  static String? ppr(String? v) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^[0-9\s\-/]+$').hasMatch(s)) {
      return 'قيمة PPR غير صالحة (تُقبل الأرقام والشرطة فقط).';
    }
    if (s.length > 64) return 'قيمة PPR طويلة جداً.';
    return null;
  }

  /// رقم هاتف — نخزّنه نصاً (قد يبدأ بـ 0 أو +).
  static String? phone(String? v) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^[+0-9\s\-()]+$').hasMatch(s)) {
      return 'رقم هاتف غير صالح.';
    }
    if (s.replaceAll(RegExp(r'[^0-9]'), '').length < 5) {
      return 'رقم هاتف غير صالح (قصير جداً).';
    }
    return null;
  }

  /// تاريخ صالح.
  static String? date(String? v) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (AppDate.tryParse(s) == null) {
      return 'تنسيق تاريخ غير معروف: "$s"';
    }
    return null;
  }

  /// تاريخ إلزامي.
  static String? dateRequired(String? v) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return 'التاريخ إلزامي.';
    if (AppDate.tryParse(s) == null) {
      return 'تنسيق تاريخ غير معروف: "$s"';
    }
    return null;
  }

  /// النهاية يجب أن تكون بعد البداية (أو مساوية لها).
  static String? dateRange({required String? start, required String? end}) {
    final DateTime? s = AppDate.tryParse(start);
    final DateTime? e = AppDate.tryParse(end);
    if (s == null || e == null) return null;
    if (e.isBefore(s)) return 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية.';
    return null;
  }

  /// مدة موجبة.
  static String? duration(double? v) {
    if (v == null) return 'المدة إلزامية.';
    if (v.isNaN || v.isInfinite) return 'قيمة مدة غير صالحة.';
    if (v <= 0) return 'المدة يجب أن تكون أكبر من صفر.';
    if (v > 3650) return 'المدة كبيرة جداً (الحد الأقصى 3650).';
    return null;
  }

  /// ساعات ضمن نطاق منطقي.
  static String? hours(double? v) {
    final String? base = duration(v);
    if (base != null) return base;
    if (v! > 24 * 365) return 'قيمة ساعات غير صالحة.';
    return null;
  }

  /// نص غير فارغ بحد أقصى للأطوال.
  static String? text(String? v, {int max = 200, String? label}) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (s.length > max) {
      return '${label ?? 'النص'} طويل جداً (الحد الأقصى $max).';
    }
    return null;
  }

  /// اسم مرجعي (قسم/رتبة/وظيفة/نوع رخصة) — إلزامي + طول.
  static String? referenceName(String? v, {int max = 120}) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return 'الاسم إلزامي.';
    if (s.length > max) return 'الاسم طويل جداً (الحد الأقصى $max).';
    return null;
  }

  /// PIN من 4 إلى 8 أرقام.
  static String? pin(String? v) {
    final String s = (v ?? '').trim();
    if (s.length < 4) return 'يجب أن يتكون الرمز من 4 أرقام على الأقل.';
    if (s.length > 8) return 'يجب ألا يتجاوز الرمز 8 أرقام.';
    if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
      return 'يجب أن يحتوي الرمز على أرقام فقط.';
    }
    return null;
  }
}
