import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';
import '../core/utils/app_date.dart';
import '../core/utils/date_input.dart';
import '../models/status_type.dart';
import '../services/status_resolver.dart';

/// ★ مستودع سجل الوضعيات والاشتقاق (قواعد 44، 14، 84).
///
/// **لا حذف فيزيائي أبداً** (قاعدة 14 / D-008): الإغلاق يتم بكتابة
/// `end_date`، والتعديل يتم على السجل نفسه — التاريخ يبقى موجوداً.
///
/// **لا قواعد أعمال هنا:** كل منطق ترتيب المرشّحين في
/// [StatusResolver] (نقي)، وكل منطق التداخل في `ConflictDetector`.
/// المستودع يجلب الصفوف ويسجّل.
class StatusRepository {
  StatusRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static String _now() => DateTime.now().toIso8601String();

  /// جلب سجل مع أسماء الوضعية — **موضع واحد** للاستعلام.
  ///
  /// `LEFT JOIN` لا `INNER` حتى لا يختفي أي سجل تاريخي إن فُقدت
  /// الوضعية المرتبطة.
  static const String _select = '''
SELECT h.*, st.${Db.cName} AS status_name,
       st.${Db.cNameFr} AS status_name_fr,
       st.${Db.cPriority} AS status_priority
  FROM ${Db.statusHistory} h
  LEFT JOIN ${Db.statusTypes} st ON st.${Db.cId} = h.${Db.cStatusTypeId}
''';

  // ── قراءة السجل ─────────────────────────────────────────────

  /// سجل موظف، مع إمكانية تقييده لتاريخ معيّن أو للحالات الجارية.
  Future<List<StatusHistoryEntry>> history(
    int employeeId, {
    String? on,
    bool activeOnly = false,
  }) async {
    final List<String> where = <String>['h.${Db.cEmployeeId} = ?'];
    final List<Object?> args = <Object?>[employeeId];

    if (on != null) {
      final String d = _isoDate(on);
      where.add('h.${Db.cStartDate} <= ?');
      args.add(d);
      where.add('(h.${Db.cEndDate} IS NULL OR h.${Db.cEndDate} >= ?)');
      args.add(d);
    } else if (activeOnly) {
      where.add('(h.${Db.cEndDate} IS NULL OR h.${Db.cEndDate} >= ?)');
      args.add(AppDate.format(AppDate.today()));
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE ${where.join(' AND ')} '
      'ORDER BY h.${Db.cStartDate} DESC, h.${Db.cId} DESC',
      args,
    );
    return rows.map(StatusHistoryEntry.fromMap).toList();
  }

  /// السجلات السارية في [date].
  Future<List<StatusHistoryEntry>> activeOn(
    int employeeId,
    String date,
  ) =>
      history(employeeId, on: date);

  /// السجلات التي تتداخل مع الفترة `[from, to]`.
  ///
  /// يُستدعى قبل حفظ رخصة (Rule 45) — يقرأ من فهرس
  /// `(employee_id, start_date, end_date)` فلا مسح للجدول.
  ///
  /// السجل المفتوح (`end_date IS NULL`) يُعامَل كأنه لا نهاية له.
  Future<List<StatusHistoryEntry>> overlapping(
    int employeeId,
    String from,
    String to,
  ) async {
    final String f = _isoDate(from);
    final String t = _isoDate(to);
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE h.${Db.cEmployeeId} = ? '
      'AND h.${Db.cStartDate} <= ? '
      'AND (h.${Db.cEndDate} IS NULL OR h.${Db.cEndDate} >= ?) '
      'ORDER BY h.${Db.cStartDate} DESC, h.${Db.cId} DESC',
      <Object?>[employeeId, t, f],
    );
    return rows.map(StatusHistoryEntry.fromMap).toList();
  }

  /// السجل المفتوح (`end_date IS NULL`) إن وُجد.
  Future<StatusHistoryEntry?> openEntry(int employeeId) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_select WHERE h.${Db.cEmployeeId} = ? AND h.${Db.cEndDate} IS NULL '
      'ORDER BY h.${Db.cStartDate} DESC LIMIT 1',
      <Object?>[employeeId],
    );
    return rows.isEmpty ? null : StatusHistoryEntry.fromMap(rows.first);
  }

  Future<StatusHistoryEntry> byId(int id) async {
    final List<Map<String, Object?>> rows =
        await _db.rawQuery('$_select WHERE h.${Db.cId} = ?', <Object?>[id]);
    if (rows.isEmpty) {
      throw const AppException('سجل الوضعية غير موجود.');
    }
    return StatusHistoryEntry.fromMap(rows.first);
  }

  // ── الكتابة ─────────────────────────────────────────────────

  /// يضيف سجل وضعية جديداً.
  ///
  /// **لا يغلق أي سجل مفتوح تلقائياً** — ذلك تغيير ضمني ممنوع
  /// (D-007). استعمل [endOpenEntry] صراحة.
  Future<StatusHistoryEntry> add({
    required int employeeId,
    required int statusTypeId,
    required String startDate,
    String? endDate,
    String? notes,
  }) async {
    final ({String start, String? end}) r = _range(startDate, endDate);
    await _requireRow(Db.employees, employeeId, 'الموظف غير موجود.');
    await _requireRow(Db.statusTypes, statusTypeId, 'الوضعية غير موجودة.');

    final String now = _now();
    final int id = await _db.insert(
      Db.statusHistory,
      <String, Object?>{
        Db.cEmployeeId: employeeId,
        Db.cStatusTypeId: statusTypeId,
        Db.cStartDate: r.start,
        Db.cEndDate: r.end,
        Db.cNotes: notes,
        Db.cCreatedAt: now,
        Db.cUpdatedAt: now,
      },
    );
    return byId(id);
  }

  /// يعدّل سجلاً قائماً (التواريخ/الوضعية/الملاحظات) — بلا حذف.
  Future<void> updateEntry(StatusHistoryEntry entry) async {
    if (entry.id == null) {
      throw const AppException('سجل الوضعية غير محفوظ بعد.');
    }
    final ({String start, String? end}) r = _range(entry.startDate, entry.endDate);
    await _requireRow(Db.statusTypes, entry.statusTypeId, 'الوضعية غير موجودة.');

    await _db.update(
      Db.statusHistory,
      <String, Object?>{
        Db.cStatusTypeId: entry.statusTypeId,
        Db.cStartDate: r.start,
        Db.cEndDate: r.end,
        Db.cNotes: entry.notes,
        Db.cUpdatedAt: _now(),
      },
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[entry.id],
    );
  }

  /// يغلق سجلاً بكتابة `end_date` — **لا يحذفه**.
  Future<void> closeEntry(int id, String endDate) async {
    final String e = _isoDate(endDate);
    final List<Map<String, Object?>> rows = await _db.query(
      Db.statusHistory,
      columns: <String>[Db.cStartDate],
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AppException('سجل الوضعية غير موجود.');
    }
    final String start = (rows.first[Db.cStartDate] as String?) ?? e;
    if (e.compareTo(start) < 0) {
      throw const AppException('تاريخ النهاية قبل تاريخ البداية.');
    }
    await _db.update(
      Db.statusHistory,
      <String, Object?>{Db.cEndDate: e, Db.cUpdatedAt: _now()},
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// يغلق **كل** السجلات المفتوحة لموظف حتى [endDate].
  ///
  /// يُرجع `true` إن أُغلق سجل واحد على الأقل.
  Future<bool> endOpenEntry(int employeeId, String endDate) async {
    final String e = _isoDate(endDate);
    // `rawUpdate` لا `update`: الجملة تحتاج `SET` بلا اسم جدول
    // مُرقَّم، والصفوف تُفلَتر بالعمود نفسه.
    final int n = await _db.rawUpdate(
      'UPDATE ${Db.statusHistory} SET ${Db.cEndDate} = ?, '
      '${Db.cUpdatedAt} = ? '
      'WHERE ${Db.cEmployeeId} = ? '
      'AND (${Db.cEndDate} IS NULL OR ${Db.cEndDate} > ?)',
      <Object?>[e, _now(), employeeId, e],
    );
    return n > 0;
  }

  // ── الاشتقاق (D-006 / قاعدة 44) ────────────────────────────

  /// الوضعية السارية لموظف في [on] (اليوم افتراضياً).
  ///
  /// لا يوجد مرشّح → [ResolvedStatus.isEmpty]؛ تعادل أولوية داخل
  /// المصدر نفسه → `isAmbiguous` (لا تطبيق تلقائي، قاعدة 45).
  Future<ResolvedStatus> derived(int employeeId, {String? on}) async {
    final String date = _isoDate(on ?? AppDate.format(AppDate.today()));
    final Map<int, List<StatusCandidate>> byEmployee =
        await _candidates(employeeId: employeeId, date: date);
    final List<StatusCandidate> list = byEmployee[employeeId] ?? <StatusCandidate>[];
    return StatusResolver.resolve(list);
  }

  /// اشتقاق دفعة واحدة لكل الموظفين — **3 استعلامات فقط** مهما كثُر
  /// الموظفون (لا `N+1`)، ويُستعمل في اللوحة وقوائم النتائج.
  Future<Map<int, ResolvedStatus>> derivedForAll({String? on}) async {
    final String date = _isoDate(on ?? AppDate.format(AppDate.today()));
    final Map<int, List<StatusCandidate>> byEmployee =
        await _candidates(date: date);
    return byEmployee.map(
      (int id, List<StatusCandidate> list) =>
          MapEntry<int, ResolvedStatus>(id, StatusResolver.resolve(list)),
    );
  }

  /// يبني المرشّحين حسب ترتيب D-006 — 3 استعلامات، اختيارية التصفية.
  Future<Map<int, List<StatusCandidate>>> _candidates({
    required String date,
    int? employeeId,
  }) async {
    final Map<int, List<StatusCandidate>> out = <int, List<StatusCandidate>>{};
    void put(int empId, StatusCandidate c) =>
        out.putIfAbsent(empId, () => <StatusCandidate>[]).add(c);

    // 1) status_history السارية.
    final String hCond = employeeId == null ? '' : ' AND h.${Db.cEmployeeId} = ?';
    final List<Map<String, Object?>> hRows = await _db.rawQuery(
      '''
SELECT h.${Db.cEmployeeId} AS employee_id,
       h.${Db.cId} AS origin_id,
       h.${Db.cStartDate} AS start_date,
       h.${Db.cEndDate} AS end_date,
       st.${Db.cId} AS status_id,
       st.${Db.cName} AS name,
       st.${Db.cNameFr} AS name_fr,
       st.${Db.cPriority} AS priority
  FROM ${Db.statusHistory} h
  JOIN ${Db.statusTypes} st ON st.${Db.cId} = h.${Db.cStatusTypeId}
 WHERE st.${Db.cIsActive} = 1
   AND h.${Db.cStartDate} <= ?
   AND (h.${Db.cEndDate} IS NULL OR h.${Db.cEndDate} >= ?)$hCond
''',
      employeeId == null
          ? <Object?>[date, date]
          : <Object?>[date, date, employeeId],
    );
    for (final Map<String, Object?> m in hRows) {
      final String? end = m['end_date'] as String?;
      put(
        (m['employee_id'] as int?) ?? 0,
        StatusCandidate(
          statusTypeId: (m['status_id'] as int?) ?? 0,
          name: (m['name'] as String?) ?? '',
          nameFr: m['name_fr'] as String?,
          priority: (m['priority'] as int?) ?? 0,
          source: StatusSource.statusHistory,
          startDate: (m['start_date'] as String?) ?? '',
          endDate: end,
          originId: m['origin_id'] as int?,
          originLabel: '${AppDate.display(m['start_date'] as String?)} → '
              '${end == null ? 'مستمر' : AppDate.display(end)}',
        ),
      );
    }

    // 2) الرخص الجارية → وضعيتها عبر leave_types.status_type_id.
    final String lCond = employeeId == null ? '' : ' AND l.${Db.cEmployeeId} = ?';
    final List<Map<String, Object?>> lRows = await _db.rawQuery(
      '''
SELECT l.${Db.cEmployeeId} AS employee_id,
       l.${Db.cId} AS origin_id,
       l.${Db.cStartDate} AS start_date,
       l.${Db.cEndDate} AS end_date,
       lt.${Db.cNameAr} AS leave_name,
       st.${Db.cId} AS status_id,
       st.${Db.cName} AS name,
       st.${Db.cNameFr} AS name_fr,
       st.${Db.cPriority} AS priority
  FROM ${Db.leaves} l
  JOIN ${Db.leaveTypes} lt ON lt.${Db.cId} = l.${Db.cLeaveTypeId}
  JOIN ${Db.statusTypes} st ON st.${Db.cId} = lt.${Db.cStatusTypeId}
 WHERE l.${Db.cIsCancelled} = 0
   AND st.${Db.cIsActive} = 1
   AND l.${Db.cStartDate} <= ? AND l.${Db.cEndDate} >= ?$lCond
''',
      employeeId == null
          ? <Object?>[date, date]
          : <Object?>[date, date, employeeId],
    );
    for (final Map<String, Object?> m in lRows) {
      final String? start = m['start_date'] as String?;
      final String? end = m['end_date'] as String?;
      put(
        (m['employee_id'] as int?) ?? 0,
        StatusCandidate(
          statusTypeId: (m['status_id'] as int?) ?? 0,
          name: (m['name'] as String?) ?? '',
          nameFr: m['name_fr'] as String?,
          priority: (m['priority'] as int?) ?? 0,
          source: StatusSource.leave,
          startDate: start ?? '',
          endDate: end,
          originId: m['origin_id'] as int?,
          originLabel: '${(m['leave_name'] as String?) ?? 'رخصة'}: '
              '${AppDate.display(start)} → ${AppDate.display(end)}',
        ),
      );
    }

    // 3) الوضعية المسجَّلة للموظف — آخر ملجأ.
    final String eCond = employeeId == null ? '' : ' AND e.${Db.cId} = ?';
    final List<Map<String, Object?>> eRows = await _db.rawQuery(
      '''
SELECT e.${Db.cId} AS employee_id,
       e.${Db.cCreatedAt} AS start_date,
       st.${Db.cId} AS status_id,
       st.${Db.cName} AS name,
       st.${Db.cNameFr} AS name_fr,
       st.${Db.cPriority} AS priority
  FROM ${Db.employees} e
  JOIN ${Db.statusTypes} st ON st.${Db.cId} = e.${Db.cStatusId}
 WHERE e.${Db.cIsActive} = 1
   AND e.${Db.cStatusId} IS NOT NULL
   AND st.${Db.cIsActive} = 1$eCond
''',
      employeeId == null ? const <Object?>[] : <Object?>[employeeId],
    );
    for (final Map<String, Object?> m in eRows) {
      put(
        (m['employee_id'] as int?) ?? 0,
        StatusCandidate(
          statusTypeId: (m['status_id'] as int?) ?? 0,
          name: (m['name'] as String?) ?? '',
          nameFr: m['name_fr'] as String?,
          priority: (m['priority'] as int?) ?? 0,
          source: StatusSource.employeeDefault,
          startDate: (m['start_date'] as String?) ?? '',
          originId: m['employee_id'] as int?,
          originLabel: 'الوضعية المسجَّلة في ملف الموظف',
        ),
      );
    }

    return out;
  }

  // ── أدوات ───────────────────────────────────────────────────

  /// يوحّد التاريخ إلى `YYYY-MM-DD` ويرمي رسالة عربية عند الخطأ.
  ///
  /// المنطق كله في [DateInput] — لا نسخة ثانية من الرسالة.
  static String _isoDate(String raw) => DateInput.iso(raw);

  /// يوحّد الفترة ويرمي إن كانت النهاية قبل البداية.
  static ({String start, String? end}) _range(String start, String? end) {
    final String s = _isoDate(start);
    final String? e =
        (end == null || end.trim().isEmpty) ? null : _isoDate(end);
    if (e != null && e.compareTo(s) < 0) {
      throw const AppException('تاريخ النهاية قبل تاريخ البداية.');
    }
    return (start: s, end: e);
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
}
