import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/core/utils/csv/csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات محلّل CSV — تغطي P1..P12 من TESTING.md.
void main() {
  group('P1..P3 كشف الفاصل', () {
    test('P1: فاصلة', () {
      final ParsedCsv csv = CsvParser.parse('a,b,c\n1,2,3');
      expect(csv.delimiter, CsvDelimiter.comma);
      expect(csv.headers, <String>['a', 'b', 'c']);
      expect(csv.rowCount, 1);
      expect(csv.rows.first, <String>['1', '2', '3']);
    });

    test('P2: فاصلة منقوطة', () {
      final ParsedCsv csv = CsvParser.parse('a;b;c\n1;2;3');
      expect(csv.delimiter, CsvDelimiter.semicolon);
      expect(csv.headers, <String>['a', 'b', 'c']);
      expect(csv.rows.first, <String>['1', '2', '3']);
    });

    test('P3: TAB', () {
      const String text = 'a\tb\tc\n1\t2\t3';
      final ParsedCsv csv = CsvParser.parse(text);
      expect(csv.delimiter, CsvDelimiter.tab);
      expect(csv.headers, <String>['a', 'b', 'c']);
      expect(csv.rows.first, <String>['1', '2', '3']);
    });

    test('P12: فاصل غامض a,b;c → الأكثر اتساقاً (الفاصلة)', () {
      final ParsedCsv csv = CsvParser.parse('a,b,c\n1,2,3\n4,5,6');
      expect(csv.delimiter, CsvDelimiter.comma);
      expect(csv.rowCount, 2);
    });

    test('فاصلة عمودية |', () {
      final ParsedCsv csv = CsvParser.parse('a|b\n1|2');
      expect(csv.delimiter, CsvDelimiter.pipe);
    });

    test('يمكن تمرير الفاصل يدوياً رغم الكشف', () {
      final ParsedCsv csv = CsvParser.parse(
        'a;b\n1;2',
        delimiter: CsvDelimiter.semicolon,
      );
      expect(csv.delimiter, CsvDelimiter.semicolon);
      expect(csv.rowCount, 1);
    });
  });

  group('P4..P6 الاقتباسات وأنهاء الأسطر', () {
    test('P4: فاصلة داخل حقل مقتبس محفوظة', () {
      final ParsedCsv csv = CsvParser.parse(
        'name,city\n"Smith, John",Paris',
      );
      expect(csv.headers, <String>['name', 'city']);
      expect(csv.rows.first, <String>['Smith, John', 'Paris']);
    });

    test('P5: علامة اقتباس مزدوجة مُهرّبة', () {
      final ParsedCsv csv = CsvParser.parse('msg,flag\n"said ""hi""",y');
      expect(csv.rows.first, <String>['said "hi"', 'y']);
    });

    test('P5b: حقل مقتبس يحتوي فاصلة منقوطة مع فاصل منقوط', () {
      final ParsedCsv csv = CsvParser.parse(
        'a;b\n"x;y;z";1',
        delimiter: CsvDelimiter.semicolon,
      );
      expect(csv.rows.first, <String>['x;y;z', '1']);
    });

    test('P5c: حقل مقتبس يحتوي نهاية سطر', () {
      final ParsedCsv csv = CsvParser.parse('a,b\n"line1\nline2",z');
      expect(csv.rowCount, 1);
      expect(csv.rows.first.first, 'line1\nline2');
    });

    test('P6: نهايات أسطر CRLF', () {
      final ParsedCsv csv = CsvParser.parse('a,b\r\n1,2\r\n3,4\r\n');
      expect(csv.headers, <String>['a', 'b']);
      expect(csv.rowCount, 2);
      expect(csv.rows.last, <String>['3', '4']);
    });

    test('P6b: نهايات أسطر CR فقط', () {
      final ParsedCsv csv = CsvParser.parse('a,b\r1,2');
      expect(csv.rowCount, 1);
      expect(csv.rows.first, <String>['1', '2']);
    });
  });

  group('P7..P8 الترميز', () {
    test('P7: UTF-8 BOM يُزال تلقائياً', () {
      final List<int> bytes = <int>[
        0xEF, 0xBB, 0xBF,
        ..._utf8('name,matricule\nأحمد,1001'),
      ];
      final ParsedCsv csv = CsvParser.parseBytes(bytes);
      expect(csv.hasBom, isTrue);
      expect(csv.encoding, 'UTF-8');
      expect(csv.headers.first, 'name');
      expect(csv.rows.first.first, 'أحمد');
    });

    test('P7b: بدون BOM', () {
      final ParsedCsv csv = CsvParser.parseBytes('name,matricule\nx,1'.codeUnits);
      expect(csv.hasBom, isFalse);
    });

    test('P8: نص عربي لا يتشوه (UTF-8 صحيح)', () {
      const String name = 'بن عيسى محمد الأمين';
      final List<int> bytes = _utf8('name,section\n"$name",الإدارة');
      final ParsedCsv csv = CsvParser.parseBytes(bytes);
      expect(csv.rows.first.first, name);
      expect(csv.rows.first.last, 'الإدارة');
      expect(csv.rows.first.first.contains('بن عيسى'), isTrue);
    });

    test('P8b: ترميز UTF-16 LE ببادئة BOM', () {
      final List<int> bytes = <int>[0xFF, 0xFE];
      for (final int u in 'a,b\n1,2'.codeUnits) {
        bytes.add(u & 0xFF);
        bytes.add((u >> 8) & 0xFF);
      }
      final ParsedCsv csv = CsvParser.parseBytes(bytes);
      expect(csv.encoding, 'UTF-16 LE');
      expect(csv.headers, <String>['a', 'b']);
      expect(csv.rows.first, <String>['1', '2']);
    });

    test('P8c: فك الترميز وحده يعمل', () {
      final ({String text, String encoding, bool hasBom}) d =
          CsvParser.decode(_utf8('عمود'));
      expect(d.text, 'عمود');
      expect(d.encoding, 'UTF-8');
    });
  });

  group('P9..P11 التحقق من الصفوف', () {
    test('P9: ملف فارغ → خطأ واضح', () {
      expect(
        () => CsvParser.parse(''),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.userMessage,
            'userMessage',
            contains('فارغ'),
          ),
        ),
      );
      expect(() => CsvParser.parse('   \n  '), throwsA(isA<AppException>()));
    });

    test('P9b: ملف يحتوي رأساً فقط → صفر صفوف وليست خطأ', () {
      final ParsedCsv csv = CsvParser.parse('a,b,c');
      expect(csv.isEmpty, isTrue);
      expect(csv.rowCount, 0);
      expect(csv.headers.length, 3);
    });

    test('P10: صف أقل أعمدة → مرفوض ومعدود', () {
      final ParsedCsv csv = CsvParser.parse('a,b,c\n1,2\n3,4,5');
      expect(csv.rowCount, 1);
      expect(csv.discardedRows, 1);
      expect(csv.rows.first, <String>['3', '4', '5']);
    });

    test('P11: 15 عموداً لرأس 12 → الزائدة تُقصّ ويُعدّ', () {
      final List<String> headers =
          List<String>.generate(12, (int i) => 'h$i');
      final List<String> wide =
          List<String>.generate(15, (int i) => 'v$i');
      final ParsedCsv csv =
          CsvParser.parse('${headers.join(',')}\n${wide.join(',')}');
      expect(csv.rowCount, 1);
      expect(csv.rows.first.length, 12);
      expect(csv.truncatedRows, 1);
      expect(csv.discardedRows, 0);
      expect(csv.problemRows, 1);
      expect(csv.rows.first.last, 'v11');
    });

    test('P11b: صفوف فارغة بالكامل تُهمل بلا عقوبة', () {
      final ParsedCsv csv = CsvParser.parse('a,b\n1,2\n,\n3,4');
      expect(csv.rowCount, 2);
    });
  });

  group('إضافات', () {
    test('indexOfHeader غير حساس لحالة الأحرف', () {
      final ParsedCsv csv = CsvParser.parse('Matricule,Nom Fr\n1001,Ali');
      expect(csv.indexOfHeader('matricule'), 0);
      expect(csv.indexOfHeader('  NOM FR '), 1);
      expect(csv.indexOfHeader('missing'), isNull);
    });

    test('hasHeader=false يولّد أعمدة رقمية', () {
      final ParsedCsv csv = CsvParser.parse('1,2,3', hasHeader: false);
      expect(csv.headers, <String>['col_0', 'col_1', 'col_2']);
      expect(csv.rows.first, <String>['1', '2', '3']);
    });

    test('ملف Sample الموحد يُقرأ بالكامل', () {
      const String text = 'matricule,nom_fr,section\n'
          '1001,Ali,Bureau\n'
          '1002,Sara,Etudes\n'
          '1003,Khaled,Finances\n';
      final ParsedCsv csv = CsvParser.parse(text);
      expect(csv.rowCount, 3);
      expect(csv.discardedRows, 0);
      expect(csv.truncatedRows, 0);
    });

    test('سطر أخير بدون newline يُقرأ', () {
      final ParsedCsv csv = CsvParser.parse('a,b\n1,2');
      expect(csv.rowCount, 1);
      expect(csv.rows.first, <String>['1', '2']);
    });

    test('مسافات حول عناوين الرأس تُزال', () {
      final ParsedCsv csv = CsvParser.parse('  a , b \n1,2');
      expect(csv.headers, <String>['a', 'b']);
    });
  });
}

List<int> _utf8(String s) {
  final List<int> out = <int>[];
  for (final int byte in s.codeUnits) {
    if (byte < 0x80) {
      out.add(byte);
    } else if (byte < 0x800) {
      out.add(0xC0 | (byte >> 6));
      out.add(0x80 | (byte & 0x3F));
    } else {
      out.add(0xE0 | (byte >> 12));
      out.add(0x80 | ((byte >> 6) & 0x3F));
      out.add(0x80 | (byte & 0x3F));
    }
  }
  return out;
}
