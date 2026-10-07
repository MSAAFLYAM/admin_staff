import 'package:admin_staff/services/status_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات D-006 / قاعدة 44 — ترتيب الاشتقاق.
///
/// **الأهم هنا ليس "أي فائز" بل "لماذا":** المصدر يسبق الأولوية،
/// والأولوية (من `status_types` لا من الكود) تسبق الأحدث.
StatusCandidate _c({
  required int statusTypeId,
  required String name,
  required StatusSource source,
  int priority = 0,
  String start = '2026-10-01',
  String? end,
  int? originId,
}) =>
    StatusCandidate(
      statusTypeId: statusTypeId,
      name: name,
      source: source,
      priority: priority,
      startDate: start,
      endDate: end,
      originId: originId,
    );

void main() {
  group('R1 لا مرشّحين', () {
    test('قائمة فارغة → لا فائز وحالة فارغة', () {
      final ResolvedStatus r = StatusResolver.resolve(const <StatusCandidate>[]);
      expect(r.winner, isNull);
      expect(r.isEmpty, isTrue);
      expect(r.isResolved, isFalse);
      expect(r.label, '');
      expect(r.statusTypeId, 0);
      expect(r.sourceLabel, '');
      expect(r.isAmbiguous, isFalse);
      expect(r.candidates, isEmpty);
    });

    test('hasAny تفرّق بين الفراغ والقيمة', () {
      expect(StatusResolver.hasAny(const <StatusCandidate>[]), isFalse);
      expect(
        StatusResolver.hasAny(<StatusCandidate>[
          _c(statusTypeId: 1, name: 'x', source: StatusSource.leave),
        ]),
        isTrue,
      );
    });
  });

  group('R2 المصدر يسبق الأولوية (D-006)', () {
    test('سجل الوضعيات يهزم الوضعية المسجَّلة ولو كان أولويتها 100', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 8,
          name: 'التقاعد',
          source: StatusSource.employeeDefault,
          priority: 100,
        ),
        _c(
          statusTypeId: 1,
          name: 'في الخدمة',
          source: StatusSource.statusHistory,
          priority: 0,
        ),
      ]);
      expect(r.label, 'في الخدمة');
      expect(r.sourceLabel, 'سجل الوضعيات');
      expect(r.winner?.source, StatusSource.statusHistory);
    });

    test('الرخصة الجارية تهزم الوضعية المسجَّلة', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 1,
          name: 'في الخدمة',
          source: StatusSource.employeeDefault,
          priority: 0,
        ),
        _c(
          statusTypeId: 4,
          name: 'رخصة مرضية',
          source: StatusSource.leave,
          priority: 30,
        ),
      ]);
      expect(r.label, 'رخصة مرضية');
      expect(r.winner?.source, StatusSource.leave);
    });

    test('سجل الوضعيات يهزم الرخصة الجارية', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 4,
          name: 'رخصة مرضية',
          source: StatusSource.leave,
          priority: 30,
        ),
        _c(
          statusTypeId: 1,
          name: 'في الخدمة',
          source: StatusSource.statusHistory,
          priority: 0,
        ),
      ]);
      expect(r.winner?.source, StatusSource.statusHistory);
      expect(r.label, 'في الخدمة');
    });
  });

  group('R3 الأولوية داخل المصدر نفسه (قاعدة 84)', () {
    test('الأولوية الأعلى تغلب — 90 فوق 0', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 1,
          name: 'في الخدمة',
          source: StatusSource.statusHistory,
          priority: 0,
          start: '2026-10-05',
        ),
        _c(
          statusTypeId: 6,
          name: 'موقوف',
          source: StatusSource.statusHistory,
          priority: 90,
          start: '2026-10-01',
        ),
      ]);
      expect(r.label, 'موقوف');
      expect(r.isAmbiguous, isFalse, reason: 'الأولويتان مختلفتان لا تعادل');
    });

    test('الأولوية 100 (تقاعد) تهزم 30 (مرضية)', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 4,
          name: 'رخصة مرضية',
          source: StatusSource.statusHistory,
          priority: 30,
        ),
        _c(
          statusTypeId: 8,
          name: 'التقاعد',
          source: StatusSource.statusHistory,
          priority: 100,
        ),
      ]);
      expect(r.label, 'التقاعد');
      expect(r.topCount, 1);
    });
  });

  group('R4 تساوي الأولوية → الأحدث أولاً', () {
    test('نفس المصدر ونفس الأولوية: الأحدث يفوز', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 2,
          name: 'عطلة إدارية',
          source: StatusSource.statusHistory,
          priority: 20,
          start: '2026-10-01',
        ),
        _c(
          statusTypeId: 3,
          name: 'رخصة استثنائية',
          source: StatusSource.statusHistory,
          priority: 20,
          start: '2026-10-09',
        ),
      ]);
      expect(r.label, 'رخصة استثنائية');
      expect(r.isAmbiguous, isTrue, reason: 'تعادل أولوية = لا تطبيق تلقائي');
    });

    test('المرشّحون في `candidates` مرتّبون بترتيب الاشتقاق', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 1,
          name: 'في الخدمة',
          source: StatusSource.employeeDefault,
          priority: 100,
        ),
        _c(
          statusTypeId: 6,
          name: 'موقوف',
          source: StatusSource.leave,
          priority: 10,
        ),
        _c(
          statusTypeId: 2,
          name: 'عطلة إدارية',
          source: StatusSource.statusHistory,
          priority: 0,
        ),
      ]);
      expect(
        r.candidates.map((StatusCandidate c) => c.source).toList(),
        <StatusSource>[
          StatusSource.statusHistory,
          StatusSource.leave,
          StatusSource.employeeDefault,
        ],
      );
      expect(r.winner?.name, 'عطلة إدارية', reason: 'المصدر يسبق الأولوية');
    });
  });

  group('R5 الغموض (قاعدة 45 — لا تطبيق تلقائي)', () {
    test('وضعيتان مختلفتان بأولوية متساوية → isAmbiguous', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 2,
          name: 'عطلة إدارية',
          source: StatusSource.statusHistory,
          priority: 20,
        ),
        _c(
          statusTypeId: 5,
          name: 'تصريف الإجازات',
          source: StatusSource.statusHistory,
          priority: 20,
        ),
      ]);
      expect(r.isAmbiguous, isTrue);
      expect(r.topCount, 2);
      expect(r.winner, isNotNull, reason: 'يُعرض المرشّح الأول مع التنبيه');
    });

    test('نفس الوضعية في سطرين = ليس غموضاً', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 2,
          name: 'عطلة إدارية',
          source: StatusSource.statusHistory,
          priority: 20,
          start: '2026-10-01',
        ),
        _c(
          statusTypeId: 2,
          name: 'عطلة إدارية',
          source: StatusSource.statusHistory,
          priority: 20,
          start: '2026-10-03',
        ),
      ]);
      expect(r.isAmbiguous, isFalse);
      expect(r.topCount, 2);
      expect(r.label, 'عطلة إدارية');
    });

    test('تعادل بين مصدرين مختلفين ليس غموضاً — المصدر يفصل', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 2,
          name: 'عطلة إدارية',
          source: StatusSource.leave,
          priority: 20,
        ),
        _c(
          statusTypeId: 5,
          name: 'تصريف الإجازات',
          source: StatusSource.statusHistory,
          priority: 20,
        ),
      ]);
      expect(r.isAmbiguous, isFalse);
      expect(r.winner?.source, StatusSource.statusHistory);
    });
  });

  group('R6 وصف المصدر للعرض', () {
    test('كل مرشّح يحمل وصف مصدره ووصف سجله المنبع', () {
      final StatusCandidate c = _c(
        statusTypeId: 4,
        name: 'رخصة مرضية',
        source: StatusSource.leave,
        originId: 77,
      );
      expect(c.source.label, 'رخصة جارية');
      expect(c.originId, 77);
      expect(c.displayName, 'رخصة مرضية');
      expect(c.displayNameFr, 'رخصة مرضية', reason: 'nameFr = null');
      expect(c.toString(), contains('leave'));
    });

    test('displayNameFr يفضّل الاسم الفرنسي عند وجوده', () {
      const StatusCandidate c = StatusCandidate(
        statusTypeId: 1,
        name: 'في الخدمة',
        nameFr: 'En service',
        source: StatusSource.employeeDefault,
      );
      expect(c.displayNameFr, 'En service');
      expect(c.displayName, 'في الخدمة');
    });

    test('sourceLabel منقول من الفائز', () {
      final ResolvedStatus r = StatusResolver.resolve(<StatusCandidate>[
        _c(
          statusTypeId: 1,
          name: 'في الخدمة',
          source: StatusSource.employeeDefault,
        ),
      ]);
      expect(r.sourceLabel, 'الوضعية المسجَّلة');
    });
  });
}
