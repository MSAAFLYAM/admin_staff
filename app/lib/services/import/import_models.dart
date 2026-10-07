import '../../core/utils/csv/csv_parser.dart';
import '../../models/employee.dart';
import '../../models/permanence_record.dart';

/// سياسة استيراد المداومة (قاعدة 42 — تُعرض قبل التنفيذ دائماً).
enum ImportMode {
  /// إضافة السجلات الجديدة فقط — لا يمسّ الموجود (الافتراضي).
  addNew('add_new'),

  /// تحديث السجلات الموجودة لنفس الفترة.
  updateExisting('update_existing'),

  /// استبدال فترة مؤكَّدة (يتطلب تأكيداً صريحاً).
  replaceRange('replace_range');

  const ImportMode(this.id);
  final String id;

  static ImportMode fromId(String? id) =>
      ImportMode.values.firstWhere(
        (ImportMode m) => m.id == id,
        orElse: () => ImportMode.addNew,
      );
}

/// حالة الصف بعد التحقق.
enum RowAction {
  /// صف جديد → INSERT.
  insert,

  /// موجود → UPDATE (التاريخ السابق لا يُمسّ).
  update,

  /// مكرر داخل الملف → يُتخطّى ويُعدّ.
  duplicateInFile,

  /// مطابق موجود مسبقاً → يُتخطّى (لأنه بلا تغيير).
  duplicateExisting,

  /// غير صالح → يُرفض مع سبب واضح.
  error,

  /// صف فارغ تماماً → يُهمل بلا عقوبة.
  empty,
}

/// صف واحد بعد التخطيط — يحمل كل ما يحتاجه التنفيذ.
class PlannedRow {
  const PlannedRow({
    required this.lineNumber,
    required this.action,
    this.errorMessage,
    this.employee,
    this.existingId,
    this.permanence,
    this.unmatchedMatricule,
    this.pendingSection,
    this.pendingGrade,
    this.pendingFunction,
    this.pendingStatus,
    this.warnings = const <String>[],
    this.raw = const <String>[],
  });

  /// رقم الصف **في الملف** (1 = الرأس). يظهر للمستخدم في شاشة الرفض.
  final int lineNumber;
  final RowAction action;
  final String? errorMessage;

  /// بيانات الموظف للإدراج/التحديث (استيراد الموظفين).
  final Employee? employee;

  /// معرّف السجل الموجود إن كان التحديث/التخطي.
  final int? existingId;

  /// سجل المداومة (استيراد المداومة).
  final PermanenceRecord? permanence;

  /// matriculeغير موجود في قاعدة الموظفين (استيراد المداومة).
  final String? unmatchedMatricule;

  /// أسماء مرجعية غير موجودة — تُنشأ داخل الـ Transaction ثم تُربط.
  /// (`null` = لا شيء يُنشأ.)
  final String? pendingSection;
  final String? pendingGrade;
  final String? pendingFunction;
  final String? pendingStatus;

  /// تحذيرات لا تمنع الاستيراد (مثل PPR غير رقمي).
  final List<String> warnings;

  final List<String> raw;

  bool get isRejected => action == RowAction.error;
  bool get willWrite =>
      action == RowAction.insert || action == RowAction.update;

  PlannedRow copyWith({
    RowAction? action,
    String? errorMessage,
    Employee? employee,
    int? existingId,
    PermanenceRecord? permanence,
    String? unmatchedMatricule,
    int? setSectionId,
    int? setGradeId,
    int? setFunctionId,
    int? setStatusId,
    List<String>? warnings,
  }) =>
      PlannedRow(
        lineNumber: lineNumber,
        action: action ?? this.action,
        errorMessage: errorMessage ?? this.errorMessage,
        employee: employee ?? this.employee,
        existingId: existingId ?? this.existingId,
        permanence: permanence ?? this.permanence,
        unmatchedMatricule: unmatchedMatricule ?? this.unmatchedMatricule,
        pendingSection: pendingSection,
        pendingGrade: pendingGrade,
        pendingFunction: pendingFunction,
        pendingStatus: pendingStatus,
        warnings: warnings ?? this.warnings,
        raw: raw,
      );

  @override
  String toString() => 'PlannedRow($lineNumber, $action, $errorMessage)';
}

/// معاينة الاستيراد — تُعرض للمستخدم **قبل** أي كتابة (قاعدة 9).
class ImportPreview {
  const ImportPreview({
    required this.kind,
    required this.fileName,
    required this.parsed,
    required this.mapping,
    required this.rows,
    this.detectedDateFormat,
    this.createdAt,
  });

  final String kind;
  final String fileName;
  final ParsedCsv parsed;
  final Object mapping;

  /// كل الصفوف مخطّطة (بما فيها المرفضة) — تعرض في شاشة المعاينة.
  final List<PlannedRow> rows;

  /// التنسيق المتعرَّف عليه من أول تاريخ صالح (للعرض فقط).
  final String? detectedDateFormat;
  final String? createdAt;

  int get totalRows => rows.length;

  int _count(RowAction a) => rows.where((PlannedRow r) => r.action == a).length;

  int get insertCount => _count(RowAction.insert);
  int get updateCount => _count(RowAction.update);
  int get duplicateInFileCount => _count(RowAction.duplicateInFile);
  int get duplicateExistingCount => _count(RowAction.duplicateExisting);
  int get errorCount => _count(RowAction.error);
  int get emptyCount => _count(RowAction.empty);

  /// المجموع الذي سيُكتب فعلياً.
  int get writableCount => insertCount + updateCount;

  /// سجلات المداومة غير المربوطة بموظف.
  List<PlannedRow> get unmatched =>
      rows.where((PlannedRow r) => r.unmatchedMatricule != null).toList();

  /// أول [max] صفوف مرفوضة — للعرض المختصر.
  List<PlannedRow> rejected({int max = 50}) =>
      rows.where((PlannedRow r) => r.isRejected).take(max).toList();

  /// تنبيه إن كان هناك صفوف تخطّت الصمت (لا معاينة ⇒ لا كتابة).
  bool get hasWork => writableCount > 0;
}

/// نتيجة التنفيذ الفعلي داخل Transaction.
class ImportResult {
  const ImportResult({
    required this.kind,
    required this.fileName,
    required this.inserted,
    required this.updated,
    required this.skipped,
    required this.errors,
    required this.referenceEntriesCreated,
    this.unmatchedCount = 0,
    this.deleted = 0,
    this.mode,
    this.succeeded = true,
    this.message,
  });

  final String kind;
  final String fileName;
  final int inserted;
  final int updated;
  final int skipped;
  final int errors;

  /// عدد الأقسام/الدرجات/الوظائف الجديدة أُنشئت أثناء الاستيراد.
  final int referenceEntriesCreated;
  final int unmatchedCount;
  final int deleted;
  final ImportMode? mode;
  final bool succeeded;
  final String? message;

  int get written => inserted + updated;

  Map<String, Object?> toHistoryRow() => <String, Object?>{
        'kind': kind,
        'file_name': fileName,
        'total_rows': inserted + updated + skipped + errors,
        'new_rows': inserted,
        'updated_rows': updated,
        'dup_rows': skipped,
        'error_rows': errors,
        'status': succeeded ? 'success' : 'failed',
        'message': message,
        'mode': mode?.id,
      };

  @override
  String toString() =>
      'ImportResult($kind: +$inserted ~$updated skip$skipped err$errors)';
}
