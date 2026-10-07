import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/utils/app_date.dart';
import '../core/utils/date_input.dart';
import '../services/status_resolver.dart';
import 'status_repository.dart';

/// لقطة اللوحة الرئيسية — كل الأرقام لحظة واحدة لا استعلاماً لكل
/// بطاقة (لا `N+1`).
///
/// الترتيب المعلن للواجهة: `statusCounts` مرتَّبة تنازلياً حسب
/// العدد، والمفتاح `0` يعني «بلا وضعية» (للموظف الذي لا مصدر له).
class DashboardSummary {
  const DashboardSummary({
    required this.date,
    required this.totalEmployees,
    required this.archivedCount,
    required this.statusCounts,
    required this.ambiguousCount,
    required this.todaysPermanence,
    required this.unmatchedToday,
    required this.leavesEndingToday,
    required this.leavesEndingTomorrow,
    required this.leavesEndingIn3Days,
    required this.returningToday,
  });

  /// اليوم الذي أُخذت عنه اللقطة — `YYYY-MM-DD`.
  final String date;

  /// الموظفون **النشطون** (`is_active = 1`).
  final int totalEmployees;

  /// المعطَّلون — يعرضون في «السجلات الموقوفة» لا في التفاصيل.
  final int archivedCount;

  /// `status_type_id` ← العدد (اشتقاق اليوم). المفتاح `0` = بلا وضعية.
  final Map<int, int> statusCounts;

  /// من اشتقاهم متعارضين اليوم (`Conflict Detected`) → تنبيه.
  final int ambiguousCount;

  final int todaysPermanence;

  /// مداومة اليوم غير المربوطة بموظف → تنبيه «حاجة ربط».
  final int unmatchedToday;

  final int leavesEndingToday;
  final int leavesEndingTomorrow;
  final int leavesEndingIn3Days;

  /// الرخص التي `return_date` = اليوم.
  final int returningToday;

  /// إجمالي تنبيهات اليوم = التعارضات + غير المطابَق.
  int get alerts => ambiguousCount + unmatchedToday;

  bool get hasNoPermanenceToday => todaysPermanence == 0;
  bool get hasNoAlerts => alerts == 0;

  /// أقوى `[n]` وضعيات للعرض المصغّر — ترتيب تصاعدي حسب العدد
  /// و**بلا تفضيل معلن** في الكود: الترتيب من البيانات.
  List<MapEntry<int, int>> topStatuses(int n) {
    final List<MapEntry<int, int>> sorted = statusCounts.entries.toList()
      ..sort((MapEntry<int, int> a, MapEntry<int, int> b) {
        final int byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key); // تعادل → رقم الوضعية ثابت
      });
    return sorted.take(n).toList();
  }

  /// بقية الوضعيات خارج [topStatuses] (للعرض خلف «أخرى»).
  int othersCount(int n) {
    final List<MapEntry<int, int>> top = topStatuses(n);
    if (top.length >= statusCounts.length) return 0;
    int inTop = 0;
    for (final MapEntry<int, int> e in top) {
      inTop += e.value;
    }
    int sum = 0;
    for (final int v in statusCounts.values) {
      sum += v;
    }
    return sum - inTop;
  }

  @override
  String toString() => 'DashboardSummary($date, active=$totalEmployees, '
      'permanence=$todaysPermanence, alerts=$alerts)';
}

/// ★ مستودع اللوحة (التابلونة).
///
/// **كل شيء مشتق من الجداول** — لا رقم مُثبَّت في الكود (قاعدة
/// 17/84): عدد حالات «في الخدمة» يحدده `status_types.priority` +
/// `status_history`، وعدد المداومة يحدده جدول `permanence` لليوم.
///
/// الاستعلامات محدودة ومقروءة: لقطة واحدة = استعلامات معدودة،
/// وكلها على فهارس `date` / `end_date` / `return_date` /
/// `is_active`.
class DashboardRepository {
  DashboardRepository(this._database, this._statuses);

  final AppDatabase _database;

  /// الاشتقاق (3 استعلامات) لا يُعاد بناؤه هنا.
  final StatusRepository _statuses;

  Database get _db => _database.db;

  /// لقطة اليوم (أو يوم آخر للتقارير التاريخية).
  Future<DashboardSummary> summary({String? on}) async {
    final String date = DateInput.iso(on ?? AppDate.format(AppDate.today()));
    final DateTime day = AppDate.parseStrict(date);
    final String tomorrow = AppDate.format(AppDate.addDays(day, 1));
    final String inThree = AppDate.format(AppDate.addDays(day, 3));

    // ── 1) الموظفون: استعلام واحد يعطي العدّ ومعرّفات النشطين معاً ──
    int active = 0;
    int archived = 0;
    final Set<int> activeIds = <int>{};
    final List<Map<String, Object?>> empRows = await _db.query(
      Db.employees,
      columns: <String>[Db.cId, Db.cIsActive],
    );
    for (final Map<String, Object?> m in empRows) {
      if ((m[Db.cIsActive] as int?) == 1) {
        active++;
        activeIds.add(m[Db.cId] as int);
      } else {
        archived++;
      }
    }

    // ── 2) الوضعيات المشتقة لليوم ──
    //
    // يُستبعد من العدّ من ليس نشطاً: `status_history` قد يحمل
    // سجلاً مفتوحاً لموظف أُرشف، فلا يدخل عدّاد «في الخدمة».
    final Map<int, ResolvedStatus> derived =
        await _statuses.derivedForAll(on: date);
    final Map<int, int> tally = <int, int>{};
    int ambiguous = 0;
    for (final MapEntry<int, ResolvedStatus> e in derived.entries) {
      if (!activeIds.contains(e.key)) continue;
      if (e.value.isAmbiguous) ambiguous++;
      if (e.value.isEmpty) continue;
      final int key = e.value.statusTypeId;
      tally[key] = (tally[key] ?? 0) + 1;
    }
    int covered = 0;
    for (final int v in tally.values) {
      covered += v;
    }
    final int noStatus = activeIds.length - covered;
    if (noStatus > 0) tally[0] = noStatus;

    // ── 3) مداومة اليوم: القائمة وغير المربوط في استعلام واحد ──
    final List<Map<String, Object?>> permRows = await _db.rawQuery(
      'SELECT COUNT(*) AS n, '
      'COALESCE(SUM(CASE WHEN ${Db.cEmployeeId} IS NULL '
      'THEN 1 ELSE 0 END), 0) AS u '
      'FROM ${Db.permanence} WHERE ${Db.cDate} = ?',
      <Object?>[date],
    );
    final int permanence = (permRows.first['n'] as int?) ?? 0;
    final int unmatched = (permRows.first['u'] as int?) ?? 0;

    // ── 4) الرخص المنتهية اليوم/غداً/بعد 3 أيام ──
    final Map<String, int> ending = <String, int>{};
    final List<Map<String, Object?>> endRows = await _db.rawQuery(
      'SELECT ${Db.cEndDate} AS d, COUNT(*) AS n FROM ${Db.leaves} '
      'WHERE ${Db.cIsCancelled} = 0 AND ${Db.cEndDate} IN (?, ?, ?) '
      'GROUP BY ${Db.cEndDate}',
      <Object?>[date, tomorrow, inThree],
    );
    for (final Map<String, Object?> m in endRows) {
      ending[m['d'] as String] = (m['n'] as int?) ?? 0;
    }

    // ── 5) العائدون اليوم ──
    final List<Map<String, Object?>> backRows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${Db.leaves} '
      'WHERE ${Db.cIsCancelled} = 0 AND ${Db.cReturnDate} = ?',
      <Object?>[date],
    );
    final int returning = (backRows.first['n'] as int?) ?? 0;

    return DashboardSummary(
      date: date,
      totalEmployees: active,
      archivedCount: archived,
      statusCounts: tally,
      ambiguousCount: ambiguous,
      todaysPermanence: permanence,
      unmatchedToday: unmatched,
      leavesEndingToday: ending[date] ?? 0,
      leavesEndingTomorrow: ending[tomorrow] ?? 0,
      leavesEndingIn3Days: ending[inThree] ?? 0,
      returningToday: returning,
    );
  }

  /// تجميع سريع: عدد الموظفين لكل قسم — للتقارير ولوحة القسم.
  ///
  /// المعطَّلون خارج العد إن [activeOnly] (الافتراضي) — لأن
  /// التقرير «بالقسم» يعرض من في الخدمة لا من أُرشف.
  Future<List<({int? sectionId, String name, int count})>> bySection({
    bool activeOnly = true,
  }) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
SELECT e.${Db.cSectionId} AS sid,
       COALESCE(s.${Db.cName}, s.${Db.cNameAr}, '') AS name,
       COUNT(*) AS n
  FROM ${Db.employees} e
  LEFT JOIN ${Db.sections} s ON s.${Db.cId} = e.${Db.cSectionId}
 ${activeOnly ? 'WHERE e.${Db.cIsActive} = 1' : ''}
 GROUP BY e.${Db.cSectionId}
 ORDER BY n DESC, name ASC''',
    );
    return <({int? sectionId, String name, int count})>[
      for (final Map<String, Object?> m in rows)
        (
          sectionId: m['sid'] as int?,
          name: (m['name'] as String?) ?? '',
          count: (m['n'] as int?) ?? 0,
        ),
    ];
  }
}
