import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';
import '../core/query/search_query.dart';
import '../core/utils/app_date.dart';
import '../core/utils/date_input.dart';
import '../core/utils/text_normalizer.dart';
import '../models/leave.dart';
import '../models/status_type.dart';
import '../services/conflict_detector.dart';
import '../services/leave_calculator.dart';
import 'status_repository.dart';

/// فلتر قراءة الرخص — كل القيم اختيارية.
///
/// [from]/[to] يعنيان «الرخص التي **تتداخل** مع النطاق»، لا
/// «التي تبدأ بعده» — هذا ما ينتظره المستخدم فعلاً.
class LeaveFilter {
  const LeaveFilter({
    this.employeeId,
    this.leaveTypeId,
    this.from,
    this.to,
    this.text = '',
    this.includeCancelled = false,
  });

  final int? employeeId;
  final int? leaveTypeId;

  /// `YYYY-MM-DD` أو أي تنسيق يفهمه [AppDate] — يُوحَّد داخلياً.
  final String? from;
  final String? to;

  /// نص حرّ: يبحث في `search_text` للموظف وفي ملاحظات الرخصة.
  final String text;

  /// الرخص الملغاة ليست ضمن النتائج إلا صراحةً (قاعدة 31/D-008).
  final bool includeCancelled;
}

/// صفحة نتائج الرخص — الترقيم داخل SQL لا في الذاكرة.
class LeavePage {
  const LeavePage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<Leave> items;
  final int total;
  final int offset;
  final int limit;

  bool get hasMore => offset + items.length < total;
  bool get isEmpty => items.isEmpty;
  int get pageCount => limit <= 0 ? 1 : ((total + limit - 1) ~/ limit);
}

/// ★ مستودع الرخص (قواعد 17، 18، 31، 45).
///
/// **فصل صارم:** الحساب في [LeaveCalculator]، كشف التعارض في
/// [ConflictDetector]، واشتقاق الوضعية في [StatusResolver] —
/// المستودع يقرأ ويكتب الصفوف وينادي تلك الخدمات، ولا يحتوي
/// خوارزمية واحدة.
class LeaveRepository {
  LeaveRepository(this._database, this._statuses);

  final AppDatabase _database;

  /// يقرأ `status_history` عبر المستودع المختص — لا نكرّر الـ SQL.
  final StatusRepository _statuses;

  Database get _db => _database.db;

  static String _now() => DateTime.now().toIso8601String();

  /// `l` = leaves، `lt` = leave_types، `e` = employees.
  static const String _joins = '''
  JOIN ${Db.leaveTypes} lt ON lt.${Db.cId} = l.${Db.cLeaveTypeId}
  JOIN ${Db.employees}  e  ON e.${Db.cId}  = l.${Db.cEmployeeId}
''';

  /// جلب سجل مع أسماء النوع والموظف — **موضع واحد** للاستعلام.
  ///
  /// اسم الموظف بالفرنسية إن وُجد، وإلا بالعربية (يمنع خلط اللغتين
  /// في سطر واحد).
  static const String _select = '''
SELECT l.*,
       lt.${Db.cNameAr} AS leave_type_name,
       lt.${Db.cNameFr} AS leave_type_name_fr,
       e.${Db.cMatricule} AS employee_matricule,
       CASE
         WHEN COALESCE(e.${Db.cNomFr}, '') <> ''
           OR COALESCE(e.${Db.cPrenomFr}, '') <> ''
           THEN TRIM(COALESCE(e.${Db.cPrenomFr}, '') || ' ' ||
                     COALESCE(e.${Db.cNomFr}, ''))
           ELSE TRIM(COALESCE(e.${Db.cPrenomAr}, '') || ' ' ||
                     COALESCE(e.${Db.cNomAr}, ''))
       END AS employee_name
  FROM ${Db.leaves} l
$_joins''';

  // ── القراءة ─────────────────────────────────────────────────

  Future<Leave?> byId(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE l.${Db.cId} = ?',
      <Object?>[id],
    );
    return rows.isEmpty ? null : Leave.fromMap(rows.first);
  }

  /// رخص موظف — الأحدث أولاً، والملغاة مستثناة افتراضياً.
  Future<List<Leave>> forEmployee(
    int employeeId, {
    bool includeCancelled = false,
  }) async {
    final String extra =
        includeCancelled ? '' : ' AND l.${Db.cIsCancelled} = 0';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE l.${Db.cEmployeeId} = ?$extra '
      'ORDER BY l.${Db.cStartDate} DESC, l.${Db.cId} DESC',
      <Object?>[employeeId],
    );
    return rows.map(Leave.fromMap).toList();
  }

  /// الرخص السارية في [date] لموظف (تُستعمل في اشتقاق الوضعية).
  Future<List<Leave>> covering(int employeeId, String date) async {
    final String d = _isoDate(date);
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE l.${Db.cEmployeeId} = ? '
      'AND l.${Db.cIsCancelled} = 0 '
      'AND l.${Db.cStartDate} <= ? AND l.${Db.cEndDate} >= ? '
      'ORDER BY l.${Db.cStartDate}',
      <Object?>[employeeId, d, d],
    );
    return rows.map(Leave.fromMap).toList();
  }

  /// بحث مُصفّى مع ترقيم داخل SQL.
  Future<LeavePage> search(
    LeaveFilter filter, {
    int limit = 50,
    int offset = 0,
  }) async {
    final SqlWhere where = _where(filter);
    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.clause}';

    final List<Map<String, Object?>> countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${Db.leaves} l$_joins$whereSql',
      where.args,
    );
    final int total = (countRows.first['n'] as int?) ?? 0;

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select $whereSql '
      'ORDER BY l.${Db.cStartDate} DESC, l.${Db.cId} DESC '
      'LIMIT ? OFFSET ?',
      <Object?>[...where.args, limit, offset],
    );

    return LeavePage(
      items: rows.map(Leave.fromMap).toList(),
      total: total,
      offset: offset,
      limit: limit,
    );
  }

  // ── إعدادات القاعدة (قاعدة 17 — لا رقم في الكود) ───────────

  /// أنواع الرخص من `leave_types` — **مصدر العرض الوحيد** في الواجهة.
  Future<List<LeaveType>> types({bool activeOnly = false}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.leaveTypes,
      where: activeOnly ? '${Db.cIsActive} = 1' : null,
      orderBy: '${Db.cSortOrder} ASC, ${Db.cId} ASC',
    );
    return rows.map(LeaveType.fromMap).toList();
  }

  /// ينشئ نوع رخصة جديداً (المدد كلها من الصف لا من الكود).
  Future<int> createType({
    required String nameAr,
    String? nameFr,
    double defaultDuration = 1,
    String durationUnit = Db.unitDays,
    bool countStartDay = true,
    bool includeWeekends = false,
    bool includeHolidays = false,
  }) async {
    final String ar = nameAr.trim();
    if (ar.isEmpty) {
      throw const AppException('اسم نوع الرخصة إلزامي.');
    }
    final List<Map<String, Object?>> dup = await _db.query(
      Db.leaveTypes,
      where: '${Db.cNameAr} = ?',
      whereArgs: <Object?>[ar],
      limit: 1,
    );
    if (dup.isNotEmpty) {
      throw const AppException('نوع رخصة بهذا الاسم موجود مسبقاً.');
    }
    final String now = _now();
    return _db.insert(Db.leaveTypes, <String, Object?>{
      Db.cNameAr: ar,
      Db.cNameFr: (nameFr ?? '').trim().isEmpty ? null : nameFr!.trim(),
      Db.cDefaultDuration: defaultDuration,
      Db.cDurationUnit: durationUnit,
      'count_start_day': countStartDay ? 1 : 0,
      'include_weekends': includeWeekends ? 1 : 0,
      'include_holidays': includeHolidays ? 1 : 0,
      Db.cIsActive: 1,
      Db.cCreatedAt: now,
      Db.cUpdatedAt: now,
    });
  }

  /// قاعدة نوع الرخصة كما هي في `leave_types` — **مصدر المدد الوحيد**.
  Future<LeaveRuleConfig> ruleFor(int leaveTypeId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.leaveTypes,
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[leaveTypeId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AppException('نوع الرخصة غير موجود.');
    }
    return LeaveRuleConfig.fromMap(rows.first);
  }

  /// العطل الرسمية النشطة — تُمرَّر للمحرّك حين يطلب الحساب
  /// تخطّي العطل.
  Future<Set<DateTime>> holidays() async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.holidays,
      columns: <String>[Db.cDate],
      where: '${Db.cIsActive} = 1',
    );
    final Set<DateTime> out = <DateTime>{};
    for (final Map<String, Object?> m in rows) {
      final DateTime? d = AppDate.tryParse(m[Db.cDate] as String?);
      if (d != null) out.add(d);
    }
    return out;
  }

  /// معاينة الحساب **بلا كتابة** — تعرضها الشاشة أثناء الإدخال:
  /// تاريخ النهاية، تاريخ العودة، والمدة المحتسبة.
  Future<LeaveCalculationResult> preview({
    required int leaveTypeId,
    required DateTime startDate,
    double? duration,
    String? durationUnit,
  }) async {
    final LeaveRuleConfig base = await ruleFor(leaveTypeId);
    final LeaveRuleConfig rule = base.copyWith(
      duration: duration ?? base.duration,
      unit: durationUnit ?? base.unit,
    );
    return _calc(rule, AppDate.format(startDate));
  }

  // ── التعارض (Rule 45) ──────────────────────────────────────

  /// يفحص التعارضات **بلا كتابة** — تُعرض للمستخدم قبل الحفظ.
  ///
  /// يقرأ فقط الصفوف التي يمكن أن تتداخل مع الفترة (فهارس
  /// `leaves(employee_id, start_date, end_date)` و
  /// `status_history(employee_id, start_date, end_date)`).
  Future<List<DetectedConflict>> conflictsFor(Leave candidate) async {
    if (candidate.endDate.isEmpty) return const <DetectedConflict>[];

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE l.${Db.cEmployeeId} = ? '
      'AND l.${Db.cIsCancelled} = 0 '
      'AND l.${Db.cStartDate} <= ? AND l.${Db.cEndDate} >= ?',
      <Object?>[
        candidate.employeeId,
        candidate.endDate,
        candidate.startDate,
      ],
    );
    final List<Leave> leaves = rows.map(Leave.fromMap).toList();
    final List<StatusHistoryEntry> history = await _statuses.overlapping(
      candidate.employeeId,
      candidate.startDate,
      candidate.endDate,
    );

    return ConflictDetector.checkLeave(
      candidate,
      leaves: leaves,
      history: history,
    );
  }

  // ── الكتابة ─────────────────────────────────────────────────

  /// ينشئ رخصة: يحسب النهاية والعودة بالمحرّك، يفحص التعارض،
  /// ثم يكتب في خطوة واحدة.
  ///
  /// **التعارض يرفض الكتابة** ما لم يمرّر [userConfirmed] — أي
  /// بعد أن قرأ المستخدم `Conflict Detected` ووافق. لا تطبيق
  /// تلقائي أبداً (قاعدة 45).
  Future<Leave> create({
    required int employeeId,
    required int leaveTypeId,
    required String startDate,
    double? duration,
    String? durationUnit,
    String? notes,
    bool userConfirmed = false,
  }) async {
    await _requireRow(Db.employees, employeeId, 'الموظف غير موجود.');
    await _requireRow(Db.leaveTypes, leaveTypeId, 'نوع الرخصة غير موجود.');

    final Leave candidate = await _build(
      employeeId: employeeId,
      leaveTypeId: leaveTypeId,
      startDate: startDate,
      duration: duration,
      durationUnit: durationUnit,
      notes: notes,
    );
    await _ensureNoConflict(candidate, userConfirmed: userConfirmed);

    final String now = _now();
    final int id = await _db.insert(
      Db.leaves,
      candidate.toInsertMap()
        ..[Db.cCreatedAt] = now
        ..[Db.cUpdatedAt] = now,
    );
    return _required(id);
  }

  /// يعدّل رخصة **مع إعادة الحساب** — لا يمكن أن تختلّ القيم
  /// المخزَّنة عن المحرّك.
  Future<Leave> update(
    Leave leave, {
    bool userConfirmed = false,
  }) async {
    if (leave.id == null) {
      throw const AppException('رخصة غير محفوظة بعد.');
    }
    final Leave? current = await byId(leave.id!);
    if (current == null) {
      throw const AppException('لم تعد هذه الرخصة موجودة.');
    }
    final Leave built = await _build(
      id: current.id,
      employeeId: current.employeeId,
      leaveTypeId: leave.leaveTypeId,
      startDate: leave.startDate,
      duration: leave.duration,
      durationUnit: leave.durationUnit,
      notes: leave.notes,
      isCancelled: current.isCancelled,
      createdAt: current.createdAt,
      leaveTypeName: current.leaveTypeName,
      leaveTypeNameFr: current.leaveTypeNameFr,
    );
    await _ensureNoConflict(built, userConfirmed: userConfirmed);

    await _db.update(
      Db.leaves,
      built.toInsertMap()..[Db.cUpdatedAt] = _now(),
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[leave.id],
    );
    return _required(leave.id!);
  }

  /// إلغاء **منطقي** — السجل يبقى في القاعدة (قاعدة 31/D-008).
  ///
  /// لا `DELETE` في هذا الملف إطلاقاً.
  Future<void> cancel(int id, {String? reason}) async {
    final Leave? current = await byId(id);
    if (current == null) {
      throw const AppException('سجل الرخصة غير موجود.');
    }
    if (current.isCancelled) return; // إلغاء مكرر = لا شيء

    final Map<String, Object?> values = <String, Object?>{
      Db.cIsCancelled: 1,
      Db.cUpdatedAt: _now(),
    };
    if (reason != null && reason.trim().isNotEmpty) {
      values[Db.cNotes] = reason.trim();
    }
    await _db.update(
      Db.leaves,
      values,
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// التراجع عن الإلغاء — يعيد الحالة كما كانت.
  Future<void> uncancel(int id) async {
    await _db.update(
      Db.leaves,
      <String, Object?>{Db.cIsCancelled: 0, Db.cUpdatedAt: _now()},
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  // ── أدوات داخلية ───────────────────────────────────────────

  /// يبني مرشّح الرخص جاهزاً للعرض أو للحفظ — **بلا قاعدة**.
  Future<Leave> _build({
    int? id,
    required int employeeId,
    required int leaveTypeId,
    required String startDate,
    double? duration,
    String? durationUnit,
    String? notes,
    bool isCancelled = false,
    String? createdAt,
    String? leaveTypeName,
    String? leaveTypeNameFr,
  }) async {
    final String start = _isoDate(startDate);
    final LeaveRuleConfig base = await ruleFor(leaveTypeId);
    final String unit = durationUnit ?? base.unit;
    final LeaveRuleConfig rule = base.copyWith(
      duration: duration ?? base.duration,
      unit: unit,
    );
    final LeaveCalculationResult calc = await _calc(rule, start);

    return Leave(
      id: id,
      employeeId: employeeId,
      leaveTypeId: leaveTypeId,
      startDate: start,
      endDate: AppDate.format(calc.endDate),
      returnDate: AppDate.format(calc.returnDate),
      duration: calc.countedDuration,
      durationUnit: calc.unit.dbValue,
      rawDuration: _raw(calc.countedDuration, calc.unit.dbValue),
      notes: notes,
      isCancelled: isCancelled,
      createdAt: createdAt,
      leaveTypeName: leaveTypeName,
      leaveTypeNameFr: leaveTypeNameFr,
    );
  }

  Future<LeaveCalculationResult> _calc(
    LeaveRuleConfig rule,
    String startIso,
  ) async {
    try {
      return LeaveCalculator.calculate(
        startDate: AppDate.parseStrict(startIso),
        rule: rule,
        holidays: await holidays(),
      );
    } on LeaveCalculationException catch (e) {
      throw AppException(e.message, cause: e);
    } on FormatException catch (e) {
      throw AppException('تاريخ البداية غير صالح.', cause: e);
    }
  }

  Future<void> _ensureNoConflict(
    Leave candidate, {
    required bool userConfirmed,
  }) async {
    final List<DetectedConflict> conflicts = await conflictsFor(candidate);
    if (conflicts.isEmpty || userConfirmed) return;
    throw ConflictException(
      conflicts,
      '${ConflictDetector.title}: ${conflicts.first.message}',
    );
  }

  SqlWhere _where(LeaveFilter f) {
    final List<SqlWhere> parts = <SqlWhere>[
      if (f.employeeId != null)
        SqlWhere('l.${Db.cEmployeeId} = ?', <Object?>[f.employeeId]),
      if (f.leaveTypeId != null)
        SqlWhere('l.${Db.cLeaveTypeId} = ?', <Object?>[f.leaveTypeId]),
      if (!f.includeCancelled)
        const SqlWhere('l.${Db.cIsCancelled} = 0', <Object?>[]),
      if (_isoOrNull(f.to) != null)
        SqlWhere('l.${Db.cStartDate} <= ?', <Object?>[_isoOrNull(f.to)]),
      if (_isoOrNull(f.from) != null)
        SqlWhere('l.${Db.cEndDate} >= ?', <Object?>[_isoOrNull(f.from)]),
      _text(f.text),
    ];
    return SqlWhere.combine(parts, logic: 'AND');
  }

  /// نص حرّ بكل الكلمات (AND) — نفس منطق البحث العام، لكن على
  /// عمودَيّ `search_text` للموظف وملاحظات الرخصة فقط (لا JOIN
  /// الأقسام هنا).
  SqlWhere _text(String raw) {
    final List<String> tokens = TextNormalizer.tokens(raw);
    if (tokens.isEmpty) return SqlWhere.none;

    final List<SqlWhere> perToken = <SqlWhere>[];
    for (final String t in tokens) {
      final String pattern = '%${SearchQueryBuilder.escapeLike(t)}%';
      perToken.add(
        SqlWhere(
          "LOWER(COALESCE(e.${Db.cSearchText}, '')) LIKE ? ESCAPE '\\' "
          "OR LOWER(COALESCE(l.${Db.cNotes}, '')) LIKE ? ESCAPE '\\'",
          <Object?>[pattern, pattern],
        ),
      );
    }
    return SqlWhere.combine(perToken, logic: 'AND');
  }

  /// يوحّد التاريخ إلى `YYYY-MM-DD` أو يرمي رسالة عربية.
  ///
  /// المنطق كله في [DateInput] — لا نسخة ثانية من الرسالة.
  static String _isoDate(String raw) => DateInput.iso(raw);

  /// يوحّد بلا رمي — للفلاتر (مدخل خاطئ يعني «بلا قيد» لا خطأ).
  static String? _isoOrNull(String? raw) => DateInput.isoOrNull(raw);

  /// صيغة `raw_duration` كما يكتبها المستخدم: `48h` / `3d`.
  static String _raw(double v, String unit) {
    final String n = v == v.roundToDouble() ? v.round().toString() : '$v';
    return '$n${unit == Db.unitHours ? 'h' : 'd'}';
  }

  Future<void> _requireRow(String table, int id, String message) async {
    final List<Map<String, Object?>> rows = await _db.query(
      table,
      columns: <String>[Db.cId],
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) throw AppException(message);
  }

  /// إحضار سجل مطلوب — يرمي رسالة عربية إن لم يعد موجوداً.
  Future<Leave> _required(int id) async {
    final Leave? leave = await byId(id);
    if (leave == null) {
      throw const AppException('سجل الرخصة غير موجود.');
    }
    return leave;
  }
}
