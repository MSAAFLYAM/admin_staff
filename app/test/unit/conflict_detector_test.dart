import 'package:admin_staff/models/leave.dart';
import 'package:admin_staff/models/status_type.dart';
import 'package:admin_staff/services/conflict_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات Rule 45 / D-007 — كشف التعارض.
///
/// **لا حفظ ولا قاعدة بيانات:** كل الاختبارات على منطق نقي،
/// لأن القاعدة "يُعرض ولا يُطبَّق تلقائياً" يجب أن تُختبر مطلقة.
Leave _leave({
  int? id,
  int employeeId = 1,
  String start = '2026-10-03',
  String end = '2026-10-05',
  String? type = 'رخصة مرضية',
  bool cancelled = false,
}) =>
    Leave(
      id: id,
      employeeId: employeeId,
      leaveTypeId: 1,
      startDate: start,
      endDate: end,
      leaveTypeName: type,
      isCancelled: cancelled,
    );

StatusHistoryEntry _status({
  int? id,
  int employeeId = 1,
  int statusTypeId = 6,
  String start = '2026-10-01',
  String? end,
  String? name = 'موقوف',
}) =>
    StatusHistoryEntry(
      id: id,
      employeeId: employeeId,
      statusTypeId: statusTypeId,
      startDate: start,
      endDate: end,
      statusName: name,
    );

void main() {
  group('P1 حساب فترة التداخل', () {
    test('فترتان متباعدتان → null', () {
      expect(
        ConflictDetector.overlapOf(
          aStart: '2026-10-01',
          aEnd: '2026-10-05',
          bStart: '2026-10-06',
          bEnd: '2026-10-10',
        ),
        isNull,
      );
    });

    test('تداخل جزئي → الحد الأقصى من البدايات حتى الأدنى من النهايات', () {
      final ({String start, String? end})? o = ConflictDetector.overlapOf(
        aStart: '2026-10-01',
        aEnd: '2026-10-10',
        bStart: '2026-10-08',
        bEnd: '2026-10-20',
      );
      expect(o, isNotNull);
      expect(o!.start, '2026-10-08');
      expect(o.end, '2026-10-10');
    });

    test('تلامس في يوم واحد = تداخل (الفترتان شاملتان)', () {
      final ({String start, String? end})? o = ConflictDetector.overlapOf(
        aStart: '2026-10-01',
        aEnd: '2026-10-05',
        bStart: '2026-10-05',
        bEnd: '2026-10-09',
      );
      expect(o, isNotNull);
      expect(o!.start, '2026-10-05');
      expect(o.end, '2026-10-05');
    });

    test('طرف مفتوح (end = null) → التداخل يمتد حتى نهاية الطرف الآخر', () {
      final ({String start, String? end})? o = ConflictDetector.overlapOf(
        aStart: '2026-10-01',
        aEnd: null,
        bStart: '2026-10-08',
        bEnd: '2026-10-12',
      );
      expect(o!.start, '2026-10-08');
      expect(o.end, '2026-10-12');
    });

    test('الطرفان مفتوحان → تداخل مفتوح بلا نهاية', () {
      final ({String start, String? end})? o = ConflictDetector.overlapOf(
        aStart: '2026-10-01',
        aEnd: null,
        bStart: '2026-10-08',
        bEnd: null,
      );
      expect(o!.start, '2026-10-08');
      expect(o.end, isNull, reason: 'null = لا نهاية');
    });

    test('طرف مفتوح يبدأ بعد نهاية الطرف الآخر → لا تداخل', () {
      expect(
        ConflictDetector.overlapOf(
          aStart: '2026-10-01',
          aEnd: '2026-10-05',
          bStart: '2026-10-06',
          bEnd: null,
        ),
        isNull,
      );
    });

    test('تاريخ نهاية فارغ يُعامَل كمفتوح', () {
      final ({String start, String? end})? o = ConflictDetector.overlapOf(
        aStart: '2026-10-01',
        aEnd: '   ',
        bStart: '2026-10-02',
        bEnd: '2026-10-03',
      );
      expect(o, isNotNull);
      expect(o!.end, '2026-10-03');
    });
  });

  group('P2 رخصة جديدة مقابل رخص قائمة', () {
    test('تداخل واحد → تعارض واحد بالعنوان المطلوب', () {
      final List<DetectedConflict> c = ConflictDetector.checkLeave(
        _leave(start: '2026-10-04', end: '2026-10-06'),
        leaves: <Leave>[
          _leave(id: 9, start: '2026-10-01', end: '2026-10-05'),
        ],
      );
      expect(c, hasLength(1));
      expect(c.single.kind, ConflictKind.leaveVsLeave);
      expect(ConflictDetector.title, 'Conflict Detected');
      expect(c.single.message, contains('تعارض'));
      expect(c.single.message, contains('فترة التداخل'));
      expect(c.single.overlapStart, '2026-10-04');
      expect(c.single.overlapEnd, '2026-10-05');
      expect(c.single.overlapLabel, '04/10/2026 → 05/10/2026');
      expect(c.single.existingLabel, contains('رخصة مرضية'));
      expect(c.single.newLabel, contains('06/10/2026'));
    });

    test('لا تداخل → لا تعارض', () {
      expect(
        ConflictDetector.checkLeave(
          _leave(start: '2026-11-01', end: '2026-11-05'),
          leaves: <Leave>[
            _leave(id: 9, start: '2026-10-01', end: '2026-10-05'),
          ],
        ),
        isEmpty,
      );
    });

    test('الرخص الملغاة تُتجاهل (is_cancelled = 1)', () {
      expect(
        ConflictDetector.checkLeave(
          _leave(start: '2026-10-04', end: '2026-10-06'),
          leaves: <Leave>[
            _leave(id: 9, start: '2026-10-01', end: '2026-10-05', cancelled: true),
          ],
        ),
        isEmpty,
      );
    });

    test('السجل نفسه لا يعارض ذاته', () {
      expect(
        ConflictDetector.checkLeave(
          _leave(id: 42, start: '2026-10-04', end: '2026-10-06'),
          leaves: <Leave>[
            _leave(id: 42, start: '2026-10-01', end: '2026-10-30'),
          ],
        ),
        isEmpty,
      );
    });

    test('عدة تداخلات → عدة تعارضات', () {
      final List<DetectedConflict> c = ConflictDetector.checkLeave(
        _leave(start: '2026-10-04', end: '2026-10-06'),
        leaves: <Leave>[
          _leave(id: 1, start: '2026-10-01', end: '2026-10-05'),
          _leave(id: 2, start: '2026-10-05', end: '2026-10-20'),
          _leave(id: 3, start: '2026-11-01', end: '2026-11-05'),
        ],
      );
      expect(c, hasLength(2));
      expect(ConflictDetector.hasConflict(c), isTrue);
      expect(ConflictDetector.hasConflict(const <DetectedConflict>[]), isFalse);
    });
  });

  group('P3 رخصة جديدة مقابل سجل الوضعيات', () {
    test('وضعية مفتوحة تغطي الرخصة → conflict من نوع leaveVsStatus', () {
      final List<DetectedConflict> c = ConflictDetector.checkLeave(
        _leave(start: '2026-10-04', end: '2026-10-06'),
        history: <StatusHistoryEntry>[
          _status(id: 1, start: '2026-10-01', end: null, name: 'موقوف'),
        ],
      );
      expect(c, hasLength(1));
      expect(c.single.kind, ConflictKind.leaveVsStatus);
      expect(c.single.overlapEnd, '2026-10-06', reason: 'الطرف الآخر مغلق');
      expect(c.single.message, contains('سجل الوضعيات'));
      expect(c.single.existingLabel, contains('مستمر'));
    });

    test('وضعية منتهية قبل الرخصة → لا تعارض', () {
      expect(
        ConflictDetector.checkLeave(
          _leave(start: '2026-10-04', end: '2026-10-06'),
          history: <StatusHistoryEntry>[
            _status(id: 1, start: '2026-09-01', end: '2026-10-01'),
          ],
        ),
        isEmpty,
      );
    });
  });

  group('P4 وضعية جديدة مقابل ما هو موجود', () {
    test('تداخل مع وضعية قائمة → statusVsStatus', () {
      final List<DetectedConflict> c = ConflictDetector.checkStatus(
        _status(id: 10, start: '2026-10-05', end: '2026-10-12', name: 'في الخدمة'),
        history: <StatusHistoryEntry>[
          _status(id: 7, start: '2026-10-01', end: '2026-10-06', name: 'موقوف'),
        ],
      );
      expect(c, hasLength(1));
      expect(c.single.kind, ConflictKind.statusVsStatus);
      expect(c.single.overlapLabel, '05/10/2026 → 06/10/2026');
      expect(c.single.message, contains('الوضعية الجديدة'));
    });

    test('تداخل مع رخصة جارية → statusVsLeave برسالة صحيحة', () {
      final List<DetectedConflict> c = ConflictDetector.checkStatus(
        _status(start: '2026-10-05', end: '2026-10-12'),
        leaves: <Leave>[
          _leave(id: 3, start: '2026-10-01', end: '2026-10-06'),
        ],
      );
      expect(c, hasLength(1));
      expect(c.single.kind, ConflictKind.statusVsLeave);
      expect(c.single.message, contains('رخصة جارية'));
      expect(c.single.overlapStart, '2026-10-05');
      expect(c.single.overlapEnd, '2026-10-06');
    });

    test('التعارض من الجدولين لا يُكتشف بالمقارنة بين المعرّفات', () {
      // معرّف سجل الوضعية 3 ومعرّف الرخصة 3 — جدولان مختلفان.
      final List<DetectedConflict> c = ConflictDetector.checkStatus(
        _status(id: 3, start: '2026-10-05', end: '2026-10-12'),
        leaves: <Leave>[
          _leave(id: 3, start: '2026-10-01', end: '2026-10-06'),
        ],
      );
      expect(c, hasLength(1), reason: 'لا تُلغَ المقارنة لمجرّد تساوي المعرّف');
    });

    test('نفس المعرّف داخل الجدول نفسه يُتجاهل', () {
      expect(
        ConflictDetector.checkStatus(
          _status(id: 5, start: '2026-10-05', end: '2026-10-12'),
          history: <StatusHistoryEntry>[
            _status(id: 5, start: '2026-10-01', end: '2026-10-30'),
          ],
        ),
        isEmpty,
      );
    });

    test('لا مدخلات → لا تعارض', () {
      expect(ConflictDetector.checkStatus(_status()), isEmpty);
      expect(ConflictDetector.checkLeave(_leave()), isEmpty);
    });
  });

  group('P5 عرض التعارض', () {
    test('نطاق مفتوح يظهر «مفتوح»', () {
      final List<DetectedConflict> c = ConflictDetector.checkStatus(
        _status(start: '2026-10-05', end: null),
        history: <StatusHistoryEntry>[
          _status(id: 1, start: '2026-10-01', end: '2026-10-06'),
        ],
      );
      expect(c.single.overlapEnd, '2026-10-06');
      expect(c.single.overlapLabel, '05/10/2026 → 06/10/2026');
    });

    test('تسميات الأنواع والوصف', () {
      expect(ConflictKind.leaveVsLeave.label, contains('رخصة'));
      expect(ConflictKind.statusVsStatus.label, contains('وضعية'));
      expect(
        ConflictDetector.statusLabel(
          _status(start: '2026-10-01', end: null, name: 'موقوف'),
        ),
        contains('مستمر'),
      );
      expect(
        ConflictDetector.leaveLabel(
          _leave(start: '2026-10-01', end: '2026-10-03', type: null),
        ),
        contains('رخصة'),
        reason: 'نوع فارغ → اسم افتراضي',
      );
      expect(
        ConflictDetector.checkLeave(
          _leave(start: '2026-10-04', end: '2026-10-06'),
          leaves: <Leave>[
            _leave(id: 9, start: '2026-10-01', end: '2026-10-05'),
          ],
        ).single.toString(),
        contains('DetectedConflict'),
      );
    });
  });
}
