import 'package:admin_staff/core/error/app_exception.dart';
import 'package:admin_staff/services/csv_column_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات مطابقة رؤوس الأعمدة (قاعدة 53).
void main() {
  group('M1..M5 المطابقة التامة', () {
    test('M1: الرؤوس الرسمية الإنجليزية تُطابق كلها', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>[
          'nom_ar', 'prenom_ar', 'nom_fr', 'prenom_fr', 'matricule',
          'section', 'fonction', 'qualite', 'grade', 'ppr',
          'telephone_mobile', 'statut',
        ],
      );
      expect(m.columnFor('matricule'), 4);
      expect(m.columnFor('nom_ar'), 0);
      expect(m.columnFor('mobile_phone'), 10);
      expect(m.columnFor('status'), 11);
      expect(m.assignedCount, 12);
    });

    test('M2: حروف كبيرة/صغيرة ومسافات لا تؤثر', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['  MATRICULE ', 'Nom AR'],
      );
      expect(m.columnFor('matricule'), 0);
      expect(m.columnFor('nom_ar'), 1);
    });

    test('M3: أسماء بديلة عربية تُطابق', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['الرقم', 'الاسم', 'القسم', 'الهاتف'],
      );
      expect(m.columnFor('matricule'), 0);
      expect(m.columnFor('nom_ar'), 1);
      expect(m.columnFor('section'), 2);
      expect(m.columnFor('mobile_phone'), 3);
    });

    test('M4: أسماء بديلة فرنسية شائعة', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['Matricule', 'Service', 'Téléphone', 'Statut'],
      );
      expect(m.columnFor('matricule'), 0);
      expect(m.columnFor('section'), 1);
      expect(m.columnFor('mobile_phone'), 2);
      expect(m.columnFor('status'), 3);
    });

    test('M5: عمود مجهول لا يُسند لأي حقل', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['matricule', 'colon_introuvable'],
      );
      expect(m.columnFor('matricule'), 0);
      // لا يُمنح لأي حقل آخر.
      expect(
        m.fieldKeyToColumnIndex.values.where((int? v) => v == 1).isEmpty,
        isTrue,
      );
    });
  });

  group('M6..M9 المطابقة الجزئية والتعارض', () {
    test('M6: الرأس يحوي اسم الحقل', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['employee_matricule_id', 'full_name_ar'],
      );
      expect(m.columnFor('matricule'), 0);
      expect(m.columnFor('nom_ar'), 1);
    });

    test('M7: عمودان لا يحصلان على نفس الفهرس', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['matricule', 'matricule_bis'],
      );
      expect(m.columnFor('matricule'), 0);
      // العمود 1 لا يُسند لـ matricule مرة ثانية.
      expect(m.columnFor('ppr'), isNull);
    });

    test('M8: permutation صحيح — الترتيب ليس مفروضاً', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['statut', 'ppr', 'matricule'],
      );
      expect(m.columnFor('status'), 0);
      expect(m.columnFor('ppr'), 1);
      expect(m.columnFor('matricule'), 2);
    });

    test('M9: permanence — horaire و date', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.permanence,
        headers: <String>['date', 'permanencier', 'matricule', 'horaire'],
      );
      expect(m.columnFor('date'), 0);
      expect(m.columnFor('permanencier'), 1);
      expect(m.columnFor('matricule'), 2);
      expect(m.columnFor('horaire'), 3);
    });
  });

  group('M10..M13 الخريطة المحفوظة', () {
    test('M10: خريطة محفوظة صالحة تُستعمل', () {
      final ColumnMapping saved = ColumnMapping(<String, int?>{
        'matricule': 5,
        'nom_ar': 0,
      });
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['a', 'b', 'c', 'd', 'e', 'f'],
        savedMapping: saved,
      );
      expect(m.columnFor('matricule'), 5);
    });

    test('M11: خريطة محفوظة تتجاوز عرض الملف تُرفض وتُعاد', () {
      final ColumnMapping saved = ColumnMapping(<String, int?>{
        'matricule': 99,
      });
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['matricule', 'nom_ar'],
        savedMapping: saved,
      );
      expect(m.columnFor('matricule'), 0);
    });

    test('M12: round-trip JSON', () {
      final ColumnMapping m = ColumnMapping(<String, int?>{
        'matricule': 3,
        'nom_ar': null,
      });
      final ColumnMapping back = ColumnMapping.fromJson(m.toJson());
      expect(back.columnFor('matricule'), 3);
      expect(back.columnFor('nom_ar'), isNull);
      expect(back.assignedCount, 1);
    });

    test('M13: empty() لا يخصص أي حقل', () {
      final ColumnMapping m = CsvColumnMapper.empty(ImportKind.employees);
      expect(m.assignedCount, 0);
      expect(m.fieldKeyToColumnIndex.containsKey('matricule'), isTrue);
    });
  });

  group('M14..M18 التحقق الإلزامي', () {
    test('M14: matricule غير مخصّص → AppException برسالة واضحة', () {
      final ColumnMapping m = CsvColumnMapper.empty(ImportKind.employees);
      expect(
        () => CsvColumnMapper.validate(
          kind: ImportKind.employees,
          mapping: m,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.userMessage,
            'message',
            allOf(contains('Matricule'), contains('Column Mapping')),
          ),
        ),
      );
    });

    test('M15: الخريطة الكاملة تمر', () {
      final ColumnMapping m = CsvColumnMapper.autoMap(
        kind: ImportKind.employees,
        headers: <String>['matricule', 'nom_ar'],
      );
      expect(
        () => CsvColumnMapper.validate(
          kind: ImportKind.employees,
          mapping: m,
        ),
        returnsNormally,
      );
    });

    test('M16: date إلزامي في permanence', () {
      final ColumnMapping m = ColumnMapping(<String, int?>{
        'matricule': 0,
        'date': null,
      });
      expect(
        () => CsvColumnMapper.validate(
          kind: ImportKind.permanence,
          mapping: m,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.userMessage,
            'message',
            contains('Date'),
          ),
        ),
      );
    });

    test('M17: missingRequired يعدد كل الناقص', () {
      final ColumnMapping m = CsvColumnMapper.empty(ImportKind.permanence);
      expect(
        m.missingRequired(CsvColumnMapper.requiredKeysFor(ImportKind.permanence)),
        <String>['date', 'matricule'],
      );
    });

    test('M18: isAssigned', () {
      final ColumnMapping m = ColumnMapping(<String, int?>{'date': 2});
      expect(m.isAssigned('date'), isTrue);
      expect(m.isAssigned('matricule'), isFalse);
    });
  });

  group('M19..M21 قراءة الصفوف', () {
    const ColumnMapping m = ColumnMapping(<String, int?>{
      'matricule': 0,
      'nom_ar': 1,
      'mobile_phone': 2,
    });

    test('M19: قراءة عادية + تجاهل الفراغ', () {
      expect(m.read('matricule', <String>['12547', 'x', '']), '12547');
      expect(m.read('mobile_phone', <String>['1', '2', '   ']), isNull);
    });

    test('M20: فهرس خارج حدود الصف → null لا استثناء', () {
      expect(m.read('nom_ar', <String>['only']), isNull);
      expect(m.read('missing_key', <String>['a', 'b']), isNull);
    });

    test('M21: readRaw يحتفظ بالمسافات الداخلية', () {
      expect(
        m.readRaw('nom_ar', <String>['1', '  بن عيسى  ', '']),
        '  بن عيسى  ',
      );
      expect(m.readRaw('nom_ar', <String>['1', '   ', '']), isNull);
    });
  });
}
