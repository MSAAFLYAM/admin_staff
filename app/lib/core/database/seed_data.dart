import '../constants/db_constants.dart';

/// بيانات أولية (seed).
///
/// **قاعدة حاسمة (17):** كل المدد والقواعد هنا هي
/// *Business Defaults قابلة للتعديل* — وليست قوانين ثابتة في الكود.
/// المستخدم يستطيع تعديلها بالكامل من واجهة الإدارة.
abstract final class SeedData {
  static final String now = DateTime.now().toUtc().toIso8601String();

  /// الوضعيات الإدارية (قاعدة 13).
  /// priority يحكم الحالات المتداخلة (قاعدة 84) وهو قابل للتعديل.
  static const List<List<Object?>> statusTypes = <List<Object?>>[
    // name, name_fr, priority, sort_order, is_terminal
    ['في الخدمة', 'En service', 0, 0, 0],
    ['عطلة إدارية', 'Congé administratif', 20, 1, 0],
    ['رخصة استثنائية', 'Congé exceptionnel', 20, 2, 0],
    ['رخصة مرضية', 'Congé maladie', 30, 3, 0],
    ['تصريف الإجازات', 'Liquidation de congés', 20, 4, 0],
    ['موقوف', 'Suspendu', 90, 5, 0],
    ['التقاعد النسبي', 'Retraite progressive', 80, 6, 0],
    ['التقاعد', 'Retraite', 100, 7, 1],
    ['أخرى', 'Autre', 10, 8, 0],
  ];

  // ── أنواع الرخص الافتراضية (Rule 17) ────────────────────────
  // [name_ar, name_fr, duration, unit, count_start_day,
  //  include_weekends, include_holidays, day_count_mode,
  //  return_day_mode, sort_order]
  static const List<List<Object?>> leaveTypes = <List<Object?>>[
    [
      'عطلة إدارية', 'Congé administratif', 30.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 0,
    ],
    [
      'رخصة مرضية', 'Congé maladie', 30.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 1,
    ],
    [
      'رخصة استثنائية', 'Congé exceptionnel', 15.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 2,
    ],
    // ⏱️ وحدة الساعات
    [
      'رخصة 48 ساعة', 'Permission 48 heures', 48.0, Db.unitHours,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 3,
    ],
    [
      'وفاة أصل', "Décès d'un ascendant", 3.0, Db.unitDays,
      1, 1, 1, Db.modeCalendar, Db.returnNextWorking, 4,
    ],
    [
      'وفاة فرع', "Décès d'un descendant", 2.0, Db.unitDays,
      1, 1, 1, Db.modeCalendar, Db.returnNextWorking, 5,
    ],
    [
      'رخصة الترحال (خارج مدينة التعيين)',
      'Mutation hors ville', 3.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 6,
    ],
    [
      'رخصة الترحال (داخل مدينة التعيين)',
      'Mutation dans la ville', 1.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 7,
    ],
    [
      'ازدياد مولود', "Naissance d'un enfant", 15.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 8,
    ],
    [
      'تصريف الإجازات', 'Liquidation de congés', 30.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 9,
    ],
    [
      'التقاعد النسبي', 'Retraite progressive', 0.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnImmediate, 10,
    ],
    [
      'التقاعد', 'Retraite', 0.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnImmediate, 11,
    ],
    [
      'أخرى', 'Autre', 1.0, Db.unitDays,
      1, 0, 0, Db.modeCalendar, Db.returnNextWorking, 12,
    ],
  ];

  /// أسماء الوضعيات التي ترتبط بأنواع الرخص تلقائياً.
  /// الربط يتم بعد إنشاء الجداول (يحتاج SELECT بالاسم).
  static const Map<String, String> leaveTypeToStatus = <String, String>{
    'عطلة إدارية': 'عطلة إدارية',
    'رخصة مرضية': 'رخصة مرضية',
    'رخصة استثنائية': 'رخصة استثنائية',
    'تصريف الإجازات': 'تصريف الإجازات',
    'التقاعد النسبي': 'التقاعد النسبي',
    'التقاعد': 'التقاعد',
    'رخصة 48 ساعة': 'أخرى',
    'وفاة أصل': 'أخرى',
    'وفاة فرع': 'أخرى',
    'رخصة الترحال (خارج مدينة التعيين)': 'أخرى',
    'رخصة الترحال (داخل مدينة التعيين)': 'أخرى',
    'ازدياد مولود': 'أخرى',
    'أخرى': 'أخرى',
  };
}
