import '../core/error/app_exception.dart';
import '../core/utils/app_date.dart';
import '../models/leave.dart';
import '../models/status_type.dart';

/// نوع التعارض المكتشف (Rule 45).
enum ConflictKind {
  leaveVsLeave('رخصة مع رخصة'),
  leaveVsStatus('رخصة مع وضعية'),
  statusVsLeave('وضعية مع رخصة'),
  statusVsStatus('وضعية مع وضعية');

  const ConflictKind(this.label);

  final String label;
}

/// تعارض مكتشف — يُعرض للمستخدم **قبل** الحفظ ولا يُطبَّق تلقائياً.
class DetectedConflict {
  const DetectedConflict({
    required this.kind,
    required this.message,
    required this.existingLabel,
    required this.newLabel,
    required this.overlapStart,
    this.overlapEnd,
  });

  final ConflictKind kind;

  /// رسالة عربية جاهزة للعرض (تشمل فترة التداخل).
  final String message;

  /// وصف السجل الموجود مسبقاً.
  final String existingLabel;

  /// وصف السجل المقترح حفظه.
  final String newLabel;

  /// أول يوم من التداخل (`YYYY-MM-DD`).
  final String overlapStart;

  /// آخر يوم من التداخل — `null` = التداخل مفتوح حتى ما لا نهاية له.
  final String? overlapEnd;

  /// فترة التداخل بصيغة العرض: `03/10/2026 → 05/10/2026`.
  String get overlapLabel {
    final String from = AppDate.display(overlapStart);
    if (overlapEnd == null) return '$from → مفتوح';
    return '$from → ${AppDate.display(overlapEnd)}';
  }

  @override
  String toString() => 'DetectedConflict(${kind.name}, $overlapLabel)';
}

/// ★ كاشف التعارضات (D-007 / Rule 45) — **منطق نقي بلا قاعدة بيانات**.
///
/// **القاعدة:** الاكتشاف يحدث قبل الحفظ، يعرض `Conflict Detected`
/// مع التفاصيل، **ولا يُطبَّق تلقائياً أبداً** — القرار للمستخدم.
///
/// كل التواريخ `YYYY-MM-DD` فالمقارنة نصّية مباشرة وصحيحة.
/// الطرف المفتوح (`end == null`) يُعامَل كأنه لا نهاية له.
abstract final class ConflictDetector {
  /// العنوان الذي تعرضه الواجهة فوق قائمة التعارضات.
  static const String title = 'Conflict Detected';

  /// فترة التداخل بين فترتين، أو `null` إن لم تتتالما.
  ///
  /// الفترتان شاملتان للطرفين: التلامس في يوم واحد = تداخل.
  static ({String start, String? end})? overlapOf({
    required String aStart,
    String? aEnd,
    required String bStart,
    String? bEnd,
  }) {
    final String? aEndClean = _clean(aEnd);
    final String? bEndClean = _clean(bEnd);

    final String start = aStart.compareTo(bStart) >= 0 ? aStart : bStart;

    final String? end;
    if (aEndClean == null && bEndClean == null) {
      end = null; // كلاهما مفتوح → التداخل يمتد للأبد.
    } else if (aEndClean == null) {
      end = bEndClean;
    } else if (bEndClean == null) {
      end = aEndClean;
    } else {
      end = aEndClean.compareTo(bEndClean) <= 0 ? aEndClean : bEndClean;
    }

    // بدأت إحداهما بعد نهاية الأخرى → لا تداخل.
    if (end != null && start.compareTo(end) > 0) return null;
    return (start: start, end: end);
  }

  // ── واجهات الاستدعاء ────────────────────────────────────────

  /// هل تتداخل [candidate] مع أي رخصة سارية أو وضعية في السجل؟
  ///
  /// لا تُؤخذ الرخص الملغاة (`is_cancelled = 1`) بعين الاعتبار.
  static List<DetectedConflict> checkLeave(
    Leave candidate, {
    List<Leave> leaves = const <Leave>[],
    List<StatusHistoryEntry> history = const <StatusHistoryEntry>[],
  }) {
    final List<DetectedConflict> out = <DetectedConflict>[];

    for (final Leave other in leaves) {
      if (other.isCancelled) continue;
      if (!_isOther(candidate.id, other.id)) continue;
      final DetectedConflict? c = _between(
        kind: ConflictKind.leaveVsLeave,
        existingLabel: leaveLabel(other),
        newLabel: leaveLabel(candidate),
        aStart: other.startDate,
        aEnd: other.endDate,
        bStart: candidate.startDate,
        bEnd: candidate.endDate,
      );
      if (c != null) out.add(c);
    }

    // `candidate` رخصة و`other` وضعية — جدولان مختلفان، فتعيُّن
    // المعرّفات بينهما لا يعني السجل نفسه.
    for (final StatusHistoryEntry other in history) {
      final DetectedConflict? c = _between(
        kind: ConflictKind.leaveVsStatus,
        existingLabel: statusLabel(other),
        newLabel: leaveLabel(candidate),
        aStart: other.startDate,
        aEnd: other.endDate,
        bStart: candidate.startDate,
        bEnd: candidate.endDate,
      );
      if (c != null) out.add(c);
    }

    return out;
  }

  /// هل تتداخل [candidate] مع أي رخصة سارية أو وضعية في السجل؟
  static List<DetectedConflict> checkStatus(
    StatusHistoryEntry candidate, {
    List<StatusHistoryEntry> history = const <StatusHistoryEntry>[],
    List<Leave> leaves = const <Leave>[],
  }) {
    final List<DetectedConflict> out = <DetectedConflict>[];

    for (final StatusHistoryEntry other in history) {
      if (!_isOther(candidate.id, other.id)) continue;
      final DetectedConflict? c = _between(
        kind: ConflictKind.statusVsStatus,
        existingLabel: statusLabel(other),
        newLabel: statusLabel(candidate),
        aStart: other.startDate,
        aEnd: other.endDate,
        bStart: candidate.startDate,
        bEnd: candidate.endDate,
      );
      if (c != null) out.add(c);
    }

    // جدولان مختلفان — لا مقارنة معرّفات هنا أيضاً.
    for (final Leave other in leaves) {
      if (other.isCancelled) continue;
      final DetectedConflict? c = _between(
        kind: ConflictKind.statusVsLeave,
        existingLabel: leaveLabel(other),
        newLabel: statusLabel(candidate),
        aStart: other.startDate,
        aEnd: other.endDate,
        bStart: candidate.startDate,
        bEnd: candidate.endDate,
      );
      if (c != null) out.add(c);
    }

    return out;
  }

  /// `true` إذا وُجد تعارض واحد على الأقل.
  static bool hasConflict(List<DetectedConflict> conflicts) => conflicts.isNotEmpty;

  // ── أدوات داخلية ────────────────────────────────────────────

  static String? _clean(String? end) =>
      end == null || end.trim().isEmpty ? null : end.trim();

  /// السجل نفسه ليس تعارضاً مع ذاته.
  static bool _isOther(int? a, int? b) => !(a != null && b != null && a == b);

  static DetectedConflict? _between({
    required ConflictKind kind,
    required String existingLabel,
    required String newLabel,
    required String aStart,
    required String? aEnd,
    required String bStart,
    required String? bEnd,
  }) {
    final ({String start, String? end})? o = overlapOf(
      aStart: aStart,
      aEnd: aEnd,
      bStart: bStart,
      bEnd: bEnd,
    );
    if (o == null) return null;

    return DetectedConflict(
      kind: kind,
      message: _message(kind, o.start, o.end),
      existingLabel: existingLabel,
      newLabel: newLabel,
      overlapStart: o.start,
      overlapEnd: o.end,
    );
  }

  static String _message(ConflictKind kind, String start, String? end) {
    final String range =
        end == null ? '${AppDate.display(start)} → مفتوح' : _range(start, end);

    switch (kind) {
      case ConflictKind.leaveVsLeave:
        return 'تعارض: الرخصة الجديدة تتداخل مع رخصة قائمة لنفس الموظف. '
            'فترة التداخل: $range.';
      case ConflictKind.leaveVsStatus:
        return 'تعارض: الرخصة الجديدة تتداخل مع وضعية مسجَّلة في '
            'سجل الوضعيات. فترة التداخل: $range.';
      case ConflictKind.statusVsLeave:
        return 'تعارض: الوضعية الجديدة تتداخل مع رخصة جارية. '
            'فترة التداخل: $range.';
      case ConflictKind.statusVsStatus:
        return 'تعارض: الوضعية الجديدة تتداخل مع وضعية قائمة. '
            'فترة التداخل: $range.';
    }
  }

  static String _range(String start, String end) =>
      '${AppDate.display(start)} → ${AppDate.display(end)}';

  /// وصف رخصة للعرض داخل رسالة التعارض.
  static String leaveLabel(Leave leave) {
    final String type =
        leave.displayTypeName.isEmpty ? 'رخصة' : leave.displayTypeName;
    return '$type: ${AppDate.display(leave.startDate)} → '
        '${AppDate.display(leave.endDate)}';
  }

  /// وصف وضعية للعرض داخل رسالة التعارض.
  static String statusLabel(StatusHistoryEntry entry) {
    final String name = entry.displayStatus.isEmpty ? 'وضعية' : entry.displayStatus;
    final String end = entry.isOpen ? 'مستمر' : AppDate.display(entry.endDate);
    return '$name: ${AppDate.display(entry.startDate)} → $end';
  }
}

/// تعارض يمنع الحفظ — يُرمى من مستودعات الكتابة عند وجود تعارض
/// **لم يؤكد عليه المستخدم بعد**.
///
/// تحمل [conflicts] القائمة كاملة لتعرضها الواجهة تحت عنوان
/// [ConflictDetector.title]، فالقرار بعدها للمستخدم وحده (Rule 45).
class ConflictException extends AppException {
  const ConflictException(this.conflicts, String message) : super(message);

  final List<DetectedConflict> conflicts;
}
