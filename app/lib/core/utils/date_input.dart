import '../error/app_exception.dart';
import 'app_date.dart';

/// تحويل مدخلات التاريخ إلى `YYYY-MM-DD` برسائل عربية مفهومة
/// (قاعدة 49) — **مصدر واحد** يستعمله كل المستودعات.
///
/// [AppDate.tryParse] لا يرمي أبداً (مناسب للمحلّلات)، وهذه
/// الطبقة للقراءة من المستخدم: مدخل خاطئ يجب أن يظهر كرسالة لا
/// كـ `FormatException` ولا كخطأ SQLite.
abstract final class DateInput {
  /// الرسالة الموحّدة لكل مدخل تاريخ غير صالح.
  static const String invalidMessage =
      'التاريخ غير صالح — الصيغة المطلوبة YYYY-MM-DD أو DD/MM/YYYY.';

  /// يوحّد إلى `YYYY-MM-DD` أو يرمي [AppException] برسالة عربية.
  static String iso(String raw) {
    final DateTime? d = AppDate.tryParse(raw);
    if (d == null) throw AppException(invalidMessage);
    return AppDate.format(d);
  }

  /// نسخة صامتة للفلاتر: مدخل خاطئ = **بلا قيد** لا خطأ.
  ///
  /// فلتر تاريخي فاسد يجب أن يُرجع كل الصفوف لا أن يوقف القراءة.
  static String? isoOrNull(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final DateTime? d = AppDate.tryParse(raw);
    return d == null ? null : AppDate.format(d);
  }
}
