import '../core/utils/text_normalizer.dart';

/// نموذج الموظف — المرجع الأساسي `matricule` (قاعدة 10).
///
/// كل المعرّفات (`matricule`, `ppr`, `mobile_phone`) **TEXT**
/// لأنها قد تبدأ بـ 0 أو تحوي `+`.
class Employee {
  const Employee({
    this.id,
    required this.matricule,
    this.nomAr,
    this.prenomAr,
    this.nomFr,
    this.prenomFr,
    this.sectionId,
    this.functionId,
    this.quality,
    this.gradeId,
    this.ppr,
    this.mobilePhone,
    this.currentStatusId,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    // ── حقول عرض من JOIN ──
    this.sectionName,
    this.gradeName,
    this.functionName,
    this.statusName,
    this.statusNameFr,
    this.statusPriority,
    this.derivedStatusId,
    this.derivedStatusName,
  });

  final int? id;
  final String matricule;
  final String? nomAr;
  final String? prenomAr;
  final String? nomFr;
  final String? prenomFr;
  final int? sectionId;
  final int? functionId;
  final String? quality;
  final int? gradeId;
  final String? ppr;
  final String? mobilePhone;
  final int? currentStatusId;
  final String? notes;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  // ── عرض ──
  final String? sectionName;
  final String? gradeName;
  final String? functionName;
  final String? statusName;
  final String? statusNameFr;
  final int? statusPriority;

  /// الوضعية المشتقة حسابياً (قاعدة 44) — قد تختلف عن المسجّلة.
  final int? derivedStatusId;
  final String? derivedStatusName;

  // ── خصائص مساعدة ──────────────────────────────────────────

  /// الاسم بالعربية: `prenom_ar nom_ar`.
  String get nameAr {
    final String p = (prenomAr ?? '').trim();
    final String n = (nomAr ?? '').trim();
    return <String>[p, n].where((String s) => s.isNotEmpty).join(' ');
  }

  /// الاسم بالفرنسية: `NOM Prénom`.
  String get nameFr {
    final String n = (nomFr ?? '').trim();
    final String p = (prenomFr ?? '').trim();
    return <String>[n, p].where((String s) => s.isNotEmpty).join(' ');
  }

  /// أفضل اسم متاح للعرض.
  String get displayName {
    if (nameFr.isNotEmpty) return nameFr;
    if (nameAr.isNotEmpty) return nameAr;
    return matricule;
  }

  /// الاسم بالعربية إن وجد وإلا الفرنسي.
  String get displayNameAr => nameAr.isNotEmpty ? nameAr : displayName;

  bool get hasArabicName => nameAr.isNotEmpty;
  bool get hasFrenchName => nameFr.isNotEmpty;

  /// الوضعية المعروضة: المشتقة أولاً ثم المسجّلة.
  String get displayStatus => derivedStatusName ?? statusName ?? '';

  Employee copyWith({
    int? id,
    String? matricule,
    String? nomAr,
    String? prenomAr,
    String? nomFr,
    String? prenomFr,
    int? sectionId,
    int? functionId,
    String? quality,
    int? gradeId,
    String? ppr,
    String? mobilePhone,
    int? currentStatusId,
    String? notes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    String? sectionName,
    String? gradeName,
    String? functionName,
    String? statusName,
    String? statusNameFr,
    int? statusPriority,
    int? derivedStatusId,
    String? derivedStatusName,
    bool clearSection = false,
    bool clearGrade = false,
    bool clearFunction = false,
    bool clearStatus = false,
    bool clearPpr = false,
    bool clearPhone = false,
  }) =>
      Employee(
        id: id ?? this.id,
        matricule: matricule ?? this.matricule,
        nomAr: nomAr ?? this.nomAr,
        prenomAr: prenomAr ?? this.prenomAr,
        nomFr: nomFr ?? this.nomFr,
        prenomFr: prenomFr ?? this.prenomFr,
        sectionId: clearSection ? null : (sectionId ?? this.sectionId),
        functionId: clearFunction ? null : (functionId ?? this.functionId),
        quality: quality ?? this.quality,
        gradeId: clearGrade ? null : (gradeId ?? this.gradeId),
        ppr: clearPpr ? null : (ppr ?? this.ppr),
        mobilePhone: clearPhone ? null : (mobilePhone ?? this.mobilePhone),
        currentStatusId:
            clearStatus ? null : (currentStatusId ?? this.currentStatusId),
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        sectionName: sectionName ?? this.sectionName,
        gradeName: gradeName ?? this.gradeName,
        functionName: functionName ?? this.functionName,
        statusName: statusName ?? this.statusName,
        statusNameFr: statusNameFr ?? this.statusNameFr,
        statusPriority: statusPriority ?? this.statusPriority,
        derivedStatusId: derivedStatusId ?? this.derivedStatusId,
        derivedStatusName: derivedStatusName ?? this.derivedStatusName,
      );

  /// خريطة الإدراج (بدون id).
  ///
  /// تحتوي `search_text` المطبَّع — عمود البحث الافتراضي (قاعدة 61).
  Map<String, Object?> toInsertMap() => <String, Object?>{
        'matricule': matricule,
        'nom_ar': nomAr,
        'prenom_ar': prenomAr,
        'nom_fr': nomFr,
        'prenom_fr': prenomFr,
        'section_id': sectionId,
        'function_id': functionId,
        'quality': quality,
        'grade_id': gradeId,
        'ppr': ppr,
        'mobile_phone': mobilePhone,
        'current_status_id': currentStatusId,
        'notes': notes,
        'search_text': searchText,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// نص البحث المطبَّع لهذا الموظف (يُخزَّن في `employees.search_text`).
  ///
  /// الحقول النصية القابلة للبحث فقط — لا تُضمَّن المعرّفات الرقمية
  /// ([sectionId] [gradeId] [functionId] [currentStatusId]) لأنها
  /// تُبحث عبر فلاتر مخصّصة لا عبر النص الحرّ.
  String get searchText => TextNormalizer.searchText(<String?>[
        matricule,
        ppr,
        nomAr,
        prenomAr,
        nomFr,
        prenomFr,
        quality,
        mobilePhone,
      ]);

  Map<String, Object?> toMap() => <String, Object?>{'id': id, ...toInsertMap()};

  factory Employee.fromMap(Map<String, Object?> m) => Employee(
        id: m['id'] as int?,
        matricule: (m['matricule'] as String?) ?? '',
        nomAr: m['nom_ar'] as String?,
        prenomAr: m['prenom_ar'] as String?,
        nomFr: m['nom_fr'] as String?,
        prenomFr: m['prenom_fr'] as String?,
        sectionId: m['section_id'] as int?,
        functionId: m['function_id'] as int?,
        quality: m['quality'] as String?,
        gradeId: m['grade_id'] as int?,
        ppr: m['ppr'] as String?,
        mobilePhone: m['mobile_phone'] as String?,
        currentStatusId: m['current_status_id'] as int?,
        notes: m['notes'] as String?,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
        sectionName: m['section_name'] as String?,
        gradeName: m['grade_name'] as String?,
        functionName: m['function_name'] as String?,
        statusName: m['status_name'] as String?,
        statusNameFr: m['status_name_fr'] as String?,
        statusPriority: m['status_priority'] as int?,
        derivedStatusId: m['derived_status_id'] as int?,
        derivedStatusName: m['derived_status_name'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'matricule': matricule,
        'nom_ar': nomAr,
        'prenom_ar': prenomAr,
        'nom_fr': nomFr,
        'prenom_fr': prenomFr,
        'section_id': sectionId,
        'function_id': functionId,
        'quality': quality,
        'grade_id': gradeId,
        'ppr': ppr,
        'mobile_phone': mobilePhone,
        'current_status_id': currentStatusId,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as int?,
        matricule: (j['matricule'] as String?) ?? '',
        nomAr: j['nom_ar'] as String?,
        prenomAr: j['prenom_ar'] as String?,
        nomFr: j['nom_fr'] as String?,
        prenomFr: j['prenom_fr'] as String?,
        sectionId: j['section_id'] as int?,
        functionId: j['function_id'] as int?,
        quality: j['quality'] as String?,
        gradeId: j['grade_id'] as int?,
        ppr: j['ppr'] as String?,
        mobilePhone: j['mobile_phone'] as String?,
        currentStatusId: j['current_status_id'] as int?,
        notes: j['notes'] as String?,
        isActive: (j['is_active'] as bool?) ?? true,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Employee && other.id == id && other.matricule == matricule;

  @override
  int get hashCode => Object.hash(id, matricule);

  @override
  String toString() => 'Employee($id, $matricule, $displayName)';
}
