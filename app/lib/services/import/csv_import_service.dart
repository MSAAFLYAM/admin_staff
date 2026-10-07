import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/error/app_exception.dart';
import '../../core/utils/csv/csv_parser.dart';
import '../../core/utils/text_normalizer.dart';
import '../../models/audit_log_entry.dart';
import '../../models/employee.dart';
import '../../models/permanence_record.dart';
import '../../repositories/audit_repository.dart';
import '../../repositories/reference_repository.dart';
import '../csv_column_mapper.dart';
import 'employee_import_planner.dart';
import 'import_models.dart';
import 'permanence_import_planner.dart';

/// ★ خدمة الاستيراد (قواعد 9 و81..84).
///
/// المسار:
///   بايتات → [CsvParser] → [CsvColumnMapper] → مخطِّط → **معاينة**
///   → تأكيد المستخدم → `Transaction` واحدة → كتابة أو rollback كامل.
///
/// **لا تكتب أي شيء قبل التأكيد.**
class CsvImportService {
  CsvImportService(this._database, this._refs, this._audit);

  final AppDatabase _database;
  final ReferenceRepository _refs;
  final AuditRepository _audit;

  // ── الخطوة 1: المعاينة (لا كتابة) ───────────────────────────

  /// يحلّل ويتحقّق ويخطّط — **بدون أي كتابة في القاعدة**.
  Future<ImportPreview> preview({
    required ImportKind kind,
    required List<int> bytes,
    required String fileName,
    ColumnMapping? savedMapping,
    ImportMode mode = ImportMode.addNew,
  }) async {
    final ParsedCsv parsed = CsvParser.parseBytes(bytes);

    if (parsed.isEmpty) {
      throw const AppException(
        'الملف فارغ. الملف يجب أن يحتوي على رأس أعمدة وسجل واحد على الأقل.',
      );
    }

    final ColumnMapping mapping = CsvColumnMapper.autoMap(
      kind: kind,
      headers: parsed.headers,
      savedMapping: savedMapping,
    );

    // رسالة عربية واضحة إذا كان matricule/date غير مخصّص.
    CsvColumnMapper.validate(kind: kind, mapping: mapping);

    final _DbLookup lookup = await _buildLookup(kind, parsed, mapping);

    final List<PlannedRow> rows = switch (kind) {
      ImportKind.employees => EmployeeImportPlanner.plan(
          parsed: parsed,
          mapping: mapping,
          lookup: lookup,
        ),
      ImportKind.permanence => PermanenceImportPlanner.plan(
          parsed: parsed,
          mapping: mapping,
          lookup: lookup,
          sourceFile: fileName,
          mode: mode,
        ),
    };

    return ImportPreview(
      kind: kind.id,
      fileName: fileName,
      parsed: parsed,
      mapping: mapping,
      rows: rows,
      detectedDateFormat:
          EmployeeImportPlanner.detectDateFormat(parsed, mapping),
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  // ── الخطوة 2: التنفيذ (Transaction واحدة) ───────────────────

  /// يكتب ناتج [preview] بعد التأكيد الصريح من المستخدم.
  ///
  /// أي فشل داخل → **rollback كامل** ولا يتغيّر شيء.
  Future<ImportResult> commit(
    ImportPreview preview, {
    ImportMode mode = ImportMode.addNew,
    String? replaceFrom,
    String? replaceTo,
    bool createMissingReferences = true,
  }) async {
    final ImportKind kind = ImportKind.values.firstWhere(
      (ImportKind k) => k.id == preview.kind,
      orElse: () => ImportKind.employees,
    );

    if (!preview.hasWork && mode != ImportMode.replaceRange) {
      return ImportResult(
        kind: kind.id,
        fileName: preview.fileName,
        inserted: 0,
        updated: 0,
        skipped: preview.duplicateInFileCount + preview.duplicateExistingCount,
        errors: preview.errorCount,
        referenceEntriesCreated: 0,
        message: 'لا توجد سجلات للاستيراد.',
      );
    }

    try {
      final ImportResult result = await _database.transaction<ImportResult>(
        (Transaction txn) => _write(
          txn: txn,
          kind: kind,
          preview: preview,
          mode: mode,
          replaceFrom: replaceFrom,
          replaceTo: replaceTo,
          createMissingReferences: createMissingReferences,
        ),
      );

      await _audit.logImport(
        kind.id,
        'استيراد ${result.fileName}: '
        '+${result.inserted} ~${result.updated} '
        'تخطي=${result.skipped} خطأ=${result.errors}',
      );
      await _recordHistory(result, mode);
      return result;
    } on AppException {
      rethrow;
    } catch (e) {
      // أي فشل غير متوقع → القاعدة لم تتغيّر (rollback تلقائي).
      throw AppException(
        'تعذّر إتمام الاستيراد. لم يتغيّر أي شيء في القاعدة.',
        techDetail: e.toString(),
        cause: e,
      );
    }
  }

  // ── التنفيذ الداخلي ─────────────────────────────────────────

  Future<ImportResult> _write({
    required Transaction txn,
    required ImportKind kind,
    required ImportPreview preview,
    required ImportMode mode,
    String? replaceFrom,
    String? replaceTo,
    required bool createMissingReferences,
  }) async {
    int inserted = 0;
    int updated = 0;
    int skipped = 0;
    int errors = 0;
    int refsCreated = 0;
    int deleted = 0;

    final List<AuditLogEntry> auditRows = <AuditLogEntry>[];
    final String now = DateTime.now().toIso8601String();

    // ── Replace: حذف الفترة المحددة أولاً (بعد التأكيد) ──
    if (kind == ImportKind.permanence &&
        mode == ImportMode.replaceRange &&
        replaceFrom != null &&
        replaceTo != null) {
      deleted = await txn.delete(
        Db.permanence,
        where: '${Db.cDate} >= ? AND ${Db.cDate} <= ?',
        whereArgs: <Object?>[replaceFrom, replaceTo],
      );
    }

    for (final PlannedRow row in preview.rows) {
      switch (row.action) {
        case RowAction.empty:
        case RowAction.duplicateInFile:
        case RowAction.duplicateExisting:
          skipped++;
          continue;
        case RowAction.error:
          errors++;
          continue;
        case RowAction.insert:
        case RowAction.update:
          break;
      }

      if (kind == ImportKind.employees) {
        final ({int id, bool isNew, int refs}) r = await _writeEmployee(
          txn: txn,
          row: row,
          now: now,
          createMissing: createMissingReferences,
        );
        refsCreated += r.refs;
        if (r.isNew) {
          inserted++;
          auditRows.add(AuditLogEntry(
            action: 'create',
            entityType: 'employee',
            entityId: r.id,
            description: 'استيراد موظف matricule=${row.employee?.matricule}',
            createdAt: now,
          ));
        } else {
          updated++;
          auditRows.add(AuditLogEntry(
            action: 'update',
            entityType: 'employee',
            entityId: r.id,
            description:
                'تحديث من ملف ${preview.fileName} (السجل السابق محفوظ)',
            createdAt: now,
          ));
        }
      } else {
        final ({int id, bool isNew}) r = await _writePermanence(
          txn: txn,
          row: row,
          now: now,
          mode: mode,
        );
        if (r.isNew) {
          inserted++;
          auditRows.add(AuditLogEntry(
            action: 'create',
            entityType: 'permanence',
            entityId: r.id,
            description:
                'استيراد مداومة ${row.permanence?.date ?? ''} '
                'matricule=${row.permanence?.matricule ?? ''}',
            createdAt: now,
          ));
        } else {
          updated++;
          auditRows.add(AuditLogEntry(
            action: 'update',
            entityType: 'permanence',
            entityId: r.id,
            description: 'تحديث مداومة من ملف ${preview.fileName}',
            createdAt: now,
          ));
        }
      }
    }

    if (auditRows.isNotEmpty) {
      final Batch b = txn.batch();
      for (final AuditLogEntry e in auditRows) {
        b.insert(Db.auditLogs, e.toInsertMap());
      }
      await b.commit(noResult: true);
    }

    return ImportResult(
      kind: kind.id,
      fileName: preview.fileName,
      inserted: inserted,
      updated: updated,
      skipped: skipped,
      errors: errors,
      referenceEntriesCreated: refsCreated,
      unmatchedCount: preview.unmatched.length,
      deleted: deleted,
      mode: mode,
      succeeded: true,
      message: errors > 0
          ? 'تم الاستيراد مع $errors صف مرفوض.'
          : 'تم الاستيراد بنجاح.',
    );
  }

  /// إدراج/تحديث موظف واحد + إنشاء المراجع الناقصة إن لزم.
  Future<({int id, bool isNew, int refs})> _writeEmployee({
    required Transaction txn,
    required PlannedRow row,
    required String now,
    required bool createMissing,
  }) async {
    Employee e = row.employee!;
    int refs = 0;

    // إنشاء المراجع الناقصة داخل نفس الـ Transaction.
    //
    // **حتماً `txn: txn`** — أي استدعاء على الكائن الجذري هنا
    // يوقف sqflite بالكامل (deadlock: "database has been locked").
    if (createMissing) {
      if (row.pendingSection != null) {
        final ({int id, bool created}) r = await _refs.resolveOrCreate(
          Db.sections,
          row.pendingSection!,
          createIfMissing: true,
          txn: txn,
        );
        if (r.created) refs++;
        e = e.copyWith(sectionId: r.id);
      }
      if (row.pendingGrade != null) {
        final ({int id, bool created}) r = await _refs.resolveOrCreate(
          Db.grades,
          row.pendingGrade!,
          createIfMissing: true,
          txn: txn,
        );
        if (r.created) refs++;
        e = e.copyWith(gradeId: r.id);
      }
      if (row.pendingFunction != null) {
        final ({int id, bool created}) r = await _refs.resolveOrCreate(
          Db.functions,
          row.pendingFunction!,
          createIfMissing: true,
          txn: txn,
        );
        if (r.created) refs++;
        e = e.copyWith(functionId: r.id);
      }
      if (row.pendingStatus != null) {
        final int? id = await _refs.findStatusId(row.pendingStatus!, txn: txn);
        if (id != null) e = e.copyWith(currentStatusId: id);
      }
    }

    if (row.action == RowAction.update && row.existingId != null) {
      // **قاعدة حاسمة:** لا نمسح التاريخ — نحدّث الحقول فقط،
      // ونُبقي created_at كما هو.
      final Map<String, Object?> values =
          await _updateValues(txn, row.existingId!, e, now);
      await txn.update(
        Db.employees,
        values,
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[row.existingId],
      );
      return (id: row.existingId!, isNew: false, refs: refs);
    }

    final Map<String, Object?> values = e.toInsertMap()
      ..[Db.cCreatedAt] = now
      ..[Db.cUpdatedAt] = now;

    // حماية إضافية: matricule موجود مسبقاً → تحديث بدل خطأ UNIQUE.
    final List<Map<String, Object?>> existing = await txn.query(
      Db.employees,
      columns: <String>[Db.cId],
      where: '${Db.cMatricule} = ?',
      whereArgs: <Object?>[e.matricule],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final int id = existing.first[Db.cId] as int;
      final Map<String, Object?> upd =
          await _updateValues(txn, id, e, now, base: values);
      await txn.update(
        Db.employees,
        upd,
        where: '${Db.cId} = ?',
        whereArgs: <Object?>[id],
      );
      return (id: id, isNew: false, refs: refs);
    }

    final int id = await txn.insert(Db.employees, values);
    return (id: id, isNew: true, refs: refs);
  }

  /// يبني خريطة التحديث: **لا يُفرّغ** الحقول غير الواردة في الملف،
  /// ويعيد بناء `search_text` من الصف **المدموج** (قاعدة 61).
  ///
  /// السبب: لو استوردنا ملفاً فيه `matricule` فقط، فإن `search_text`
  /// المحسوب من [e] وحدها سيهمل الاسم السابق المحفوظ في قاعدة
  /// البيانات، فيختفي الموظف من البحث.
  Future<Map<String, Object?>> _updateValues(
    Transaction txn,
    int id,
    Employee e,
    String now, {
    Map<String, Object?>? base,
  }) async {
    final Map<String, Object?> values = <String, Object?>{
      if (base != null) ...base else ...e.toInsertMap(),
    }..remove(Db.cCreatedAt);
    values[Db.cUpdatedAt] = now;
    values.removeWhere(
      (String k, Object? v) =>
          v == null &&
          (k == Db.cSectionId ||
              k == Db.cGradeId ||
              k == Db.cFunctionId ||
              k == Db.cStatusId ||
              k == Db.cNomAr ||
              k == Db.cPrenomAr ||
              k == Db.cNomFr ||
              k == Db.cPrenomFr ||
              k == Db.cQuality ||
              k == Db.cPpr ||
              k == Db.cPhone ||
              k == Db.cNotes),
    );

    final List<Map<String, Object?>> cur = await txn.query(
      Db.employees,
      columns: const <String>[
        Db.cMatricule,
        Db.cPpr,
        Db.cNomAr,
        Db.cPrenomAr,
        Db.cNomFr,
        Db.cPrenomFr,
        Db.cQuality,
        Db.cPhone,
      ],
      where: '${Db.cId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (cur.isNotEmpty) {
      final Map<String, Object?> old = cur.first;
      values[Db.cSearchText] = TextNormalizer.searchText(<String?>[
        e.matricule.isNotEmpty
            ? e.matricule
            : old[Db.cMatricule] as String?,
        (values[Db.cPpr] ?? old[Db.cPpr]) as String?,
        (values[Db.cNomAr] ?? old[Db.cNomAr]) as String?,
        (values[Db.cPrenomAr] ?? old[Db.cPrenomAr]) as String?,
        (values[Db.cNomFr] ?? old[Db.cNomFr]) as String?,
        (values[Db.cPrenomFr] ?? old[Db.cPrenomFr]) as String?,
        (values[Db.cQuality] ?? old[Db.cQuality]) as String?,
        (values[Db.cPhone] ?? old[Db.cPhone]) as String?,
      ]);
    } else {
      values[Db.cSearchText] = e.searchText;
    }
    return values;
  }

  /// إدراج سجل مداومة واحد.
  Future<({int id, bool isNew})> _writePermanence({
    required Transaction txn,
    required PlannedRow row,
    required String now,
    required ImportMode mode,
  }) async {
    final PermanenceRecord p = row.permanence!;
    final Map<String, Object?> values = p.toInsertMap()
      ..[Db.cCreatedAt] = now
      ..[Db.cUpdatedAt] = now;

    if (p.employeeId != null) {
      // المفتاح الفريد (date, employee_id, time_slot) — D-010.
      final List<Map<String, Object?>> existing = await txn.query(
        Db.permanence,
        columns: <String>[Db.cId],
        where: '${Db.cDate} = ? AND ${Db.cEmployeeId} = ? '
            'AND ${Db.cTimeSlot} = ?',
        whereArgs: <Object?>[p.date, p.employeeId, p.timeSlot],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final int id = existing.first[Db.cId] as int;
        if (mode == ImportMode.addNew) {
          return (id: id, isNew: false);
        }
        values.remove(Db.cCreatedAt);
        await txn.update(
          Db.permanence,
          values,
          where: '${Db.cId} = ?',
          whereArgs: <Object?>[id],
        );
        return (id: id, isNew: false);
      }
    }

    final int id = await txn.insert(Db.permanence, values);
    return (id: id, isNew: true);
  }

  // ── بناء فهرس البحث ─────────────────────────────────────────

  /// يبني فهرساً من **استعلامات SQL** (لا تحميل الجداول كاملة).
  ///
  /// نجلب فقط ما يحتاجه هذا الملف: matricules و ppr الواردة فيه.
  Future<_DbLookup> _buildLookup(
    ImportKind kind,
    ParsedCsv parsed,
    ColumnMapping mapping,
  ) async {
    final Set<String> matricules = <String>{};
    final Set<String> pprs = <String>{};
    final Set<String> refSections = <String>{};
    final Set<String> refGrades = <String>{};
    final Set<String> refFunctions = <String>{};
    final Set<String> refStatuses = <String>{};

    void collect(String key, Set<String> into) {
      final int? idx = mapping.columnFor(key);
      if (idx == null) return;
      for (final List<String> r in parsed.rows) {
        if (idx >= r.length) continue;
        final String v = r[idx].trim();
        if (v.isNotEmpty) into.add(v);
      }
    }

    collect('matricule', matricules);
    if (kind == ImportKind.employees) {
      collect('ppr', pprs);
      collect('section', refSections);
      collect('grade', refGrades);
      collect('fonction', refFunctions);
      collect('status', refStatuses);
    }

    final Map<String, int> byMatricule = <String, int>{};
    final Map<String, int> byPpr = <String, int>{};
    final Map<String, Map<String, int>> references =
        <String, Map<String, int>>{};
    final Set<String> permKeys = <String>{};
    final Map<String, int> empIdByMatricule = <String, int>{};

    if (matricules.isNotEmpty) {
      final List<Map<String, Object?>> rows = await _database.db.query(
        Db.employees,
        columns: <String>[Db.cId, Db.cMatricule, Db.cPpr],
        where: '${Db.cMatricule} IN (${_placeholders(matricules.length)})',
        whereArgs: matricules.toList(),
      );
      for (final Map<String, Object?> m in rows) {
        final String mat = (m[Db.cMatricule] as String?) ?? '';
        final int id = m[Db.cId] as int;
        byMatricule[mat] = id;
        empIdByMatricule[mat] = id;
        final String? p = m[Db.cPpr] as String?;
        if (p != null && p.isNotEmpty) byPpr[p] = id;
      }
    }

    if (pprs.isNotEmpty) {
      final List<Map<String, Object?>> rows = await _database.db.query(
        Db.employees,
        columns: <String>[Db.cId, Db.cPpr],
        where: '${Db.cPpr} IN (${_placeholders(pprs.length)})',
        whereArgs: pprs.toList(),
      );
      for (final Map<String, Object?> m in rows) {
        final String? p = m[Db.cPpr] as String?;
        if (p != null && p.isNotEmpty) {
          byPpr.putIfAbsent(p, () => m[Db.cId] as int);
        }
      }
    }

    for (final (String table, Set<String> names) in <(String, Set<String>)>[
      (Db.sections, refSections),
      (Db.grades, refGrades),
      (Db.functions, refFunctions),
      (Db.statusTypes, refStatuses),
    ]) {
      if (names.isEmpty) continue;
      final Map<String, int> map = references.putIfAbsent(
        table,
        () => <String, int>{},
      );
      // `name_fr` موجودة في status_types فقط — أعمدة غير موجودة
      // تكسر الاستعلام كاملاً (`no such column`).
      final bool hasNameFr = table == Db.statusTypes;
      final List<String> columns = <String>[
        Db.cId,
        Db.cName,
        Db.cNameAr,
        if (hasNameFr) Db.cNameFr,
      ];
      final List<String> nameCols = <String>[
        Db.cName,
        Db.cNameAr,
        if (hasNameFr) Db.cNameFr,
      ];

      // نطابق الاسم كما ورد أو الاسم العربي/الفرنسي المسجّل.
      final String ph = _placeholders(names.length);
      final String where =
          nameCols.map((String c) => '$c IN ($ph)').join(' OR ');
      final List<Object?> whereArgs = <Object?>[
        for (int i = 0; i < nameCols.length; i++) ...names,
      ];
      final List<Map<String, Object?>> rows = await _database.db.query(
        table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
      );
      for (final Map<String, Object?> m in rows) {
        for (final String col in nameCols) {
          final String? v = m[col] as String?;
          if (v != null && v.isNotEmpty) map[v] = m[Db.cId] as int;
        }
      }
      // مطابقة غير حساسة للحالة.
      final Map<String, int> lower = <String, int>{
        for (final MapEntry<String, int> e in map.entries)
          e.key.toLowerCase(): e.value,
      };
      for (final String n in names) {
        final int? hit = map[n] ?? lower[n.toLowerCase()];
        if (hit != null) map[n] = hit;
      }
    }

    if (kind == ImportKind.permanence && empIdByMatricule.isNotEmpty) {
      final List<String> mats = empIdByMatricule.keys.toList();
      // نجلب مفاتيح المداومة القائمة على دفعات صغيرة.
      for (int i = 0; i < mats.length; i += 400) {
        final List<String> chunk = mats.sublist(
          i,
          i + 400 > mats.length ? mats.length : i + 400,
        );
        final List<Map<String, Object?>> rows = await _database.db.query(
          Db.permanence,
          columns: <String>[Db.cDate, Db.cEmployeeId, Db.cTimeSlot],
          where: '${Db.cEmployeeId} IN (${_placeholders(chunk.length)})',
          whereArgs: chunk
              .map((String m) => empIdByMatricule[m])
              .toList(),
        );
        for (final Map<String, Object?> m in rows) {
          permKeys.add(
            '${m[Db.cDate]}|${m[Db.cEmployeeId]}|${m[Db.cTimeSlot]}',
          );
        }
      }
    }

    return _DbLookup(
      matricules: byMatricule,
      pprs: byPpr,
      references: references,
      permanenceKeys: permKeys,
    );
  }

  static String _placeholders(int n) => List<String>.filled(n, '?').join(',');

  // ── سجل الاستيراد ───────────────────────────────────────────

  Future<void> _recordHistory(ImportResult result, ImportMode mode) async {
    final Map<String, Object?> row = result.toHistoryRow()
      ..[Db.cCreatedAt] = DateTime.now().toIso8601String()
      ..['delimiter'] = ','
      ..['encoding'] = 'UTF-8'
      ..['mode'] = mode.id;
    await _database.db.insert(Db.importHistory, row);
  }
}

/// تنفيذ فهرس البحث من SQL.
class _DbLookup implements ImportLookup {
  _DbLookup({
    required this.matricules,
    required this.pprs,
    required this.references,
    required this.permanenceKeys,
  });

  final Map<String, int> matricules;
  final Map<String, int> pprs;
  final Map<String, Map<String, int>> references;
  final Set<String> permanenceKeys;

  @override
  int? findByMatricule(String matricule) => matricules[matricule];

  @override
  int? findByPpr(String ppr) => ppr.isEmpty ? null : pprs[ppr];

  @override
  int? findReference(String table, String name) {
    final Map<String, int>? m = references[table];
    if (m == null) return null;
    final String clean = name.trim();
    return m[clean] ?? m[clean.toLowerCase()];
  }

  @override
  int? employeeIdFor(String matricule) => matricules[matricule];

  @override
  bool permanenceKeyExists(String date, int employeeId, String timeSlot) =>
      permanenceKeys.contains('$date|$employeeId|$timeSlot');

  @override
  bool hasPermanenceInRange(String from, String to) => permanenceKeys.isNotEmpty;
}
