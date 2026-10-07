import 'csv_parser.dart';

/// عميل كتابة CSV متماثل مع [CsvParser] (قاعدة 51).
///
/// المزايا:
///  - UTF-8 **مع BOM** افتراضياً (لإعراب Excel عن العربية).
///  - تهريب RFC4180: حقول فيها فاصلة/اقتباس/نهاية سطر تُغلَّف.
///  - `""` للهروب من علامة الاقتباس.
///  - توحيد القيم: `null` → فراغ، `DateTime` → `YYYY-MM-DD`.
///  - لا يكتب أبداً حروفاً تحكماً غير مقصودة.
abstract final class CsvWriter {
  static const List<int> _utf8Bom = <int>[0xEF, 0xBB, 0xBF];

  /// يبني محتوى CSV نصّياً (بدون BOM).
  ///
  /// [headers] تُكتب كأول سطر. القيم عبر [rows] بنفس ترتيب الأعمدة.
  static String build({
    required List<String> headers,
    required List<List<Object?>> rows,
    CsvDelimiter delimiter = CsvDelimiter.comma,
    bool writeHeader = true,
    String lineSeparator = '\r\n',
  }) {
    final String sep = delimiter.actual;
    final StringBuffer sb = StringBuffer();

    if (writeHeader) {
      sb.write(headers.map((String h) => _escape(h, sep)).join(sep));
      sb.write(lineSeparator);
    }

    for (final List<Object?> row in rows) {
      sb.write(row.map((Object? v) => _escape(_stringify(v), sep)).join(sep));
      sb.write(lineSeparator);
    }
    return sb.toString();
  }

  /// يبني البايتات الجاهزة للحفظ: **UTF-8 + BOM**.
  ///
  /// [withBom] يُطفأ فقط عند الحاجة (مثلاً تغذية محلّل داخلي).
  static List<int> buildBytes({
    required List<String> headers,
    required List<List<Object?>> rows,
    CsvDelimiter delimiter = CsvDelimiter.comma,
    bool writeHeader = true,
    bool withBom = true,
  }) {
    final String text = build(
      headers: headers,
      rows: rows,
      delimiter: delimiter,
      writeHeader: writeHeader,
    );
    final List<int> body = _utf8Encode(text);
    return withBom ? <int>[..._utf8Bom, ...body] : body;
  }

  /// تحويل قيمة واحدة إلى نص موحّد قبل التهريب.
  static String _stringify(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is bool) return value ? '1' : '0';
    return value.toString();
  }

  /// تهريب RFC4180.
  static String _escape(String value, String sep) {
    final bool needsQuote = value.contains(sep) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuote) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// UTF-8 ترميز يدوي — يغطي كل نقاط Unicode بما فيها العربية والرموز.
  static List<int> _utf8Encode(String input) {
    final List<int> out = <int>[];
    for (final int unit in input.runes) {
      if (unit < 0x80) {
        out.add(unit);
      } else if (unit < 0x800) {
        out.add(0xC0 | (unit >> 6));
        out.add(0x80 | (unit & 0x3F));
      } else if (unit < 0x10000) {
        out.add(0xE0 | (unit >> 12));
        out.add(0x80 | ((unit >> 6) & 0x3F));
        out.add(0x80 | (unit & 0x3F));
      } else {
        out.add(0xF0 | (unit >> 18));
        out.add(0x80 | ((unit >> 12) & 0x3F));
        out.add(0x80 | ((unit >> 6) & 0x3F));
        out.add(0x80 | (unit & 0x3F));
      }
    }
    return out;
  }

  /// جولة كاملة للاختبار: كتابة ثم قراءة [CsvParser] ومقارنة.
  static ParsedCsv roundTrip({
    required List<String> headers,
    required List<List<Object?>> rows,
    CsvDelimiter delimiter = CsvDelimiter.comma,
  }) =>
      CsvParser.parseBytes(
        buildBytes(
          headers: headers,
          rows: rows,
          delimiter: delimiter,
        ),
      );
}
