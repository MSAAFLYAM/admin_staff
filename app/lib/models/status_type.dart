/// الوضعية الإدارية (جدول مرجعي قابل للإدارة — Rule 13).
class StatusType {
  const StatusType({
    this.id,
    required this.name,
    this.nameFr,
    this.priority = 0,
    this.isTerminal = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? nameFr;

  /// كلما زادت الأولوية تغلّبت الحالة عند التداخل (قاعدة 84).
  final int priority;

  /// `1` = حالة نهائية (تقاعد) — لا يُلغى سجلها بوضعية لاحقة.
  final bool isTerminal;

  final bool isActive;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;

  StatusType copyWith({
    int? id,
    String? name,
    String? nameFr,
    int? priority,
    bool? isTerminal,
    bool? isActive,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) =>
      StatusType(
        id: id ?? this.id,
        name: name ?? this.name,
        nameFr: nameFr ?? this.nameFr,
        priority: priority ?? this.priority,
        isTerminal: isTerminal ?? this.isTerminal,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toInsertMap() => <String, Object?>{
        'name': name,
        'name_fr': nameFr,
        'priority': priority,
        'is_terminal': isTerminal ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        ...toInsertMap(),
      };

  factory StatusType.fromMap(Map<String, Object?> m) => StatusType(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        nameFr: m['name_fr'] as String?,
        priority: (m['priority'] as int?) ?? 0,
        isTerminal: ((m['is_terminal'] as int?) ?? 0) == 1,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
        sortOrder: (m['sort_order'] as int?) ?? 0,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'name_fr': nameFr,
        'priority': priority,
        'is_terminal': isTerminal,
        'is_active': isActive,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory StatusType.fromJson(Map<String, dynamic> j) => StatusType(
        id: j['id'] as int?,
        name: (j['name'] as String?) ?? '',
        nameFr: j['name_fr'] as String?,
        priority: (j['priority'] as int?) ?? 0,
        isTerminal: (j['is_terminal'] as bool?) ?? false,
        isActive: (j['is_active'] as bool?) ?? true,
        sortOrder: (j['sort_order'] as int?) ?? 0,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is StatusType && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StatusType($id, $name, p=$priority)';
}

/// سجل وضعية (قاعدة 14 — لا يُحذف التاريخ).
class StatusHistoryEntry {
  const StatusHistoryEntry({
    this.id,
    required this.employeeId,
    required this.statusTypeId,
    required this.startDate,
    this.endDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    // حقول عرض من join
    this.statusName,
    this.statusNameFr,
    this.statusPriority,
  });

  final int? id;
  final int employeeId;
  final int statusTypeId;

  /// `YYYY-MM-DD`
  final String startDate;

  /// `YYYY-MM-DD` أو `null` = مستمر.
  final String? endDate;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  // ── من JOIN ──
  final String? statusName;
  final String? statusNameFr;
  final int? statusPriority;

  String get displayStatus =>
      (statusNameFr?.trim().isNotEmpty ?? false) ? statusNameFr! : (statusName ?? '');

  bool get isOpen => endDate == null || endDate!.isEmpty;

  StatusHistoryEntry copyWith({
    int? id,
    int? employeeId,
    int? statusTypeId,
    String? startDate,
    String? endDate,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? statusName,
    String? statusNameFr,
    int? statusPriority,
    /// لإفراغ `end_date` صراحةً (null وحده يعني «لا تغيير»).
    bool clearEndDate = false,
  }) =>
      StatusHistoryEntry(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        statusTypeId: statusTypeId ?? this.statusTypeId,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        statusName: statusName ?? this.statusName,
        statusNameFr: statusNameFr ?? this.statusNameFr,
        statusPriority: statusPriority ?? this.statusPriority,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'employee_id': employeeId,
        'status_type_id': statusTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory StatusHistoryEntry.fromMap(Map<String, Object?> m) =>
      StatusHistoryEntry(
        id: m['id'] as int?,
        employeeId: (m['employee_id'] as int?) ?? 0,
        statusTypeId: (m['status_type_id'] as int?) ?? 0,
        startDate: (m['start_date'] as String?) ?? '',
        endDate: m['end_date'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
        statusName: m['status_name'] as String?,
        statusNameFr: m['status_name_fr'] as String?,
        statusPriority: m['status_priority'] as int?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'employee_id': employeeId,
        'status_type_id': statusTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> j) =>
      StatusHistoryEntry(
        id: j['id'] as int?,
        employeeId: (j['employee_id'] as int?) ?? 0,
        statusTypeId: (j['status_type_id'] as int?) ?? 0,
        startDate: (j['start_date'] as String?) ?? '',
        endDate: j['end_date'] as String?,
        notes: j['notes'] as String?,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is StatusHistoryEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
