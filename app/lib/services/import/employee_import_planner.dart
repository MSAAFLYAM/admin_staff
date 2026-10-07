import '../../core/constants/db_constants.dart';
import '../../core/utils/app_date.dart';
import '../../core/utils/csv/csv_parser.dart';
import '../../models/employee.dart';
import '../../services/csv_column_mapper.dart';
import '../../services/import/import_models.dart';

/// واجهة البحث التي يحتاجها المخطِّط — قابلة للاستبدال في الاختبارات.
///
/// التنفيذ الحقيقي يبنيها من SQL؛ الاختبارات تبنيها من خرائط في الذاكرة.
abstract interface class ImportLookup {
  /// معرّف موظف موجود بـ `matricule` (مطابقة تامة) أو `null`.
  int? findByMatricule(String matricule);

  /// معرّف موظف موجود بـ `ppr` غير فارغ أو `null`.
  int? findByPpr(String ppr);

  /// معرّف مدخل مرجعي موجود بالاسم أو `null`.
  int? findReference(String table, String name);

  /// معرّف موظف بـ matricule لربط المداومة (قد يكون null).
  int? employeeIdFor(String matricule);

  /// مفتاح مداومة موجود مسبقاً `(date|employeeId|timeSlot)`؟
  bool permanenceKeyExists(String date, int employeeId, String timeSlot);

  /// هل يوجد سجل مداومة لنفس الفترة يمسحها وضع `replace`؟
  bool hasPermanenceInRange(String from, String to);
}

/// بديل مبني على خرائط — يُستخدم في الاختبارات والمعاينة السريعة.
class MapLookup implements ImportLookup {
  MapLookup({
    this.matricules = const <String, int>{},
    this.pprs = const <String, int>{},
    this.references = const <String, Map<String, int>>{},
    this.permanenceKeys = const <String>{},
    this.rangeKeys = const <String>{},
  });

  /// `matricule` → `employee.id`.
  final Map<String, int> matricules;

  /// `ppr` → `employee.id`.
  final Map<String, int> pprs;

  /// `table` → (`اسم` → `id`).
  final Map<String, Map<String, int>> references;

  /// مفاتيح `date|employeeId|timeSlot` القائمة مسبقاً.
  final Set<String> permanenceKeys;

  /// مفاتيح `yyyy-MM-dd` المطلوبة في نطاق الاستبدال.
  final Set<String> rangeKeys;

  @override
  int? findByMatricule(String matricule) => matricules[matricule];

  @override
  int? findByPpr(String ppr) => ppr.isEmpty ? null : pprs[ppr];

  @override
  int? findReference(String table, String name) =>
      references[table]?[name.trim()];

  @override
  int? employeeIdFor(String matricule) => matricules[matricule];

  @override
  bool permanenceKeyExists(String date, int employeeId, String timeSlot) =>
      permanenceKeys.contains('$date|$employeeId|$timeSlot');

  @override
  bool hasPermanenceInRange(String from, String to) => rangeKeys.isNotEmpty;
}

/// ★ مخطِّط استيراد الموظفين (قواعد 81..84).
///
/// **نقي تماماً** — لا يلمس قاعدة البيانات. يقرأ [ParsedCsv]
/// ويعيد قائمة [PlannedRow] تُعرض في شاشة المعاينة قبل التأكيد.
///
/// قواعد التكرار (§4.3):
///  1. `matricule` مطابق ← تحديث.
///  2. ثم `ppr` مطابق وغير فارغ ← تحديث.
///  3. لا يوجد ← جديد.
abstract final class EmployeeImportPlanner {
  /// يخطّط كل الصفوف.
  ///
  /// [lineOffset] = 1 لأن الصف الأول هو الرأس.
  static List<PlannedRow> plan({
    required ParsedCsv parsed,
    required ColumnMapping mapping,
    required ImportLookup lookup,
    int lineOffset = 1,
  }) {
    final List<PlannedRow> out = <PlannedRow>[];

    // تتبّع matricule داخل الملف لاكتشاف التكرار (§4.2).
    final Map<String, int> seenMatricules = <String, int>{};
    final Map<String, int> seenPprs = <String, int>{};

    for (int i = 0; i < parsed.rows.length; i++) {
      final List<String> row = parsed.rows[i];
      final int line = i + 1 + lineOffset;

      // صف خالٍ تماماً → مُهمل (لا يُعدّ خطأ).
      if (row.every((String c) => c.trim().isEmpty)) {
        out.add(PlannedRow(lineNumber: line, action: RowAction.empty, raw: row));
        continue;
      }

      final String matricule = _cell(mapping, row, 'matricule');
      final String ppr = _cell(mapping, row, 'ppr');
      final String nomAr = _cell(mapping, row, 'nom_ar');
      final String prenomAr = _cell(mapping, row, 'prenom_ar');
      final String nomFr = _cell(mapping, row, 'nom_fr');
      final String prenomFr = _cell(mapping, row, 'prenom_fr');

      // ── قواعد الرفض (§4.2) ──
      if (matricule.isEmpty) {
        out.add(_reject(
          line,
          row,
          'حقل Matricule إلزامي ولا يمكن أن يكون فارغاً',
        ));
        continue;
      }

      final int? firstLineOfDuplicate = seenMatricules[matricule];
      if (firstLineOfDuplicate != null) {
        out.add(_reject(
          line,
          row,
          'Matricule مكرر في الملف (موجود في الصف $firstLineOfDuplicate)',
        ));
        continue;
      }
      seenMatricules[matricule] = line;

      if (nomAr.isEmpty &&
          prenomAr.isEmpty &&
          nomFr.isEmpty &&
          prenomFr.isEmpty) {
        out.add(_reject(
          line,
          row,
          'يجب إدخال الاسم بالعربية أو الفرنسية',
        ));
        continue;
      }

      final List<String> warnings = <String>[];
      if (ppr.isNotEmpty && !_isMostlyNumeric(ppr)) {
        warnings.add('PPR "$ppr" غير رقمي — يُخزَّن كنص');
      }

      // ── تكرار داخل الملف بالنسبة لـ PPR ──
      if (ppr.isNotEmpty && seenPprs.containsKey(ppr)) {
        out.add(_reject(
          line,
          row,
          'PPR مكرر في الملف (موجود في الصف ${seenPprs[ppr]})',
          warnings: warnings,
        ));
        continue;
      }
      if (ppr.isNotEmpty) seenPprs[ppr] = line;

      // ── كشف التكرار مع القاعدة (§4.3) ──
      final int? byMatricule = lookup.findByMatricule(matricule);
      final int? byPpr = ppr.isEmpty ? null : lookup.findByPpr(ppr);
      final int? existingId = byMatricule ?? byPpr;

      final Employee employee = Employee(
        id: existingId,
        matricule: matricule,
        nomAr: _nullIfEmpty(nomAr),
        prenomAr: _nullIfEmpty(prenomAr),
        nomFr: _nullIfEmpty(nomFr),
        prenomFr: _nullIfEmpty(prenomFr),
        quality: _nullIfEmpty(_cell(mapping, row, 'qualite')),
        ppr: _nullIfEmpty(ppr),
        mobilePhone: _nullIfEmpty(_cell(mapping, row, 'mobile_phone')),
        notes: _nullIfEmpty(_cell(mapping, row, 'notes')),
        sectionId: _ref(mapping, row, 'section', lookup, Db.sections),
        gradeId: _ref(mapping, row, 'grade', lookup, Db.grades),
        functionId: _ref(mapping, row, 'fonction', lookup, Db.functions),
        currentStatusId:
            _ref(mapping, row, 'status', lookup, Db.statusTypes),
        createdAt: null,
        updatedAt: null,
      );

      // أسماء مرجعية غير موجودة → تُنشأ داخل الـ Transaction.
      final String sectionName = _cell(mapping, row, 'section');
      final String gradeName = _cell(mapping, row, 'grade');
      final String functionName = _cell(mapping, row, 'fonction');
      final String statusName = _cell(mapping, row, 'status');

      final bool needsSection = sectionName.isNotEmpty &&
          employee.sectionId == null;
      final bool needsGrade =
          gradeName.isNotEmpty && employee.gradeId == null;
      final bool needsFunction =
          functionName.isNotEmpty && employee.functionId == null;
      final bool needsStatus =
              statusName.isNotEmpty && employee.currentStatusId == null;

      out.add(
        PlannedRow(
          lineNumber: line,
          action: existingId == null ? RowAction.insert : RowAction.update,
          employee: employee,
          existingId: existingId,
          pendingSection: needsSection ? sectionName : null,
          pendingGrade: needsGrade ? gradeName : null,
          pendingFunction: needsFunction ? functionName : null,
          pendingStatus: needsStatus ? statusName : null,
          warnings: warnings,
          raw: row,
        ),
      );
    }

    return out;
  }

  // ── مساعدات ──────────────────────────────────────────────────

  static String _cell(ColumnMapping m, List<String> row, String key) {
    final int? idx = m.columnFor(key);
    if (idx == null || idx >= row.length) return '';
    return row[idx].trim();
  }

  static String? _nullIfEmpty(String v) =>
      v.trim().isEmpty ? null : v.trim();

  static int? _ref(
    ColumnMapping m,
    List<String> row,
    String key,
    ImportLookup lookup,
    String table,
  ) {
    final String name = _cell(m, row, key);
    if (name.isEmpty) return null;
    return lookup.findReference(table, name);
  }

  static PlannedRow _reject(
    int line,
    List<String> row,
    String message, {
    List<String> warnings = const <String>[],
  }) =>
      PlannedRow(
        lineNumber: line,
        action: RowAction.error,
        errorMessage: message,
        warnings: warnings,
        raw: row,
      );

  /// هل القيمة "معظماً" رقمية؟ (PPR عادة أرقام مع `/` أو `-`).
  static bool _isMostlyNumeric(String v) {
    final String s = v.replaceAll(RegExp(r'[\s/\-_.]'), '');
    if (s.isEmpty) return false;
    final int digits = s.replaceAll(RegExp(r'[^0-9]'), '').length;
    return digits >= s.length * 0.7;
  }

  /// يكتشف تنسيق التاريخ من أول خلية `date` صالحة (للعرض فقط).
  static String? detectDateFormat(ParsedCsv parsed, ColumnMapping mapping) {
    final int? idx = mapping.columnFor('date');
    if (idx == null) return null;
    for (final List<String> row in parsed.rows) {
      if (idx >= row.length) continue;
      final String raw = row[idx].trim();
      if (raw.isEmpty) continue;
      if (AppDate.tryParse(raw) == null) continue;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return 'YYYY-MM-DD';
      if (RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(raw)) return 'YYYY/MM/DD';
      if (RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(raw)) return 'DD.MM.YYYY';
      if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(raw)) return 'DD-MM-YYYY';
      if (RegExp(r'^\d{1,2}/\d{1,2}/\d{2}$').hasMatch(raw)) return 'DD/MM/YY';
      if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(raw)) return 'DD/MM/YYYY';
      return 'DD/MM/YYYY';
    }
    return null;
  }
}
