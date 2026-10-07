/// سجل مداومة (جدول `permanence`).
///
/// المفتاح الفريد: `(date, employee_id, time_slot)` — يسمح
/// بأكثر من فترة لموظف واحد في اليوم نفسه (D-010).
class PermanenceRecord {
  const PermanenceRecord({
    this.id,
    required this.date,
    this.employeeId,
    required this.matricule,
    this.permanencier,
    this.section,
    this.grade,
    this.hpad,
    this.mobilePhone,
    this.startTime,
    this.endTime,
    this.timeSlot = '',
    this.scheduleText,
    this.sourceFile,
    this.createdAt,
    this.updatedAt,
    // ── عرض ──
    this.employeeNameAr,
    this.employeeNameFr,
    this.sectionId,
    this.derivedStatusName,
  });

  final int? id;

  /// `YYYY-MM-DD`
  final String date;

  /// `null` = غير مربوط بموظف (Unmatched).
  final int? employeeId;

  /// الـ matricule كما ورد في الملف — محفوظ دائماً.
  final String matricule;

  final String? permanencier;
  final String? section;
  final String? grade;
  final String? hpad;
  final String? mobilePhone;

  /// `HH:mm`
  final String? startTime;
  final String? endTime;

  /// مفتاح الفترة: `start_time` أو `''`.
  final String timeSlot;

  /// نص `horaire` كما ورد.
  final String? scheduleText;
  final String? sourceFile;
  final String? createdAt;
  final String? updatedAt;

  // ── عرض ──
  final String? employeeNameAr;
  final String? employeeNameFr;
  final int? sectionId;
  final String? derivedStatusName;

  bool get isLinked => employeeId != null;

  String get displayName {
    final String fr = (employeeNameFr ?? '').trim();
    final String ar = (employeeNameAr ?? '').trim();
    if (fr.isNotEmpty) return fr;
    if (ar.isNotEmpty) return ar;
    return permanencier?.trim().isNotEmpty == true ? permanencier! : matricule;
  }

  String get displayTime {
    if (startTime == null && endTime == null) {
      return scheduleText?.trim() ?? '';
    }
    if (startTime != null && endTime != null) return '$startTime - $endTime';
    return startTime ?? endTime ?? '';
  }

  PermanenceRecord copyWith({
    int? id,
    String? date,
    int? employeeId,
    String? matricule,
    String? permanencier,
    String? section,
    String? grade,
    String? hpad,
    String? mobilePhone,
    String? startTime,
    String? endTime,
    String? timeSlot,
    String? scheduleText,
    String? sourceFile,
    String? createdAt,
    String? updatedAt,
    /// يُملأ من الاستعلام لا من القاعدة — يحق لكل قارئ أن يكتبه.
    String? derivedStatusName,
    bool clearEmployee = false,
    bool clearStart = false,
    bool clearEnd = false,
  }) =>
      PermanenceRecord(
        id: id ?? this.id,
        date: date ?? this.date,
        employeeId: clearEmployee ? null : (employeeId ?? this.employeeId),
        matricule: matricule ?? this.matricule,
        permanencier: permanencier ?? this.permanencier,
        section: section ?? this.section,
        grade: grade ?? this.grade,
        hpad: hpad ?? this.hpad,
        mobilePhone: mobilePhone ?? this.mobilePhone,
        startTime: clearStart ? null : (startTime ?? this.startTime),
        endTime: clearEnd ? null : (endTime ?? this.endTime),
        timeSlot: timeSlot ?? this.timeSlot,
        scheduleText: scheduleText ?? this.scheduleText,
        sourceFile: sourceFile ?? this.sourceFile,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        employeeNameAr: employeeNameAr,
        employeeNameFr: employeeNameFr,
        sectionId: sectionId,
        derivedStatusName: derivedStatusName ?? this.derivedStatusName,
      );

  Map<String, Object?> toInsertMap() => <String, Object?>{
        'date': date,
        'employee_id': employeeId,
        'matricule': matricule,
        'permanencier': permanencier,
        'section': section,
        'grade': grade,
        'hpad': hpad,
        'mobile_phone': mobilePhone,
        'start_time': startTime,
        'end_time': endTime,
        'time_slot': timeSlot,
        'schedule_text': scheduleText,
        'source_file': sourceFile,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Map<String, Object?> toMap() => <String, Object?>{'id': id, ...toInsertMap()};

  factory PermanenceRecord.fromMap(Map<String, Object?> m) => PermanenceRecord(
        id: m['id'] as int?,
        date: (m['date'] as String?) ?? '',
        employeeId: m['employee_id'] as int?,
        matricule: (m['matricule'] as String?) ?? '',
        permanencier: m['permanencier'] as String?,
        section: m['section'] as String?,
        grade: m['grade'] as String?,
        hpad: m['hpad'] as String?,
        mobilePhone: m['mobile_phone'] as String?,
        startTime: m['start_time'] as String?,
        endTime: m['end_time'] as String?,
        timeSlot: (m['time_slot'] as String?) ?? '',
        scheduleText: m['schedule_text'] as String?,
        sourceFile: m['source_file'] as String?,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
        employeeNameAr: m['employee_name_ar'] as String?,
        employeeNameFr: m['employee_name_fr'] as String?,
        sectionId: m['section_id'] as int?,
        derivedStatusName: m['derived_status_name'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'date': date,
        'employee_id': employeeId,
        'matricule': matricule,
        'permanencier': permanencier,
        'section': section,
        'grade': grade,
        'hpad': hpad,
        'mobile_phone': mobilePhone,
        'start_time': startTime,
        'end_time': endTime,
        'time_slot': timeSlot,
        'schedule_text': scheduleText,
        'source_file': sourceFile,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory PermanenceRecord.fromJson(Map<String, dynamic> j) =>
      PermanenceRecord(
        id: j['id'] as int?,
        date: (j['date'] as String?) ?? '',
        employeeId: j['employee_id'] as int?,
        matricule: (j['matricule'] as String?) ?? '',
        permanencier: j['permanencier'] as String?,
        section: j['section'] as String?,
        grade: j['grade'] as String?,
        hpad: j['hpad'] as String?,
        mobilePhone: j['mobile_phone'] as String?,
        startTime: j['start_time'] as String?,
        endTime: j['end_time'] as String?,
        timeSlot: (j['time_slot'] as String?) ?? '',
        scheduleText: j['schedule_text'] as String?,
        sourceFile: j['source_file'] as String?,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is PermanenceRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Permanence($id, $date, $matricule, $timeSlot)';
}
