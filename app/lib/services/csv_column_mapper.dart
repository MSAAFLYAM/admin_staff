import '../core/error/app_exception.dart';
import '../core/utils/text_normalizer.dart';

/// نوع ملف الاستيراد — كل نوع له حقوله الإلزامية.
enum ImportKind {
  employees('employees'),
  permanence('permanence');

  const ImportKind(this.id);
  final String id;
}

/// الحقل المستهدف في قاعدة البيانات.
class TargetField {
  const TargetField(
    this.key, {
    required this.label,
    this.required = false,
    this.aliases = const <String>[],
  });

  /// المفتاح الداخلي (مطابق لعمود DB إن أمكن).
  final String key;

  /// اسم العرض في شاشة التصحيح (يُترجم في الواجهة).
  final String label;

  /// هل رفض الصف بدونه؟
  final bool required;

  /// أسماء بديلة تُقبل تلقائياً (عربي/فرنسي/مختصر).
  final List<String> aliases;
}

/// خريطة أعمدة محسَّنة: عمود CSV ← حقل مستهدف.
class ColumnMapping {
  const ColumnMapping(this.fieldKeyToColumnIndex);

  /// الحقل المستهدف ← فهرس العمود في الملف (أو null = غير مخصّص).
  final Map<String, int?> fieldKeyToColumnIndex;

  int? columnFor(String fieldKey) => fieldKeyToColumnIndex[fieldKey];

  bool isAssigned(String fieldKey) => fieldKeyToColumnIndex[fieldKey] != null;

  /// الحقول الإلزامية غير المخصّصة.
  List<String> missingRequired(Iterable<String> requiredKeys) =>
      requiredKeys.where((String k) => !isAssigned(k)).toList();

  /// عدد الحقول المخصّصة فعلياً.
  int get assignedCount =>
      fieldKeyToColumnIndex.values.where((int? i) => i != null).length;

  Map<String, int?> toJson() => Map<String, int?>.from(fieldKeyToColumnIndex);

  factory ColumnMapping.fromJson(Map<String, dynamic> json) => ColumnMapping(
        json.map(
          (String k, dynamic v) =>
              MapEntry<String, int?>(k, v == null ? null : v as int),
        ),
      );
}

/// ★ مطابِق رؤوس الأعمدة (قاعدة 53).
///
/// يقرأ أول سطر من الملف ويطابقه مع الحقول المطلوبة باستخدام:
///  1. مطابقة تامة (بعد التطبيع).
///  2. مطابقة جزئية (الرأس يحتوي اسم الحقل أو العكس).
///  3. أسماء بديلة معروفة (عربي/فرنسي/مختصر).
///
/// **لا يخمّن أبداً حقولاً إلزامية غير موجودة** — يتركها فارغة
/// لتُكتشف في شاشة التصحيح مع رسالة واضحة.
abstract final class CsvColumnMapper {
  // ── الحقول الرسمية ──────────────────────────────────────────

  static const List<TargetField> employeeFields = <TargetField>[
    TargetField(
      'matricule',
      label: 'Matricule',
      required: true,
      aliases: <String>['mat', 'num', 'numero', 'n°', 'id', 'الرقم', 'الترقيم'],
    ),
    TargetField(
      'nom_ar',
      label: 'Nom AR',
      aliases: <String>['nom arabe', 'اسم', 'الاسم', 'lname'],
    ),
    TargetField(
      'prenom_ar',
      label: 'Prénom AR',
      aliases: <String>['prenom arabe', 'اللقب', 'fname'],
    ),
    TargetField('nom_fr', label: 'Nom FR', aliases: <String>['lname fr']),
    TargetField('prenom_fr', label: 'Prénom FR', aliases: <String>['fname fr']),
    TargetField(
      'section',
      label: 'Section',
      aliases: <String>['service', 'direction', 'القسم', 'المصلحة', 'departement'],
    ),
    TargetField(
      'fonction',
      label: 'Fonction',
      aliases: <String>['poste', 'job', 'الوظيفة', 'المنصب'],
    ),
    TargetField(
      'qualite',
      label: 'Qualité',
      aliases: <String>['quality', 'صفة', 'الصفة'],
    ),
    TargetField('grade', label: 'Grade', aliases: <String>['échelon', 'echelon', 'الدرجة']),
    TargetField(
      'ppr',
      label: 'PPR',
      aliases: <String>['ppr_n', 'رقم الترقية'],
    ),
    TargetField(
      'mobile_phone',
      label: 'Téléphone mobile',
      aliases: <String>[
        'telephone',
        'téléphone',
        'tel',
        'mobile',
        'phone',
        'gsm',
        'الهاتف',
        'رقم الهاتف',
        'الجوال',
        'telephone_mobile',
        'num tel',
      ],
    ),
    TargetField(
      'status',
      label: 'Statut',
      aliases: <String>['statut', 'statut current', 'الوضعية', 'الحالة'],
    ),
    TargetField('notes', label: 'Notes', aliases: <String>['note', 'remark', 'ملاحظات']),
  ];

  static const List<TargetField> permanenceFields = <TargetField>[
    TargetField(
      'date',
      label: 'Date',
      required: true,
      aliases: <String>['jour', 'day', 'التاريخ', 'periode'],
    ),
    TargetField(
      'matricule',
      label: 'Matricule',
      required: true,
      aliases: <String>['mat', 'num', 'numero', 'الرقم'],
    ),
    TargetField(
      'permanencier',
      label: 'Permanencier',
      aliases: <String>['nom', 'name', 'agent', 'المداوم'],
    ),
    TargetField(
      'section',
      label: 'Section',
      aliases: <String>['service', 'القسم', 'المصلحة'],
    ),
    TargetField('grade', label: 'Grade', aliases: <String>['الدرجة']),
    TargetField('hpad', label: 'HPAD', aliases: <String>['h pad', 'reference', 'المرجع']),
    TargetField(
      'mobile_phone',
      label: 'Téléphone',
      aliases: <String>[
        'telephone',
        'tel',
        'mobile',
        'phone',
        'الهاتف',
        'الجوال',
        'telephone_mobile',
      ],
    ),
    TargetField(
      'horaire',
      label: 'Horaire',
      aliases: <String>[
        'schedule',
        'heure',
        'time',
        'timeslot',
        'plage',
        'التوقيت',
        'الساعة',
        'start_time',
      ],
    ),
  ];

  static List<TargetField> fieldsFor(ImportKind kind) => switch (kind) {
        ImportKind.employees => employeeFields,
        ImportKind.permanence => permanenceFields,
      };

  static List<String> requiredKeysFor(ImportKind kind) =>
      fieldsFor(kind)
          .where((TargetField f) => f.required)
          .map((TargetField f) => f.key)
          .toList();

  // ── المطابقة ────────────────────────────────────────────────

  /// مرادفات كلمة-بكلمة تُوحَّد قبل المقارنة حتى لا تُحرَّق
  /// المطابقة باختلاف اللغة: `full_name_ar` ≡ `nom_ar`.
  static const Map<String, String> _synonyms = <String, String>{
    'name': 'nom',
    'lastname': 'nom',
    'family': 'nom',
    'familyname': 'nom',
    'firstname': 'prenom',
    'given': 'prenom',
    'givenname': 'prenom',
    'phone': 'tel',
    'telephone': 'tel',
    'mobile': 'tel',
    'gsm': 'tel',
    'day': 'date',
    'schedule': 'horaire',
    'time': 'horaire',
    'hour': 'horaire',
    'heure': 'horaire',
    'plage': 'horaire',
    'poste': 'fonction',
    'job': 'fonction',
    'quality': 'qualite',
    'service': 'section',
    'direction': 'section',
    'departement': 'section',
    'numero': 'num',
    'number': 'num',
  };

  /// تطبيع + توحيد المرادفات + كسم التكرار المتتالي.
  ///
  /// `telephone_mobile` → `tel` ، `full_name_ar` → `full nom ar`.
  static String _norm(String input) {
    final List<String> words = TextNormalizer.normalize(input)
        .split(' ')
        .where((String w) => w.isNotEmpty)
        .map((String w) => _synonyms[w] ?? w)
        .toList();

    final List<String> out = <String>[];
    for (final String w in words) {
      if (out.isEmpty || out.last != w) out.add(w);
    }
    return out.join(' ');
  }

  /// يبني خريطة تلقائية من رؤوس الملف.
  ///
  /// [savedMapping] يُطبَّق أولاً إن كان صالحاً لهذا الملف
  /// (نفس عدد الأعمدة)؛ وإلا يُعاد التخمين.
  static ColumnMapping autoMap({
    required ImportKind kind,
    required List<String> headers,
    ColumnMapping? savedMapping,
  }) {
    if (savedMapping != null && _isUsable(savedMapping, headers)) {
      return savedMapping;
    }

    final Map<String, int?> result = <String, int?>{
      for (final TargetField f in fieldsFor(kind)) f.key: null,
    };

    // أعمدة الملف بعد التطبيع الموحّد.
    final List<String> normalizedHeaders = headers.map(_norm).toList();

    final Set<int> taken = <int>{};

    // 1) مطابقة تامة: الرأس == مفتاح الحقل أو أحد بدائله.
    for (final TargetField field in fieldsFor(kind)) {
      final List<String> candidates = <String>[
        _norm(field.key),
        ...field.aliases.map(_norm),
      ];
      for (int i = 0; i < normalizedHeaders.length; i++) {
        if (taken.contains(i)) continue;
        if (candidates.contains(normalizedHeaders[i])) {
          result[field.key] = i;
          taken.add(i);
          break;
        }
      }
    }

    // 2) مطابقة جزئية لما تبقّى (الرأس يحوي المفتاح أو العكس).
    for (final TargetField field in fieldsFor(kind)) {
      if (result[field.key] != null) continue;
      final String key = _norm(field.key);
      for (int i = 0; i < normalizedHeaders.length; i++) {
        if (taken.contains(i)) continue;
        final String header = normalizedHeaders[i];
        if (header.isEmpty || key.isEmpty) continue;
        if (header.contains(key) || key.contains(header)) {
          result[field.key] = i;
          taken.add(i);
          break;
        }
      }
    }

    // 3) بدائل جزئية (مثلاً "telephone mobile" يحوي "telephone").
    for (final TargetField field in fieldsFor(kind)) {
      if (result[field.key] != null) continue;
      for (final String alias in field.aliases) {
        final String a = _norm(alias);
        if (a.length < 3) continue;
        for (int i = 0; i < normalizedHeaders.length; i++) {
          if (taken.contains(i)) continue;
          final String header = normalizedHeaders[i];
          if (header.isEmpty) continue;
          if (header.contains(a) || a.contains(header)) {
            result[field.key] = i;
            taken.add(i);
            break;
          }
        }
        if (result[field.key] != null) break;
      }
    }

    return ColumnMapping(result);
  }

  /// خريطة "لا شيء مخصّص" — تُستخدم عند إلغاء التخمين.
  static ColumnMapping empty(ImportKind kind) => ColumnMapping(
        <String, int?>{for (final TargetField f in fieldsFor(kind)) f.key: null},
      );

  static bool _isUsable(ColumnMapping saved, List<String> headers) {
    final Iterable<int?> assigned =
        saved.fieldKeyToColumnIndex.values.where((int? i) => i != null);
    for (final int? i in assigned) {
      if (i == null || i < 0 || i >= headers.length) return false;
    }
    return true;
  }

  // ── التحقق ──────────────────────────────────────────────────

  /// يتحقق من أن الخريطة تكفي لاستيراد آمن.
  ///
  /// يرمي [AppException] برسالة عربية مفهومة إن نقص حقل إلزامي.
  static void validate({
    required ImportKind kind,
    required ColumnMapping mapping,
  }) {
    final List<String> missing = mapping
        .missingRequired(requiredKeysFor(kind));
    if (missing.isNotEmpty) {
      final String labels = fieldsFor(kind)
          .where((TargetField f) => missing.contains(f.key))
          .map((TargetField f) => f.label)
          .join('، ');
      throw AppException(
        'العمود $labels غير موجود في الملف. '
        'استخدم شاشة Column Mapping لتحديد العمود يدوياً.',
        techDetail: 'missing=$missing',
      );
    }
  }

  /// تُستخدم عند حفظ الخريطة في settings.
  static String storageKeyFor(ImportKind kind) => switch (kind) {
        ImportKind.employees => 'import_mapping_employees',
        ImportKind.permanence => 'import_mapping_permanence',
      };
}

/// امتداد لقراءة قيمة حقل من صف مطابقاً للخريطة.
extension ColumnMappingRowX on ColumnMapping {
  /// يقرأ عمود [fieldKey] من [row] بعد التطبيع (ترقيم + مسافات).
  String? read(String fieldKey, List<String> row) {
    final int? idx = columnFor(fieldKey);
    if (idx == null || idx >= row.length) return null;
    final String raw = row[idx].trim();
    return raw.isEmpty ? null : raw;
  }

  /// يقرأه كنص خام (يحتفظ بالمسافات) — للأسماء.
  String? readRaw(String fieldKey, List<String> row) {
    final int? idx = columnFor(fieldKey);
    if (idx == null || idx >= row.length) return null;
    final String raw = row[idx];
    return raw.trim().isEmpty ? null : raw;
  }
}
