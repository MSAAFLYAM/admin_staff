import 'package:admin_staff/core/utils/csv/csv_parser.dart';
import 'package:admin_staff/core/utils/csv/csv_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات كاتب CSV — الدور الكامل: كتابة ← قراءة (round-trip).
void main() {
  group('الكتابة الأساسية', () {
    test('W1: رأس + صف واحد', () {
      final String text = CsvWriter.build(
        headers: <String>['a', 'b'],
        rows: <List<Object?>>[
          <Object?>['1', '2'],
        ],
      );
      expect(text, 'a,b\r\n1,2\r\n');
    });

    test('W2: بدون رأس', () {
      final String text = CsvWriter.build(
        headers: <String>['a', 'b'],
        rows: <List<Object?>>[
          <Object?>['1', '2'],
        ],
        writeHeader: false,
      );
      expect(text, '1,2\r\n');
    });

    test('W3: null → خانة فارغة', () {
      final String text = CsvWriter.build(
        headers: <String>['a', 'b'],
        rows: <List<Object?>>[
          <Object?>[null, 'x'],
        ],
      );
      expect(text, 'a,b\r\n,x\r\n');
    });

    test('W4: bool → 1/0', () {
      final String text = CsvWriter.build(
        headers: <String>['f'],
        rows: <List<Object?>>[
          <Object?>[true],
          <Object?>[false],
        ],
      );
      expect(text, 'f\r\n1\r\n0\r\n');
    });

    test('W5: فاصلة داخل حقل تُغلَّف باقتباس', () {
      final String text = CsvWriter.build(
        headers: <String>['name'],
        rows: <List<Object?>>[
          <Object?>['Smith, John'],
        ],
      );
      expect(text, 'name\r\n"Smith, John"\r\n');
    });

    test('W6: علامة اقتباس تُهرَّب بمزدوجة', () {
      final String text = CsvWriter.build(
        headers: <String>['msg'],
        rows: <List<Object?>>[
          <Object?>['said "hi"'],
        ],
      );
      expect(text, 'msg\r\n"said ""hi"""\r\n');
    });

    test('W7: فاصلة منقوطة كفاصل مُمرَّر', () {
      final String text = CsvWriter.build(
        headers: <String>['a', 'b'],
        rows: <List<Object?>>[
          <Object?>['x;y', 'z'],
        ],
        delimiter: CsvDelimiter.semicolon,
      );
      expect(text, 'a;b\r\n"x;y";z\r\n');
    });

    test('W8: نهاية سطر داخل حقل محفوظة', () {
      final String text = CsvWriter.build(
        headers: <String>['a'],
        rows: <List<Object?>>[
          <Object?>['l1\nl2'],
        ],
      );
      expect(text, 'a\r\n"l1\nl2"\r\n');
    });
  });

  group('البايتات والترميز', () {
    test('B1: BOM يُكتب افتراضياً', () {
      final List<int> bytes = CsvWriter.buildBytes(
        headers: <String>['name'],
        rows: <List<Object?>>[
          <Object?>['بن عيسى'],
        ],
      );
      expect(bytes.sublist(0, 3), <int>[0xEF, 0xBB, 0xBF]);
    });

    test('B2: يمكن كتم BOM', () {
      final List<int> bytes = CsvWriter.buildBytes(
        headers: <String>['name'],
        rows: <List<Object?>>[
          <Object?>['x'],
        ],
        withBom: false,
      );
      expect(bytes.first, isNot(0xEF));
    });

    test('B3: العربية تنجو من الترميز (round-trip)', () {
      final ParsedCsv csv = CsvWriter.roundTrip(
        headers: <String>['nom_ar', 'matricule'],
        rows: <List<Object?>>[
          <Object?>['بن عيسى أحمد', '12547'],
          <Object?>['Ôuali Naïma', '90210'],
        ],
      );
      expect(csv.hasBom, isTrue);
      expect(csv.encoding, 'UTF-8');
      expect(csv.headers, <String>['nom_ar', 'matricule']);
      expect(csv.rowCount, 2);
      expect(csv.rows[0], <String>['بن عيسى أحمد', '12547']);
      expect(csv.rows[1][0], 'Ôuali Naïma');
    });

    test('B4: round-trip مع فاصلة منقوطة', () {
      final ParsedCsv csv = CsvWriter.roundTrip(
        headers: <String>['a', 'b'],
        rows: <List<Object?>>[
          <Object?>['x,y', 'z'],
        ],
        delimiter: CsvDelimiter.semicolon,
      );
      expect(csv.delimiter, CsvDelimiter.semicolon);
      expect(csv.rows.first, <String>['x,y', 'z']);
    });

    test('B5: round-trip مع حقول اقتباس مركّبة', () {
      final ParsedCsv csv = CsvWriter.roundTrip(
        headers: <String>['msg', 'n'],
        rows: <List<Object?>>[
          <Object?>['قال "مرحبا"، ثم "أهلا"', '5'],
          <Object?>['a,b;c\nd', '6'],
        ],
      );
      expect(csv.rowCount, 2);
      expect(csv.rows[0][0], 'قال "مرحبا"، ثم "أهلا"');
      expect(csv.rows[1][0], 'a,b;c\nd');
      expect(csv.rows[1][1], '6');
    });

    test('B6: صف طويل (15 عمود) لا ينكسر', () {
      final List<String> headers =
          List<String>.generate(15, (int i) => 'c$i');
      final List<Object?> row =
          List<Object?>.generate(15, (int i) => 'v$i');
      final ParsedCsv csv = CsvWriter.roundTrip(
        headers: headers,
        rows: <List<Object?>>[row],
      );
      expect(csv.headers, headers);
      expect(csv.rows.first, row.map((Object? v) => v! as String).toList());
    });

    test('B7: صفوف فارغة تماماً → ملف برأس فقط يُقرأ كـ 0 صفوف', () {
      final List<int> bytes = CsvWriter.buildBytes(
        headers: <String>['a', 'b'],
        rows: <List<Object?>>[],
      );
      final ParsedCsv csv = CsvParser.parseBytes(bytes);
      expect(csv.rowCount, 0);
      expect(csv.headers, <String>['a', 'b']);
    });

    test('B8: مسافات ونهايات محفوظة كما هي', () {
      final ParsedCsv csv = CsvWriter.roundTrip(
        headers: <String>['v'],
        rows: <List<Object?>>[
          <Object?>['  padded  '],
        ],
      );
      expect(csv.rows.first.first, '  padded  ');
    });

    test('B9: قيمة رقمية تُكتب كنص', () {
      final String text = CsvWriter.build(
        headers: <String>['n'],
        rows: <List<Object?>>[
          <Object?>[12547],
        ],
      );
      expect(text, 'n\r\n12547\r\n');
    });
  });
}
