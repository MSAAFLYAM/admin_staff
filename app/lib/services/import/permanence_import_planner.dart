import '../../core/utils/app_date.dart';
import '../../core/utils/csv/csv_parser.dart';
import '../../models/permanence_record.dart';
import '../../services/csv_column_mapper.dart';
import '../../services/import/import_models.dart';
import 'employee_import_planner.dart';

/// ★ مخطِّط استيراد المداومة (قواعد 22 و23 و42).
///
/// **نقي تماماً** — لا يلمس قاعدة البيانات.
///
/// القواعد:
///  - `date` و`matricule` إلزاميان.
///  - الربط بـ `matricule` فقط؛ غير المربوط يدخل *Unmatched*
///    ولا يُنشأ موظف تلقائياً أبداً.
///  - المفتاح `(date, employee_id, time_slot)` → التكرار يُتخطّى.
abstract final class PermanenceImportPlanner {
  static List<PlannedRow> plan({
    required ParsedCsv parsed,
    required ColumnMapping mapping,
    required ImportLookup lookup,
    required String sourceFile,
    ImportMode mode = ImportMode.addNew,
    int lineOffset = 1,
  }) {
    final List<PlannedRow> out = <PlannedRow>[];

    // تتبّع المفاتيح داخل الملف نفسه (التكرار المزدوج يُرفض).
    final Set<String> seenInFile = <String>{};

    for (int i = 0; i < parsed.rows.length; i++) {
      final List<String> row = parsed.rows[i];
      final int line = i + 1 + lineOffset;

      if (row.every((String c) => c.trim().isEmpty)) {
        out.add(PlannedRow(lineNumber: line, action: RowAction.empty, raw: row));
        continue;
      }

      final String rawDate = _cell(mapping, row, 'date');
      final String matricule = _cell(mapping, row, 'matricule');

      if (rawDate.isEmpty) {
        out.add(_reject(line, row, 'حقل Date إلزامي ولا يمكن أن يكون فارغاً'));
        continue;
      }

      final DateTime? parsedDate = AppDate.tryParse(rawDate);
      if (parsedDate == null) {
        out.add(_reject(line, row, 'تنسيق تاريخ غير معروف: "$rawDate"'));
        continue;
      }
      final String date = AppDate.format(parsedDate);

      if (matricule.isEmpty) {
        out.add(_reject(line, row, 'حقل Matricule إلزامي ولا يمكن أن يكون فارغاً'));
        continue;
      }

      // ── horaire → start/end/time_slot ──
      final String horaire = _cell(mapping, row, 'horaire');
      final (String?, String?) times = AppDate.parseSchedule(horaire);
      final String? start = times.$1;
      final String? end = times.$2;
      final String timeSlot = start ?? '';

      if (horaire.isNotEmpty && start == null) {
        out.add(_reject(
          line,
          row,
          'تنسيق التوقيت غير معروف: "$horaire"',
        ));
        continue;
      }

      // ── الربط (قاعدة 22) ──
      final int? employeeId = lookup.employeeIdFor(matricule);

      // ── منع التكرار داخل الملف (قاعدة 23) ──
      final String fileKey = '$date|$matricule|$timeSlot';
      if (!seenInFile.add(fileKey)) {
        out.add(_reject(
          line,
          row,
          'مداومة مكررة في الملف (نفس التاريخ والموظف والفترة)',
        ));
        continue;
      }

      // ── التكرار مع القاعدة ──
      if (employeeId != null &&
          lookup.permanenceKeyExists(date, employeeId, timeSlot)) {
        if (mode == ImportMode.addNew) {
          out.add(
            PlannedRow(
              lineNumber: line,
              action: RowAction.duplicateExisting,
              existingId: null,
              unmatchedMatricule: null,
              raw: row,
            ),
          );
          continue;
        }
      }

      final PermanenceRecord record = PermanenceRecord(
        date: date,
        employeeId: employeeId,
        matricule: matricule,
        permanencier: _nullIfEmpty(_cell(mapping, row, 'permanencier')),
        section: _nullIfEmpty(_cell(mapping, row, 'section')),
        grade: _nullIfEmpty(_cell(mapping, row, 'grade')),
        hpad: _nullIfEmpty(_cell(mapping, row, 'hpad')),
        mobilePhone: _nullIfEmpty(_cell(mapping, row, 'mobile_phone')),
        startTime: start,
        endTime: end,
        timeSlot: timeSlot,
        scheduleText: _nullIfEmpty(horaire),
        sourceFile: _nullIfEmpty(sourceFile),
      );

      out.add(
        PlannedRow(
          lineNumber: line,
          action: RowAction.insert,
          permanence: record,
          unmatchedMatricule: employeeId == null ? matricule : null,
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

  static PlannedRow _reject(int line, List<String> row, String message) =>
      PlannedRow(
        lineNumber: line,
        action: RowAction.error,
        errorMessage: message,
        raw: row,
      );
}
