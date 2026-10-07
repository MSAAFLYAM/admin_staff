import '../core/constants/db_constants.dart';

/// إعدادات قاعدة الرخص — تُقرأ من جدول `leave_types`.
///
/// **مبدأ محوري (قاعدة 17):** لا يوجد أي رقم ثابت في الكود.
/// كل هذه القيم قابلة للتعديل من واجهة الإدارة.
class LeaveRuleConfig {
  const LeaveRuleConfig({
    this.duration = 1,
    this.unit = Db.unitDays,
    this.countStartDay = true,
    this.includeWeekends = false,
    this.includeHolidays = false,
    this.dayCountMode = Db.modeCalendar,
    this.returnDayMode = Db.returnNextWorking,
    this.weekendDays = const <int>{5, 6},
  });

  /// المدة الافتراضية (قابلة للتعديل).
  final double duration;

  /// `hours` أو `days`.
  final String unit;

  /// هل يُحتسب يوم البداية؟
  final bool countStartDay;

  /// هل تُحتسب أيام نهاية الأسبوع؟
  final bool includeWeekends;

  /// هل تُحتسب العطل الرسمية؟
  final bool includeHolidays;

  /// `calendar` أو `working`.
  final String dayCountMode;

  /// `immediate` أو `next_working_day`.
  final String returnDayMode;

  /// أيام العطلة الأسبوعية: 5=الجمعة، 6=السبت.
  final Set<int> weekendDays;

  bool get isHours => unit == Db.unitHours;
  bool get isWorkingDays => dayCountMode == Db.modeWorking;
  bool get isImmediateReturn => returnDayMode == Db.returnImmediate;

  LeaveRuleConfig copyWith({
    double? duration,
    String? unit,
    bool? countStartDay,
    bool? includeWeekends,
    bool? includeHolidays,
    String? dayCountMode,
    String? returnDayMode,
    Set<int>? weekendDays,
  }) =>
      LeaveRuleConfig(
        duration: duration ?? this.duration,
        unit: unit ?? this.unit,
        countStartDay: countStartDay ?? this.countStartDay,
        includeWeekends: includeWeekends ?? this.includeWeekends,
        includeHolidays: includeHolidays ?? this.includeHolidays,
        dayCountMode: dayCountMode ?? this.dayCountMode,
        returnDayMode: returnDayMode ?? this.returnDayMode,
        weekendDays: weekendDays ?? this.weekendDays,
      );

  factory LeaveRuleConfig.fromMap(Map<String, Object?> m) => LeaveRuleConfig(
        duration: ((m['default_duration'] as num?) ?? 1).toDouble(),
        unit: (m['duration_unit'] as String?) ?? Db.unitDays,
        countStartDay: ((m['count_start_day'] as int?) ?? 1) == 1,
        includeWeekends: ((m['include_weekends'] as int?) ?? 0) == 1,
        includeHolidays: ((m['include_holidays'] as int?) ?? 0) == 1,
        dayCountMode: (m['day_count_mode'] as String?) ?? Db.modeCalendar,
        returnDayMode: (m['return_day_mode'] as String?) ?? Db.returnNextWorking,
      );
}

/// نوع الرخصة (جدول `leave_types`).
class LeaveType {
  const LeaveType({
    this.id,
    required this.nameAr,
    this.nameFr,
    this.defaultDuration = 1,
    this.durationUnit = Db.unitDays,
    this.countStartDay = true,
    this.includeWeekends = false,
    this.includeHolidays = false,
    this.dayCountMode = Db.modeCalendar,
    this.returnDayMode = Db.returnNextWorking,
    this.statusTypeId,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String nameAr;
  final String? nameFr;
  final double defaultDuration;
  final String durationUnit;
  final bool countStartDay;
  final bool includeWeekends;
  final bool includeHolidays;
  final String dayCountMode;
  final String returnDayMode;
  final int? statusTypeId;
  final bool isActive;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;

  String get displayName =>
      (nameFr?.trim().isNotEmpty ?? false) ? nameFr! : nameAr;

  /// يحوّل حقول النوع إلى إعدادات قابلة للتمرير لمحرك الحساب.
  LeaveRuleConfig toRuleConfig({double? overrideDuration}) => LeaveRuleConfig(
        duration: overrideDuration ?? defaultDuration,
        unit: durationUnit,
        countStartDay: countStartDay,
        includeWeekends: includeWeekends,
        includeHolidays: includeHolidays,
        dayCountMode: dayCountMode,
        returnDayMode: returnDayMode,
      );

  LeaveType copyWith({
    int? id,
    String? nameAr,
    String? nameFr,
    double? defaultDuration,
    String? durationUnit,
    bool? countStartDay,
    bool? includeWeekends,
    bool? includeHolidays,
    String? dayCountMode,
    String? returnDayMode,
    int? statusTypeId,
    bool? isActive,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
    bool clearStatusType = false,
    bool clearNameFr = false,
  }) =>
      LeaveType(
        id: id ?? this.id,
        nameAr: nameAr ?? this.nameAr,
        nameFr: clearNameFr ? null : (nameFr ?? this.nameFr),
        defaultDuration: defaultDuration ?? this.defaultDuration,
        durationUnit: durationUnit ?? this.durationUnit,
        countStartDay: countStartDay ?? this.countStartDay,
        includeWeekends: includeWeekends ?? this.includeWeekends,
        includeHolidays: includeHolidays ?? this.includeHolidays,
        dayCountMode: dayCountMode ?? this.dayCountMode,
        returnDayMode: returnDayMode ?? this.returnDayMode,
        statusTypeId: clearStatusType ? null : (statusTypeId ?? this.statusTypeId),
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toInsertMap() => <String, Object?>{
        'name_ar': nameAr,
        'name_fr': nameFr,
        'default_duration': defaultDuration,
        'duration_unit': durationUnit,
        'count_start_day': countStartDay ? 1 : 0,
        'include_weekends': includeWeekends ? 1 : 0,
        'include_holidays': includeHolidays ? 1 : 0,
        'day_count_mode': dayCountMode,
        'return_day_mode': returnDayMode,
        'status_type_id': statusTypeId,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Map<String, Object?> toMap() => <String, Object?>{'id': id, ...toInsertMap()};

  factory LeaveType.fromMap(Map<String, Object?> m) => LeaveType(
        id: m['id'] as int?,
        nameAr: (m['name_ar'] as String?) ?? '',
        nameFr: m['name_fr'] as String?,
        defaultDuration: ((m['default_duration'] as num?) ?? 1).toDouble(),
        durationUnit: (m['duration_unit'] as String?) ?? Db.unitDays,
        countStartDay: ((m['count_start_day'] as int?) ?? 1) == 1,
        includeWeekends: ((m['include_weekends'] as int?) ?? 0) == 1,
        includeHolidays: ((m['include_holidays'] as int?) ?? 0) == 1,
        dayCountMode: (m['day_count_mode'] as String?) ?? Db.modeCalendar,
        returnDayMode: (m['return_day_mode'] as String?) ?? Db.returnNextWorking,
        statusTypeId: m['status_type_id'] as int?,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
        sortOrder: (m['sort_order'] as int?) ?? 0,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name_ar': nameAr,
        'name_fr': nameFr,
        'default_duration': defaultDuration,
        'duration_unit': durationUnit,
        'count_start_day': countStartDay,
        'include_weekends': includeWeekends,
        'include_holidays': includeHolidays,
        'day_count_mode': dayCountMode,
        'return_day_mode': returnDayMode,
        'status_type_id': statusTypeId,
        'is_active': isActive,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory LeaveType.fromJson(Map<String, dynamic> j) => LeaveType(
        id: j['id'] as int?,
        nameAr: (j['name_ar'] as String?) ?? '',
        nameFr: j['name_fr'] as String?,
        defaultDuration: ((j['default_duration'] as num?) ?? 1).toDouble(),
        durationUnit: (j['duration_unit'] as String?) ?? Db.unitDays,
        countStartDay: (j['count_start_day'] as bool?) ?? true,
        includeWeekends: (j['include_weekends'] as bool?) ?? false,
        includeHolidays: (j['include_holidays'] as bool?) ?? false,
        dayCountMode: (j['day_count_mode'] as String?) ?? Db.modeCalendar,
        returnDayMode:
            (j['return_day_mode'] as String?) ?? Db.returnNextWorking,
        statusTypeId: j['status_type_id'] as int?,
        isActive: (j['is_active'] as bool?) ?? true,
        sortOrder: (j['sort_order'] as int?) ?? 0,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is LeaveType && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LeaveType($id, $nameAr)';
}

/// سجل رخصة (جدول `leaves`).
class Leave {
  const Leave({
    this.id,
    required this.employeeId,
    required this.leaveTypeId,
    required this.startDate,
    required this.endDate,
    this.returnDate,
    this.duration,
    this.durationUnit,
    this.rawDuration,
    this.notes,
    this.isCancelled = false,
    this.createdAt,
    this.updatedAt,
    // ── عرض ──
    this.employeeName,
    this.employeeMatricule,
    this.leaveTypeName,
    this.leaveTypeNameFr,
  });

  final int? id;
  final int employeeId;
  final int leaveTypeId;

  /// `YYYY-MM-DD`
  final String startDate;
  final String endDate;
  final String? returnDate;
  final double? duration;
  final String? durationUnit;

  /// المدة كما أُدخلت حرفيّاً ("48h"، "3d") — تُعرض دون إعادة حساب.
  final String? rawDuration;
  final String? notes;
  final bool isCancelled;
  final String? createdAt;
  final String? updatedAt;

  // ── عرض من JOIN ──
  final String? employeeName;
  final String? employeeMatricule;
  final String? leaveTypeName;
  final String? leaveTypeNameFr;

  String get displayTypeName =>
      (leaveTypeName?.trim().isNotEmpty ?? false) ? leaveTypeName! : '';

  String get displayDuration {
    if (duration == null) return '';
    final String unit = durationUnit == Db.unitHours ? 'h' : 'd';
    final double d = duration!;
    final String v = d == d.roundToDouble() ? d.round().toString() : d.toString();
    return '$v$unit';
  }

  Leave copyWith({
    int? id,
    int? employeeId,
    int? leaveTypeId,
    String? startDate,
    String? endDate,
    String? returnDate,
    double? duration,
    String? durationUnit,
    String? rawDuration,
    String? notes,
    bool? isCancelled,
    String? createdAt,
    String? updatedAt,
    bool clearReturnDate = false,
    bool clearNotes = false,
  }) =>
      Leave(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        leaveTypeId: leaveTypeId ?? this.leaveTypeId,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        returnDate: clearReturnDate ? null : (returnDate ?? this.returnDate),
        duration: duration ?? this.duration,
        durationUnit: durationUnit ?? this.durationUnit,
        rawDuration: rawDuration ?? this.rawDuration,
        notes: clearNotes ? null : (notes ?? this.notes),
        isCancelled: isCancelled ?? this.isCancelled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        employeeName: employeeName,
        employeeMatricule: employeeMatricule,
        leaveTypeName: leaveTypeName,
        leaveTypeNameFr: leaveTypeNameFr,
      );

  Map<String, Object?> toInsertMap() => <String, Object?>{
        'employee_id': employeeId,
        'leave_type_id': leaveTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'return_date': returnDate,
        'duration': duration,
        'duration_unit': durationUnit,
        'raw_duration': rawDuration,
        'notes': notes,
        'is_cancelled': isCancelled ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Map<String, Object?> toMap() => <String, Object?>{'id': id, ...toInsertMap()};

  factory Leave.fromMap(Map<String, Object?> m) => Leave(
        id: m['id'] as int?,
        employeeId: (m['employee_id'] as int?) ?? 0,
        leaveTypeId: (m['leave_type_id'] as int?) ?? 0,
        startDate: (m['start_date'] as String?) ?? '',
        endDate: (m['end_date'] as String?) ?? '',
        returnDate: m['return_date'] as String?,
        duration: (m['duration'] as num?)?.toDouble(),
        durationUnit: m['duration_unit'] as String?,
        rawDuration: m['raw_duration'] as String?,
        notes: m['notes'] as String?,
        isCancelled: ((m['is_cancelled'] as int?) ?? 0) == 1,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
        employeeName: m['employee_name'] as String?,
        employeeMatricule: m['employee_matricule'] as String?,
        leaveTypeName: m['leave_type_name'] as String?,
        leaveTypeNameFr: m['leave_type_name_fr'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'employee_id': employeeId,
        'leave_type_id': leaveTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'return_date': returnDate,
        'duration': duration,
        'duration_unit': durationUnit,
        'raw_duration': rawDuration,
        'notes': notes,
        'is_cancelled': isCancelled,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Leave.fromJson(Map<String, dynamic> j) => Leave(
        id: j['id'] as int?,
        employeeId: (j['employee_id'] as int?) ?? 0,
        leaveTypeId: (j['leave_type_id'] as int?) ?? 0,
        startDate: (j['start_date'] as String?) ?? '',
        endDate: (j['end_date'] as String?) ?? '',
        returnDate: j['return_date'] as String?,
        duration: (j['duration'] as num?)?.toDouble(),
        durationUnit: j['duration_unit'] as String?,
        rawDuration: j['raw_duration'] as String?,
        notes: j['notes'] as String?,
        isCancelled: (j['is_cancelled'] as bool?) ?? false,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Leave && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Leave($id, $employeeId, $startDate→$endDate)';
}
