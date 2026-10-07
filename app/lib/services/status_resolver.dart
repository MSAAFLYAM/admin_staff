/// ★ مصدر المرشّح — ترتيب الاشتقاق حسب **D-006 / قاعدة 44**.
///
/// البيانات الزمنية هي مصدر الحقيقة، لا النص المخزَّن في الموظف،
/// لذا تُشتقّ الوضعية بهذه الأسبقية:
///
/// 1. `status_history` سارية في التاريخ المستهدف
/// 2. `leaves` سارية (نوعها يحدّد الوضعية عبر `leave_types.status_type_id`)
/// 3. `employees.current_status_id` — الوضعية الافتراضية المسجَّلة
///
/// لا يوجد أي رقم ثابت هنا: `priority` يأتي من `status_types`
/// وهو قابل للتعديل من واجهة الإدارة (قاعدة 13 و84).
enum StatusSource {
  statusHistory(0, 'سجل الوضعيات'),
  leave(1, 'رخصة جارية'),
  employeeDefault(2, 'الوضعية المسجَّلة');

  const StatusSource(this.rank, this.label);

  /// الأصغر يسبق في الاشتقاق (0 = الأسبق).
  final int rank;

  /// وصف عربي مختصر يُعرض للمستخدم ليعرف **لماذا** اشتُقّت هذه الوضعية.
  final String label;
}

/// مرشّح واحد قد يغطّي التاريخ المستهدف.
///
/// عدة مرشّحين قد يتنافسون؛ الفيصل بينهم `priority` من `status_types`.
class StatusCandidate {
  const StatusCandidate({
    required this.statusTypeId,
    required this.name,
    required this.source,
    this.nameFr,
    this.priority = 0,
    this.startDate = '',
    this.endDate,
    this.originId,
    this.originLabel,
  });

  final int statusTypeId;
  final String name;
  final String? nameFr;
  final int priority;
  final StatusSource source;

  /// بداية الفترة التي يغطّيها المرشّح (`YYYY-MM-DD`).
  final String startDate;

  /// نهايتها، أو `null` = مستمر.
  final String? endDate;

  /// معرّف السجل المنبع (سطر `status_history` / `leaves` / الموظف).
  final int? originId;

  /// وصف السجل المنبع لعرضه في شاشة الاشتقاق.
  final String? originLabel;

  String get displayName => name;
  String get displayNameFr => (nameFr?.trim().isNotEmpty ?? false) ? nameFr! : name;

  @override
  String toString() =>
      'StatusCandidate(${source.name}#$statusTypeId p=$priority $startDate)';
}

/// نتيجة الاشتقاق لتاريخ معيّن.
class ResolvedStatus {
  const ResolvedStatus({
    required this.candidates,
    this.winner,
    this.isAmbiguous = false,
  });

  /// كل المرشّحين، **مرتّبين** بترتيب الاشتقاق.
  final List<StatusCandidate> candidates;

  /// المرشّح الفائز — أو `null` حين لا يوجد أي مرشّح.
  final StatusCandidate? winner;

  /// `true` = مرشّحان مختلفان **من المصدر نفسه** بأولوية متساوية.
  ///
  /// عندها لا يجوز اختيار أحدهما تلقائياً (قاعدة 45): تعرض الواجهة
  /// `Conflict Detected` وتترك القرار للمستخدم.
  final bool isAmbiguous;

  bool get isEmpty => winner == null;
  bool get isResolved => winner != null;

  /// `0` حين لا يوجد مرشّح.
  int get statusTypeId => winner?.statusTypeId ?? 0;

  /// اسم الوضعية الفائزة (عربي) — أو نص فارغ.
  String get label => winner?.name ?? '';

  /// من أين اشتُقّت الوضعية (`سجل الوضعيات` / `رخصة جارية` / …).
  String get sourceLabel => winner?.source.label ?? '';

  /// عدد المرشّحين المنافسين في نفس المستوى الأول.
  int get topCount => candidates
      .where((StatusCandidate c) => c.source == winner?.source)
      .where((StatusCandidate c) => c.priority == winner?.priority)
      .length;
}

/// ★ مُشتقّ الوضعية الإدارية (D-006) — **منطق نقي بلا قاعدة بيانات**.
///
/// كل الإدخالات قوائم مرشّحين جاهزة، فيُختبر بلا SQLite ولا محاكي.
///
/// قواعد الفرز، بالترتيب:
/// 1. المصدر (سجل الوضعيات ← الرخصة ← الوضعية المسجَّلة)
/// 2. `priority` تنازلياً — الأعلى يغلب عند التداخل (قاعدة 84)
/// 3. أحدث `start_date` أولاً — عند تساوي المصدر والأولوية
/// 4. معرّف الحالة (تثبيت للمخرجات المتساوية)
abstract final class StatusResolver {
  static int _compare(StatusCandidate a, StatusCandidate b) {
    final int bySource = a.source.rank.compareTo(b.source.rank);
    if (bySource != 0) return bySource;

    final int byPriority = b.priority.compareTo(a.priority);
    if (byPriority != 0) return byPriority;

    final int byDate = b.startDate.compareTo(a.startDate);
    if (byDate != 0) return byDate;

    return a.statusTypeId.compareTo(b.statusTypeId);
  }

  /// يختار الوضعية السارية لتاريخ معيّن من بين [candidates].
  ///
  /// تُرجع `winner == null` عند غياب المرشّحين، و`isAmbiguous == true`
  /// عند تعادل الأولوية داخل المصدر نفسه.
  static ResolvedStatus resolve(Iterable<StatusCandidate> candidates) {
    final List<StatusCandidate> all = candidates.toList()..sort(_compare);
    if (all.isEmpty) {
      return const ResolvedStatus(candidates: <StatusCandidate>[]);
    }

    final StatusCandidate winner = all.first;
    final List<StatusCandidate> sameSource = all
        .where((StatusCandidate c) => c.source == winner.source)
        .toList(growable: false);

    int top = sameSource.first.priority;
    for (final StatusCandidate c in sameSource) {
      if (c.priority > top) top = c.priority;
    }

    final Set<int> tied = sameSource
        .where((StatusCandidate c) => c.priority == top)
        .map((StatusCandidate c) => c.statusTypeId)
        .toSet();

    return ResolvedStatus(
      candidates: all,
      winner: winner,
      isAmbiguous: tied.length > 1,
    );
  }

  /// اختصار: هل يوجد مرشّح على الإطلاق؟
  static bool hasAny(Iterable<StatusCandidate> candidates) =>
      candidates.isNotEmpty;
}
