import 'dart:convert';

import '../../error/app_exception.dart';

/// فواصل CSV المدعومة (قاعدة §8 — لا نفترض فاصلة دائماً).
enum CsvDelimiter {
  comma(',', 'Comma', ','),
  semicolon(';', 'Semicolon', ';'),
  tab(r'\t', 'Tab', '\t'),
  pipe('|', 'Pipe', '|');

  const CsvDelimiter(this.char, this.label, this.actual);

  /// الرمز المخزّن (TAB يُخزَّن كـ `\t` للعرض).
  final String char;
  final String label;
  final String actual;

  static CsvDelimiter? fromChar(String? c) {
    if (c == null) return null;
    for (final CsvDelimiter d in values) {
      if (d.char == c || d.actual == c) return d;
    }
    return null;
  }

  static CsvDelimiter fromLabel(String? label) {
    for (final CsvDelimiter d in values) {
      if (d.label == label) return d;
    }
    return CsvDelimiter.comma;
  }
}

/// نتيجة تحليل ملف CSV.
class ParsedCsv {
  const ParsedCsv({
    required this.headers,
    required this.rows,
    required this.delimiter,
    required this.encoding,
    this.hasBom = false,
    this.discardedRows = 0,
    this.truncatedRows = 0,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final CsvDelimiter delimiter;
  final String encoding;
  final bool hasBom;

  /// صفوف أعمدتها أقل من الرأس وتُرفض.
  final int discardedRows;

  /// صفوف أعمدتها **أكثر** من الرأس — تُقصّ أعمدتها الزائدة مع تحذير.
  final int truncatedRows;

  int get columnCount => headers.length;
  int get rowCount => rows.length;
  bool get isEmpty => rows.isEmpty;

  /// مجموع الصفوف المحسوبة (ناقصة أو زائدة) — تُعرض في شاشة المعاينة.
  int get problemRows => discardedRows + truncatedRows;

  /// الفهرس البصري لعمود بالاسم (غير حساس لحالة الأحرف).
  int? indexOfHeader(String name) {
    final String target = name.trim().toLowerCase();
    for (int i = 0; i < headers.length; i++) {
      if (headers[i].trim().toLowerCase() == target) return i;
    }
    return null;
  }
}

/// ★ محلّل CSV (قاعدة 51).
///
/// المزايا:
///  - كشف `delimiter` تلقائياً (`,` `;` TAB `|`)
///  - دعم اقتباسات RFC4180: `"Smith, John"` و `""` للهروب
///  - خطوط نهايتها `CRLF` / `LF` / `CR`
///  - إزالة UTF-8 BOM تلقائياً
///  - الحفاظ على العربية UTF-8 بدون تشويه
///  - رفض الصفوف ناقصة الأعمدة مع عدّها
abstract final class CsvParser {
  static const List<int> _bom = <int>[0xEF, 0xBB, 0xBF];

  // ── فك الترميز ───────────────────────────────────────────────

  /// يفكّ ترميز بايتات الملف ويُزيل BOM.
  static ({String text, String encoding, bool hasBom}) decode(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const AppException('الملف فارغ.');
    }

    bool hasBom = false;
    List<int> data = bytes;

    if (bytes.length >= 3 &&
        bytes[0] == _bom[0] && bytes[1] == _bom[1] && bytes[2] == _bom[2]) {
      hasBom = true;
      data = bytes.sublist(3);
    }

    // UTF-16 LE (FF FE) — Excel العربي أحياناً يحفظ هكذا.
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return (
        text: _decodeUtf16(bytes, 2, littleEndian: true),
        encoding: 'UTF-16 LE',
        hasBom: true,
      );
    }

    // UTF-16 BE (FE FF)
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return (
        text: _decodeUtf16(bytes, 2, littleEndian: false),
        encoding: 'UTF-16 BE',
        hasBom: true,
      );
    }

    // UTF-8 مع تسامح — العربية لا يجب أن تتشوه.
    try {
      final String t = utf8.decode(data, allowMalformed: false);
      return (text: t, encoding: 'UTF-8', hasBom: hasBom);
    } catch (_) {
      // محاولة أخيرة بتسامح لتفادي فقدان الملف كله.
      try {
        final String t = utf8.decode(data, allowMalformed: true);
        return (text: t, encoding: 'UTF-8 (partial)', hasBom: hasBom);
      } catch (_) {
        throw const AppException(
          'تعذر قراءة ترميز الملف. المطلوب UTF-8.',
        );
      }
    }
  }

  // ── الواجهة المختصرة ────────────────────────────────────────

  /// يفكّ الترميز ثم يحلّل — الأعلى استخداماً في خدمات الاستيراد.
  static ParsedCsv parseBytes(
    List<int> bytes, {
    CsvDelimiter? delimiter,
    bool hasHeader = true,
  }) {
    final ({String text, String encoding, bool hasBom}) decoded = decode(bytes);
    return parse(
      decoded.text,
      delimiter: delimiter,
      hasHeader: hasHeader,
      encoding: decoded.encoding,
      hasBom: decoded.hasBom,
    );
  }

  // ── كشف الفاصل ───────────────────────────────────────────────

  /// يكشف أفضل `delimiter` حسب اتساق عدد الأعمدة عبر الأسطر.
  static CsvDelimiter detectDelimiter(String text) {
    final List<String> lines = _firstLines(text, 20);
    if (lines.isEmpty) return CsvDelimiter.comma;

    CsvDelimiter best = CsvDelimiter.comma;
    int bestScore = -1;

    for (final CsvDelimiter d in CsvDelimiter.values) {
      final List<int> counts = lines
          .map((String l) => _countOutsideQuotes(l, d.actual))
          .toList();
      if (counts.isEmpty) continue;

      // نريد: نفس العدد في كل السطور + عدد > 0.
      final int first = counts.first;
      if (first == 0) continue;

      final int consistent = counts.where((int c) => c == first).length;
      final int score = consistent * 100 + first;
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }

  // ── التحليل الرئيسي ─────────────────────────────────────────

  /// يحلّل نص CSV كاملاً.
  ///
  /// [delimiter] اختياري؛ إذا لم يُمرَّر يتم كشفه تلقائياً.
  static ParsedCsv parse(
    String text, {
    CsvDelimiter? delimiter,
    bool hasHeader = true,
    String encoding = 'UTF-8',
    bool hasBom = false,
  }) {
    if (text.trim().isEmpty) {
      throw const AppException('الملف فارغ.');
    }

    final CsvDelimiter d = delimiter ?? detectDelimiter(text);
    final List<List<String>> records = _parseRecords(text, d.actual);

    if (records.isEmpty) {
      throw const AppException('الملف فارغ.');
    }

    if (!hasHeader) {
      // توليد أعمدة رقمية.
      final int width = records.fold<int>(
        0,
        (int m, List<String> r) => r.length > m ? r.length : m,
      );
      return ParsedCsv(
        headers: List<String>.generate(width, (int i) => 'col_$i'),
        rows: records,
        delimiter: d,
        encoding: encoding,
        hasBom: hasBom,
      );
    }

    final List<String> headers =
        records.first.map((String h) => h.trim()).toList();
    final List<List<String>> rows = records.skip(1).toList();

    int discarded = 0;
    int truncated = 0;
    final List<List<String>> valid = <List<String>>[];
    for (final List<String> r in rows) {
      // صف خالٍ تماماً → يُهمل بصمت.
      if (r.every((String c) => c.trim().isEmpty)) {
        discarded++;
        continue;
      }
      // صف ناقص الأعمدة → يُرفض ويُعدّ.
      if (r.length < headers.length) {
        discarded++;
        continue;
      }
      // الزائد يُقصّ مع تحذير.
      if (r.length > headers.length) {
        truncated++;
        valid.add(r.sublist(0, headers.length));
      } else {
        valid.add(r);
      }
    }

    return ParsedCsv(
      headers: headers,
      rows: valid,
      delimiter: d,
      encoding: encoding,
      hasBom: hasBom,
      discardedRows: discarded,
      truncatedRows: truncated,
    );
  }

  // ── التحليل الأساسي (يدعم الاقتباس) ────────────────────────

  static List<List<String>> _parseRecords(String text, String delimiter) {
    final List<List<String>> records = <List<String>>[];
    final List<String> current = <String>[];
    final StringBuffer field = StringBuffer();

    bool inQuotes = false;
    bool fieldWasQuoted = false;

    for (int i = 0; i < text.length; i++) {
      final String c = text[i];

      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++; // تخطّي علامة الاقتباس الثانية.
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
        continue;
      }

      if (c == '"' && field.toString().trim().isEmpty) {
        inQuotes = true;
        fieldWasQuoted = true;
        continue;
      }

      if (c == delimiter) {
        current.add(field.toString());
        field.clear();
        fieldWasQuoted = false;
        continue;
      }

      if (c == '\r' || c == '\n') {
        // نهاية السطر: CRLF / LF / CR كلها مدعومة.
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++; // ابتلع \n المصاحبة لـ \r.
        }
        current.add(field.toString());
        field.clear();
        // نسخة مستقلة: current.clear() لاحقاً لا يمسّ السجلّ المحفوظ.
        records.add(List<String>.of(current));
        current.clear();
        fieldWasQuoted = false;
        continue;
      }

      field.write(c);
    }

    // آخر سطر بدون نهاية سطر.
    if (field.isNotEmpty || current.isNotEmpty || fieldWasQuoted) {
      current.add(field.toString());
      records.add(List<String>.of(current));
    }

    // إزالة السطور الفارغة تماماً.
    return records
        .where((List<String> r) => r.any((String c) => c.trim().isNotEmpty))
        .toList();
  }

  // ── مساعدات ──────────────────────────────────────────────────

  /// فك ترميز UTF-16 يدوياً (Dart لا يوفّر codec جاهزاً له).
  static String _decodeUtf16(
    List<int> bytes,
    int offset, {
    required bool littleEndian,
  }) {
    final StringBuffer sb = StringBuffer();
    for (int i = offset; i + 1 < bytes.length; i += 2) {
      final int unit = littleEndian
          ? (bytes[i] | (bytes[i + 1] << 8))
          : ((bytes[i] << 8) | bytes[i + 1]);
      if (unit == 0) {
        throw const AppException(
          'تعذر قراءة ترميز الملف. حوّله إلى UTF-8 ثم أعد المحاولة.',
        );
      }
      if (unit >= 0xD800 && unit <= 0xDBFF && i + 3 < bytes.length) {
        final int low = littleEndian
            ? (bytes[i + 2] | (bytes[i + 3] << 8))
            : ((bytes[i + 2] << 8) | bytes[i + 3]);
        if (low >= 0xDC00 && low <= 0xDFFF) {
          sb.writeCharCode(
            0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00),
          );
          i += 2;
          continue;
        }
      }
      sb.writeCharCode(unit);
    }
    return sb.toString();
  }

  static List<String> _firstLines(String text, int n) {
    final List<String> lines = <String>[];
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < text.length && lines.length < n; i++) {
      if (text[i] == '\n') {
        lines.add(buf.toString());
        buf.clear();
      } else if (text[i] != '\r') {
        buf.write(text[i]);
      }
    }
    if (buf.isNotEmpty) lines.add(buf.toString());
    return lines.where((String l) => l.trim().isNotEmpty).toList();
  }

  static int _countOutsideQuotes(String line, String delimiter) {
    int count = 0;
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final String c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (!inQuotes && c == delimiter) count++;
    }
    return count;
  }
}
