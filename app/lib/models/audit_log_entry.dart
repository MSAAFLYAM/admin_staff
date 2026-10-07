/// سجل تدقيق (قاعدة 32).
///
/// **ملاحظة أمنية (قاعدة 58):** لا تُخزَّن بيانات حساسة
/// (هواتف، بيانات صحية) في [description].
class AuditLogEntry {
  const AuditLogEntry({
    this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.description,
    this.oldValue,
    this.newValue,
    this.createdAt,
  });

  final int? id;
  final String action;
  final String entityType;
  final int? entityId;
  final String? description;
  final String? oldValue;
  final String? newValue;
  final String? createdAt;

  // ── أفعال معيارية ────────────────────────────────────────────
  static const String actionCreate = 'CREATE';
  static const String actionUpdate = 'UPDATE';
  static const String actionArchive = 'ARCHIVE';
  static const String actionRestore = 'RESTORE';
  static const String actionImport = 'IMPORT';
  static const String actionBackup = 'BACKUP';
  static const String actionRestoreBackup = 'RESTORE_BACKUP';
  static const String actionChangeStatus = 'CHANGE_STATUS';
  static const String actionCancelLeave = 'CANCEL_LEAVE';

  // ── أنواع الكيانات ───────────────────────────────────────────
  static const String entityEmployee = 'employee';
  static const String entityLeave = 'leave';
  static const String entityLeaveType = 'leave_type';
  static const String entityStatus = 'status';
  static const String entityReference = 'reference';
  static const String entityImport = 'import';
  static const String entityBackup = 'backup';
  static const String entitySettings = 'settings';
  static const String entityPermanence = 'permanence';

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'description': description,
        'old_value': oldValue,
        'new_value': newValue,
        'created_at': createdAt,
      };

  /// خريطة الإدراج — بدون `id` (يولّده SQLite).
  Map<String, Object?> toInsertMap() => <String, Object?>{
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'description': description,
        'old_value': oldValue,
        'new_value': newValue,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };

  factory AuditLogEntry.fromMap(Map<String, Object?> m) => AuditLogEntry(
        id: m['id'] as int?,
        action: (m['action'] as String?) ?? '',
        entityType: (m['entity_type'] as String?) ?? '',
        entityId: m['entity_id'] as int?,
        description: m['description'] as String?,
        oldValue: m['old_value'] as String?,
        newValue: m['new_value'] as String?,
        createdAt: m['created_at'] as String?,
      );
}

/// سجل استيراد (جدول `import_history`).
class ImportHistoryEntry {
  const ImportHistoryEntry({
    this.id,
    required this.kind,
    this.fileName,
    this.delimiter,
    this.encoding,
    this.dateFormat,
    this.mode,
    this.totalRows = 0,
    this.newRows = 0,
    this.updatedRows = 0,
    this.dupRows = 0,
    this.errorRows = 0,
    required this.status,
    this.message,
    this.createdAt,
  });

  final int? id;

  /// `employees` أو `permanence`.
  final String kind;
  final String? fileName;
  final String? delimiter;
  final String? encoding;
  final String? dateFormat;
  final String? mode;
  final int totalRows;
  final int newRows;
  final int updatedRows;
  final int dupRows;
  final int errorRows;

  /// `success` | `failed` | `rolled_back`.
  final String status;
  final String? message;
  final String? createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'kind': kind,
        'file_name': fileName,
        'delimiter': delimiter,
        'encoding': encoding,
        'date_format': dateFormat,
        'mode': mode,
        'total_rows': totalRows,
        'new_rows': newRows,
        'updated_rows': updatedRows,
        'dup_rows': dupRows,
        'error_rows': errorRows,
        'status': status,
        'message': message,
        'created_at': createdAt,
      };

  factory ImportHistoryEntry.fromMap(Map<String, Object?> m) =>
      ImportHistoryEntry(
        id: m['id'] as int?,
        kind: (m['kind'] as String?) ?? '',
        fileName: m['file_name'] as String?,
        delimiter: m['delimiter'] as String?,
        encoding: m['encoding'] as String?,
        dateFormat: m['date_format'] as String?,
        mode: m['mode'] as String?,
        totalRows: (m['total_rows'] as int?) ?? 0,
        newRows: (m['new_rows'] as int?) ?? 0,
        updatedRows: (m['updated_rows'] as int?) ?? 0,
        dupRows: (m['dup_rows'] as int?) ?? 0,
        errorRows: (m['error_rows'] as int?) ?? 0,
        status: (m['status'] as String?) ?? 'failed',
        message: m['message'] as String?,
        createdAt: m['created_at'] as String?,
      );
}

/// عطلة رسمية (جدول `holidays` — Rule 19).
class Holiday {
  const Holiday({
    this.id,
    required this.date,
    this.nameAr,
    this.nameFr,
    this.isRecurring = false,
    this.isActive = true,
    this.createdAt,
  });

  final int? id;
  final String date;
  final String? nameAr;
  final String? nameFr;
  final bool isRecurring;
  final bool isActive;
  final String? createdAt;

  String get displayName => (nameAr?.trim().isNotEmpty ?? false)
      ? nameAr!
      : ((nameFr?.trim().isNotEmpty ?? false) ? nameFr! : date);

  Holiday copyWith({
    int? id,
    String? date,
    String? nameAr,
    String? nameFr,
    bool? isRecurring,
    bool? isActive,
    String? createdAt,
  }) =>
      Holiday(
        id: id ?? this.id,
        date: date ?? this.date,
        nameAr: nameAr ?? this.nameAr,
        nameFr: nameFr ?? this.nameFr,
        isRecurring: isRecurring ?? this.isRecurring,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toInsertMap() => <String, Object?>{
        'date': date,
        'name_ar': nameAr,
        'name_fr': nameFr,
        'is_recurring': isRecurring ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
      };

  factory Holiday.fromMap(Map<String, Object?> m) => Holiday(
        id: m['id'] as int?,
        date: (m['date'] as String?) ?? '',
        nameAr: m['name_ar'] as String?,
        nameFr: m['name_fr'] as String?,
        isRecurring: ((m['is_recurring'] as int?) ?? 0) == 1,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
        createdAt: m['created_at'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'date': date,
        'name_ar': nameAr,
        'name_fr': nameFr,
        'is_recurring': isRecurring,
        'is_active': isActive,
        'created_at': createdAt,
      };

  factory Holiday.fromJson(Map<String, dynamic> j) => Holiday(
        id: j['id'] as int?,
        date: (j['date'] as String?) ?? '',
        nameAr: j['name_ar'] as String?,
        nameFr: j['name_fr'] as String?,
        isRecurring: (j['is_recurring'] as bool?) ?? false,
        isActive: (j['is_active'] as bool?) ?? true,
        createdAt: j['created_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Holiday && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
