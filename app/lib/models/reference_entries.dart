import '../core/utils/text_normalizer.dart';

/// مدخل مرجعي عام (sections / grades / functions).
///
/// يُستخدم في القوائم المنسدلة والبحث حيث لا يهم النوع الدقيق.
class ReferenceEntry {
  const ReferenceEntry({
    this.id,
    required this.name,
    this.nameAr,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? nameAr;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  /// الاسم المعروض: العربية أولاً إن وجدت.
  String get display =>
      (nameAr?.trim().isNotEmpty ?? false) ? nameAr! : name;

  factory ReferenceEntry.fromMap(Map<String, Object?> m) => ReferenceEntry(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        nameAr: m['name_ar'] as String?,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'name_ar': nameAr,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  @override
  bool operator ==(Object other) =>
      other is ReferenceEntry && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'ReferenceEntry($id, $name)';
}

/// نموذج القسم المرجعي (قاعدة 12).
class Section {
  const Section({
    this.id,
    required this.name,
    this.nameAr,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? nameAr;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  /// الاسم المعروض: العربية أولاً إن وجدت.
  String get display => (nameAr?.trim().isNotEmpty ?? false) ? nameAr! : name;

  Section copyWith({
    int? id,
    String? name,
    String? nameAr,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) =>
      Section(
        id: id ?? this.id,
        name: name ?? this.name,
        nameAr: nameAr ?? this.nameAr,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'name_ar': nameAr,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// نص البحث المطبَّع (اسم + اسم عربي) — `search_text`.
  String get searchText => TextNormalizer.searchText(<String?>[name, nameAr]);

  Map<String, Object?> toInsertMap() => <String, Object?>{
        'name': name,
        'name_ar': nameAr,
        'search_text': searchText,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Section.fromMap(Map<String, Object?> m) => Section(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        nameAr: m['name_ar'] as String?,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'name_ar': nameAr,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        id: j['id'] as int?,
        name: (j['name'] as String?) ?? '',
        nameAr: j['name_ar'] as String?,
        isActive: (j['is_active'] as bool?) ?? true,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Section && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Section($id, $name)';
}

/// نموذج الرتبة المرجعية.
class Grade {
  const Grade({
    this.id,
    required this.name,
    this.nameAr,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? nameAr;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  String get display => (nameAr?.trim().isNotEmpty ?? false) ? nameAr! : name;

  Grade copyWith({
    int? id,
    String? name,
    String? nameAr,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) =>
      Grade(
        id: id ?? this.id,
        name: name ?? this.name,
        nameAr: nameAr ?? this.nameAr,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// نص البحث المطبَّع (اسم + اسم عربي) — `search_text`.
  String get searchText => TextNormalizer.searchText(<String?>[name, nameAr]);

  Map<String, Object?> toInsertMap() => <String, Object?>{
        'name': name,
        'name_ar': nameAr,
        'search_text': searchText,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Grade.fromMap(Map<String, Object?> m) => Grade(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        nameAr: m['name_ar'] as String?,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'name_ar': nameAr,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
        id: j['id'] as int?,
        name: (j['name'] as String?) ?? '',
        nameAr: j['name_ar'] as String?,
        isActive: (j['is_active'] as bool?) ?? true,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Grade && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Grade($id, $name)';
}

/// نموذج الوظيفة المرجعية.
class FunctionEntry {
  const FunctionEntry({
    this.id,
    required this.name,
    this.nameAr,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? nameAr;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  String get display => (nameAr?.trim().isNotEmpty ?? false) ? nameAr! : name;

  FunctionEntry copyWith({
    int? id,
    String? name,
    String? nameAr,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) =>
      FunctionEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        nameAr: nameAr ?? this.nameAr,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// نص البحث المطبَّع (اسم + اسم عربي) — `search_text`.
  String get searchText => TextNormalizer.searchText(<String?>[name, nameAr]);

  Map<String, Object?> toInsertMap() => <String, Object?>{
        'name': name,
        'name_ar': nameAr,
        'search_text': searchText,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory FunctionEntry.fromMap(Map<String, Object?> m) => FunctionEntry(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        nameAr: m['name_ar'] as String?,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'name_ar': nameAr,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory FunctionEntry.fromJson(Map<String, dynamic> j) => FunctionEntry(
        id: j['id'] as int?,
        name: (j['name'] as String?) ?? '',
        nameAr: j['name_ar'] as String?,
        isActive: (j['is_active'] as bool?) ?? true,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  @override
  bool operator ==(Object other) => other is FunctionEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FunctionEntry($id, $name)';
}
