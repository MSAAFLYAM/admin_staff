import 'package:admin_staff/core/utils/csv/csv_parser.dart';
import 'package:admin_staff/models/permanence_record.dart';
import 'package:admin_staff/services/csv_column_mapper.dart';
import 'package:admin_staff/services/import/employee_import_planner.dart';
import 'package:admin_staff/services/import/import_models.dart';
import 'package:admin_staff/services/import/permanence_import_planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات مخطِّطي الاستيراد — قواعد D1..D6 و22 و23.
void main() {
  MapLookup emptyLookup() => MapLookup();

  ColumnMapping mapFor(List<String> headers) => CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: headers,
      );

  const List<String> empHeaders = <String>[
    'matricule',
    'nom_ar',
    'prenom_ar',
    'nom_fr',
    'prenom_fr',
    'ppr',
    'section',
    'grade',
    'statut',
  ];

  String csv(List<List<String>> dataRows) =>
      '${empHeaders.join(',')}\n'
      '${dataRows.map((List<String> r) => r.join(',')).join('\n')}';

  List<String> row({
    required String matricule,
    String nomAr = '',
    String prenomAr = '',
    String nomFr = '',
    String prenomFr = '',
    String ppr = '',
    String section = '',
    String grade = '',
    String statut = '',
  }) =>
      <String>[
        matricule,
        nomAr,
        prenomAr,
        nomFr,
        prenomFr,
        ppr,
        section,
        grade,
        statut,
      ];

  // ── D1..D6: كشف التكرار ─────────────────────────────────────
  group('D1..D6 كشف التكرار', () {
    test('D1: matricule جديد → Insert', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomAr: 'بن عيسى', prenomAr: 'أحمد'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.action, RowAction.insert);
      expect(rows.single.employee?.matricule, '1001');
      expect(rows.single.existingId, isNull);
    });

    test('D2: matricule موجود → Update', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomFr: 'BEN AISSA', prenomFr: 'Ahmed'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: MapLookup(
          matricules: <String, int>{'1001': 42},
        ),
      );
      expect(rows.single.action, RowAction.update);
      expect(rows.single.existingId, 42);
      expect(rows.single.employee?.id, 42);
    });

    test('D3: matricule جديد + ppr موجود → Update عبر ppr', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '9999', ppr: 'PPR-77', nomFr: 'SARA'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: MapLookup(pprs: <String, int>{'PPR-77': 7}),
      );
      expect(rows.single.action, RowAction.update);
      expect(rows.single.existingId, 7);
    });

    test('D4: matricule مكرر داخل الملف → الصف الثاني مرفوض', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomFr: 'ONE'),
          row(matricule: '1001', nomFr: 'TWO'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows[0].action, RowAction.insert);
      expect(rows[1].action, RowAction.error);
      expect(rows[1].errorMessage, contains('مكرر في الملف'));
      expect(rows[1].errorMessage, contains('الصف 2'));
    });

    test('D5: ppr فارغ + matricule جديد → Insert', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomFr: 'ALI'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.action, RowAction.insert);
      expect(rows.single.employee?.ppr, isNull);
    });

    test('D6: ملف مختلط → الأرقام مطابقة (210جديد + 35تحديث + 5مكرر)', () {
      final List<List<String>> data = <List<String>>[];

      // 210 جديد.
      for (int i = 0; i < 210; i++) {
        data.add(row(matricule: 'N$i', nomFr: 'N$i'));
      }
      // 35 تحديث (موجودة مسبقاً).
      for (int i = 0; i < 35; i++) {
        data.add(row(matricule: 'E$i', nomFr: 'E$i'));
      }
      // 5 مكرر داخل الملف.
      for (int i = 0; i < 5; i++) {
        data.add(row(matricule: 'N$i', nomFr: 'DUP$i'));
      }

      final ParsedCsv parsed = CsvParser.parse(csv(data));
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: MapLookup(
          matricules: <String, int>{
            for (int i = 0; i < 35; i++) 'E$i': i + 1,
          },
        ),
      );

      int insert = 0;
      int update = 0;
      int error = 0;
      for (final PlannedRow r in rows) {
        switch (r.action) {
          case RowAction.insert:
            insert++;
          case RowAction.update:
            update++;
          case RowAction.error:
            error++;
          default:
            break;
        }
      }
      expect(insert, 210);
      expect(update, 35);
      expect(error, 5);
      expect(rows.length, 250);
    });
  });

  // ── قواعد الرفض (§4.2) ──────────────────────────────────────
  group('قواعد الرفض', () {
    test('matricule فارغ → رفض برسالة واضحة', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[row(matricule: '', nomFr: 'ALI')]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.action, RowAction.error);
      expect(rows.single.errorMessage, contains('Matricule إلزامي'));
    });

    test('كلا الاسمين فارغ → رفض', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[row(matricule: '1001')]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.action, RowAction.error);
      expect(rows.single.errorMessage, contains('العربية أو الفرنسية'));
    });

    test('اسم عربي فقط كافٍ → مقبول', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[row(matricule: '1001', nomAr: 'بن عيسى')]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.action, RowAction.insert);
    });

    test('صف فارغ تماماً → مُهمل لا مرفوض', () {
      const String text = 'matricule,nom_ar,prenom_ar,nom_fr,prenom_fr,'
          'ppr,section,grade,statut\n'
          ',,,,,,,,\n'
          '1001,بن عيسى,أحمد,,,,,,';

      // المحلّل يسقط الصفوف الفارغة قبل المخطِّط.
      final ParsedCsv parsed = CsvParser.parse(text);
      expect(parsed.rowCount, 1);

      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.action, RowAction.insert);

      // والمخطِّط أيضاً يتعامل مع الصف الفارغ لو وصله.
      const ParsedCsv withBlank = ParsedCsv(
        headers: <String>['matricule', 'nom_fr'],
        rows: <List<String>>[
          <String>['  ', ''],
          <String>['1001', 'ALI'],
        ],
        delimiter: CsvDelimiter.comma,
        encoding: 'UTF-8',
      );
      final List<PlannedRow> planned = EmployeeImportPlanner.plan(
        parsed: withBlank,
        mapping: const ColumnMapping(<String, int?>{
          'matricule': 0,
          'nom_fr': 1,
        }),
        lookup: emptyLookup(),
      );
      expect(planned[0].action, RowAction.empty);
      expect(planned[1].action, RowAction.insert);
    });

    test('PPR غير رقمي → تحذير لا رفض', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomFr: 'ALI', ppr: 'ABC/12'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.action, RowAction.insert);
      expect(rows.single.warnings, isNotEmpty);
      expect(rows.single.warnings.single, contains('PPR'));
    });

    test('PPR رقمي → بلا تحذير', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomFr: 'ALI', ppr: '12/2024'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.warnings, isEmpty);
    });

    test('المرجع غير موجود → pendingSection مسجّل للإنشاء', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomFr: 'ALI', section: 'الموارد البشرية'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.pendingSection, 'الموارد البشرية');
      expect(rows.single.employee?.sectionId, isNull);
    });

    test('المرجع موجود → مربوط ولا يُنشأ', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomFr: 'ALI', section: 'RH'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: MapLookup(
          references: <String, Map<String, int>>{
            'sections': <String, int>{'RH': 3},
          },
        ),
      );
      expect(rows.single.employee?.sectionId, 3);
      expect(rows.single.pendingSection, isNull);
    });

    test('أرقام الصفوف تبدأ من 2 (1 = الرأس)', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: 'A', nomFr: 'A'),
          row(matricule: 'B', nomFr: 'B'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows[0].lineNumber, 2);
      expect(rows[1].lineNumber, 3);
    });

    test('الخلايا الفارغة تُخزَّن null وليست ""', () {
      final ParsedCsv parsed = CsvParser.parse(
        csv(<List<String>>[
          row(matricule: '1001', nomFr: 'ALI'),
        ]),
      );
      final List<PlannedRow> rows = EmployeeImportPlanner.plan(
        parsed: parsed,
        mapping: mapFor(parsed.headers),
        lookup: emptyLookup(),
      );
      expect(rows.single.employee?.ppr, isNull);
      expect(rows.single.employee?.mobilePhone, isNull);
      expect(rows.single.employee?.nomAr, isNull);
    });
  });

  // ── استيراد المداومة (قواعد 22 و23) ────────────────────────
  group('مداومة: الربط والتكرار', () {
    const List<String> permHeaders = <String>[
      'date',
      'permanencier',
      'matricule',
      'section',
      'grade',
      'hpad',
      'telephone_mobile',
      'horaire',
    ];

    String permCsv(List<List<String>> rows) =>
        '${permHeaders.join(',')}\n'
        '${rows.map((List<String> r) => r.join(',')).join('\n')}';

    List<String> permRow({
      required String date,
      required String matricule,
      String name = '',
      String horaire = '',
    }) =>
        <String>[date, name, matricule, 'RH', 'Principal', 'H-01', '', horaire];

    ColumnMapping permMap(List<String> headers) => CsvColumnMapper.autoMap(
          kind: ImportKind.permanence,
          headers: headers,
        );

    test('P-I1: matricule مربوط → employeeId مضبوط', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(date: '2026-10-05', matricule: '12547', name: 'بن عيسى'),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(matricules: <String, int>{'12547': 9}),
        sourceFile: 'test.csv',
      );
      expect(rows.single.action, RowAction.insert);
      expect(rows.single.permanence?.employeeId, 9);
      expect(rows.single.unmatchedMatricule, isNull);
    });

    test('P-I2: matricule غير موجود → Unmatched ولا يُنشأ موظف', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(date: '2026-10-05', matricule: '99999'),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(),
        sourceFile: 'test.csv',
      );
      expect(rows.single.unmatchedMatricule, '99999');
      expect(rows.single.permanence?.employeeId, isNull);
      expect(rows.single.action, RowAction.insert);
    });

    test('P-I3: نفس التاريخ + الموظف + الفترة → مكرر موجود', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(
            date: '2026-10-05',
            matricule: '12547',
            horaire: '08:00 - 16:00',
          ),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(
          matricules: <String, int>{'12547': 9},
          permanenceKeys: <String>{'2026-10-05|9|08:00'},
        ),
        sourceFile: 'test.csv',
        mode: ImportMode.addNew,
      );
      expect(rows.single.action, RowAction.duplicateExisting);
    });

    test('P-I4: نفس اليوم وفترة مختلفة → مقبول', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(
            date: '2026-10-05',
            matricule: '12547',
            horaire: '16:00 - 00:00',
          ),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(
          matricules: <String, int>{'12547': 9},
          permanenceKeys: <String>{'2026-10-05|9|08:00'},
        ),
        sourceFile: 'test.csv',
      );
      expect(rows.single.action, RowAction.insert);
      expect(rows.single.permanence?.startTime, '16:00');
    });

    test('P-I5: تاريخ غير صالح → رفض برسالة', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(date: '32/13/2026', matricule: '12547'),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(),
        sourceFile: 'test.csv',
      );
      expect(rows.single.action, RowAction.error);
      expect(rows.single.errorMessage, contains('تنسيق تاريخ غير معروف'));
    });

    test('P-I6: date فارغ → رفض', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(date: '', matricule: '12547'),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(),
        sourceFile: 't.csv',
      );
      expect(rows.single.action, RowAction.error);
      expect(rows.single.errorMessage, contains('Date إلزامي'));
    });

    test('P-I7: تكرار داخل الملف يُرفض في الصف الثاني', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(date: '2026-10-05', matricule: '12547'),
          permRow(date: '2026-10-05', matricule: '12547'),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(matricules: <String, int>{'12547': 9}),
        sourceFile: 't.csv',
      );
      expect(rows[0].action, RowAction.insert);
      expect(rows[1].action, RowAction.error);
      expect(rows[1].errorMessage, contains('مكررة في الملف'));
    });

    test('P-I8: horaire يُفكَّك إلى start/end/timeSlot', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(
            date: '05/10/2026',
            matricule: '12547',
            horaire: '08:00 - 16:00',
          ),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(matricules: <String, int>{'12547': 9}),
        sourceFile: 't.csv',
      );
      final PermanenceRecord p = rows.single.permanence!;
      expect(p.date, '2026-10-05');
      expect(p.startTime, '08:00');
      expect(p.endTime, '16:00');
      expect(p.timeSlot, '08:00');
      expect(p.sourceFile, 't.csv');
    });

    test('P-I9: horaire فارغ → بلا توقيت ومفتاح فارغ', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(date: '2026-10-05', matricule: '12547'),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(matricules: <String, int>{'12547': 9}),
        sourceFile: 't.csv',
      );
      final PermanenceRecord p = rows.single.permanence!;
      expect(p.startTime, isNull);
      expect(p.timeSlot, '');
    });

    test('P-I10: horaire بتنسيق خاطئ → رفض', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(date: '2026-10-05', matricule: '12547', horaire: 'غداً'),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(),
        sourceFile: 't.csv',
      );
      expect(rows.single.action, RowAction.error);
      expect(rows.single.errorMessage, contains('تنسيق التوقيت'));
    });

    test('P-I11: تاريخ بصيغة DD/MM/YYYY يُوحَّد إلى ISO', () {
      final ParsedCsv parsed = CsvParser.parse(
        permCsv(<List<String>>[
          permRow(date: '05/10/2026', matricule: '12547'),
        ]),
      );
      final List<PlannedRow> rows = PermanenceImportPlanner.plan(
        parsed: parsed,
        mapping: permMap(parsed.headers),
        lookup: MapLookup(),
        sourceFile: 't.csv',
      );
      expect(rows.single.permanence?.date, '2026-10-05');
    });
  });
}
