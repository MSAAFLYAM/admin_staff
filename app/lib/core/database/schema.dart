import '../constants/db_constants.dart';

/// تعريف DDL الكامل لقاعدة البيانات — **schema_version = 1**.
///
/// مرجع كامل في [docs/DATABASE.md].
///
/// القواعد المطبّقة هنا:
///  - Foreign Keys مفعّلة (قاعدة 69)
///  - لا حذف فيزيائي → soft delete (قاعدة 70)
///  - فهارس على كل حقول البحث الكثيفة (قاعدة 39 و61)
///  - `matricule` / `ppr` / `phone` كلها TEXT (قاعدة 10)
abstract final class Schema {
  /// الجداول بترتيب الاعتماديات.
  static const List<String> tablesInOrder = <String>[
    Db.settings,
    Db.sections,
    Db.grades,
    Db.functions,
    Db.statusTypes,
    Db.employees,
    Db.statusHistory,
    Db.leaveTypes,
    Db.leaves,
    Db.permanence,
    Db.holidays,
    Db.auditLogs,
    Db.savedFilters,
    Db.importHistory,
  ];

  /// كل أوامر الإنشاء بترتيب آمن.
  static const List<String> createStatements = <String>[
    // ── settings ──────────────────────────────────────────────
    '''
CREATE TABLE ${Db.settings} (
  ${Db.cKey}       TEXT PRIMARY KEY,
  ${Db.cValue}     TEXT,
  ${Db.cUpdatedAt} TEXT NOT NULL
)''',

    // ── sections ──────────────────────────────────────────────
    '''
CREATE TABLE ${Db.sections} (
  ${Db.cId}         INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cName}       TEXT NOT NULL,
  ${Db.cNameAr}     TEXT,
  ${Db.cSearchText} TEXT NOT NULL DEFAULT '',
  ${Db.cIsActive}   INTEGER NOT NULL DEFAULT 1,
  ${Db.cCreatedAt}  TEXT NOT NULL,
  ${Db.cUpdatedAt}  TEXT NOT NULL
)''',
    'CREATE INDEX ix_sections_name ON ${Db.sections}(${Db.cName})',

    // ── grades ────────────────────────────────────────────────
    '''
CREATE TABLE ${Db.grades} (
  ${Db.cId}         INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cName}       TEXT NOT NULL,
  ${Db.cNameAr}     TEXT,
  ${Db.cSearchText} TEXT NOT NULL DEFAULT '',
  ${Db.cIsActive}   INTEGER NOT NULL DEFAULT 1,
  ${Db.cCreatedAt}  TEXT NOT NULL,
  ${Db.cUpdatedAt}  TEXT NOT NULL
)''',
    'CREATE INDEX ix_grades_name ON ${Db.grades}(${Db.cName})',

    // ── functions ─────────────────────────────────────────────
    '''
CREATE TABLE ${Db.functions} (
  ${Db.cId}         INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cName}       TEXT NOT NULL,
  ${Db.cNameAr}     TEXT,
  ${Db.cSearchText} TEXT NOT NULL DEFAULT '',
  ${Db.cIsActive}   INTEGER NOT NULL DEFAULT 1,
  ${Db.cCreatedAt}  TEXT NOT NULL,
  ${Db.cUpdatedAt}  TEXT NOT NULL
)''',
    'CREATE INDEX ix_functions_name ON ${Db.functions}(${Db.cName})',

    // ── status_types (قابلة للإدارة، غير hard-coded) ─────────
    '''
CREATE TABLE ${Db.statusTypes} (
  ${Db.cId}         INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cName}       TEXT NOT NULL,
  ${Db.cNameFr}     TEXT,
  ${Db.cPriority}   INTEGER NOT NULL DEFAULT 0,
  ${Db.cIsTerminal} INTEGER NOT NULL DEFAULT 0,
  ${Db.cIsActive}   INTEGER NOT NULL DEFAULT 1,
  ${Db.cSortOrder}  INTEGER NOT NULL DEFAULT 0,
  ${Db.cCreatedAt}  TEXT NOT NULL,
  ${Db.cUpdatedAt}  TEXT NOT NULL
)''',
    'CREATE UNIQUE INDEX uq_status_name ON ${Db.statusTypes}(${Db.cName})',
    'CREATE INDEX ix_status_priority ON ${Db.statusTypes}(${Db.cPriority} DESC)',
    'CREATE INDEX ix_status_terminal ON ${Db.statusTypes}(${Db.cIsTerminal})',

    // ── employees ─────────────────────────────────────────────
    '''
CREATE TABLE ${Db.employees} (
  ${Db.cId}                INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cMatricule}         TEXT NOT NULL,
  ${Db.cNomAr}             TEXT,
  ${Db.cPrenomAr}          TEXT,
  ${Db.cNomFr}             TEXT,
  ${Db.cPrenomFr}          TEXT,
  ${Db.cSectionId}         INTEGER REFERENCES ${Db.sections}(${Db.cId}),
  ${Db.cFunctionId}        INTEGER REFERENCES ${Db.functions}(${Db.cId}),
  ${Db.cQuality}           TEXT,
  ${Db.cGradeId}           INTEGER REFERENCES ${Db.grades}(${Db.cId}),
  ${Db.cPpr}               TEXT,
  ${Db.cPhone}             TEXT,
  ${Db.cStatusId}          INTEGER REFERENCES ${Db.statusTypes}(${Db.cId}),
  ${Db.cNotes}             TEXT,
  ${Db.cSearchText}        TEXT NOT NULL DEFAULT '',
  ${Db.cIsActive}          INTEGER NOT NULL DEFAULT 1,
  ${Db.cCreatedAt}         TEXT NOT NULL,
  ${Db.cUpdatedAt}         TEXT NOT NULL
)''',
    'CREATE UNIQUE INDEX uq_employees_matricule ON ${Db.employees}(${Db.cMatricule})',
    'CREATE UNIQUE INDEX uq_employees_ppr ON ${Db.employees}(${Db.cPpr})'
        ' WHERE ${Db.cPpr} IS NOT NULL AND ${Db.cPpr} <> \'\'',
    'CREATE INDEX ix_employees_nom_fr ON ${Db.employees}(${Db.cNomFr})',
    'CREATE INDEX ix_employees_prenom_fr ON ${Db.employees}(${Db.cPrenomFr})',
    'CREATE INDEX ix_employees_nom_ar ON ${Db.employees}(${Db.cNomAr})',
    'CREATE INDEX ix_employees_prenom_ar ON ${Db.employees}(${Db.cPrenomAr})',
    'CREATE INDEX ix_employees_ppr ON ${Db.employees}(${Db.cPpr})',
    'CREATE INDEX ix_employees_phone ON ${Db.employees}(${Db.cPhone})',
    'CREATE INDEX ix_employees_section ON ${Db.employees}(${Db.cSectionId})',
    'CREATE INDEX ix_employees_grade ON ${Db.employees}(${Db.cGradeId})',
    'CREATE INDEX ix_employees_function ON ${Db.employees}(${Db.cFunctionId})',
    'CREATE INDEX ix_employees_status ON ${Db.employees}(${Db.cStatusId})',
    'CREATE INDEX ix_employees_active ON ${Db.employees}(${Db.cIsActive})',
    'CREATE INDEX ix_employees_quality ON ${Db.employees}(${Db.cQuality})',

    // ── status_history (لا يُحذف التاريخ أبداً) ───────────────
    '''
CREATE TABLE ${Db.statusHistory} (
  ${Db.cId}             INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cEmployeeId}     INTEGER NOT NULL
      REFERENCES ${Db.employees}(${Db.cId}) ON DELETE CASCADE,
  ${Db.cStatusTypeId}   INTEGER NOT NULL
      REFERENCES ${Db.statusTypes}(${Db.cId}),
  ${Db.cStartDate}      TEXT NOT NULL,
  ${Db.cEndDate}        TEXT,
  ${Db.cNotes}          TEXT,
  ${Db.cCreatedAt}      TEXT NOT NULL,
  ${Db.cUpdatedAt}      TEXT NOT NULL
)''',
    'CREATE INDEX ix_status_history_emp_dates '
        'ON ${Db.statusHistory}(${Db.cEmployeeId}, ${Db.cStartDate}, ${Db.cEndDate})',
    'CREATE INDEX ix_status_history_status '
        'ON ${Db.statusHistory}(${Db.cStatusTypeId})',

    // ── leave_types (كل المدد seed قابلة للتعديل) ─────────────
    '''
CREATE TABLE ${Db.leaveTypes} (
  ${Db.cId}                 INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cNameAr}             TEXT NOT NULL,
  ${Db.cNameFr}            TEXT,
  ${Db.cDefaultDuration}   REAL NOT NULL DEFAULT 1,
  ${Db.cDurationUnit}       TEXT NOT NULL DEFAULT '${Db.unitDays}'
      CHECK(${Db.cDurationUnit} IN ('${Db.unitHours}', '${Db.unitDays}')),
  count_start_day           INTEGER NOT NULL DEFAULT 1,
  include_weekends          INTEGER NOT NULL DEFAULT 0,
  include_holidays          INTEGER NOT NULL DEFAULT 0,
  day_count_mode            TEXT NOT NULL DEFAULT '${Db.modeCalendar}'
      CHECK(day_count_mode IN ('${Db.modeCalendar}', '${Db.modeWorking}')),
  return_day_mode           TEXT NOT NULL DEFAULT '${Db.returnNextWorking}'
      CHECK(return_day_mode IN ('${Db.returnImmediate}', '${Db.returnNextWorking}')),
  ${Db.cStatusTypeId}       INTEGER REFERENCES ${Db.statusTypes}(${Db.cId}),
  ${Db.cIsActive}           INTEGER NOT NULL DEFAULT 1,
  ${Db.cSortOrder}          INTEGER NOT NULL DEFAULT 0,
  ${Db.cCreatedAt}          TEXT NOT NULL,
  ${Db.cUpdatedAt}          TEXT NOT NULL
)''',
    'CREATE UNIQUE INDEX uq_leave_types_ar ON ${Db.leaveTypes}(${Db.cNameAr})',

    // ── leaves ────────────────────────────────────────────────
    '''
CREATE TABLE ${Db.leaves} (
  ${Db.cId}             INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cEmployeeId}     INTEGER NOT NULL
      REFERENCES ${Db.employees}(${Db.cId}) ON DELETE CASCADE,
  ${Db.cLeaveTypeId}    INTEGER NOT NULL
      REFERENCES ${Db.leaveTypes}(${Db.cId}),
  ${Db.cStartDate}      TEXT NOT NULL,
  ${Db.cEndDate}        TEXT NOT NULL,
  ${Db.cReturnDate}     TEXT,
  ${Db.cDuration}       REAL,
  ${Db.cDurationUnit}   TEXT,
  ${Db.cRawDuration}    TEXT,
  ${Db.cNotes}          TEXT,
  ${Db.cIsCancelled}    INTEGER NOT NULL DEFAULT 0,
  ${Db.cCreatedAt}      TEXT NOT NULL,
  ${Db.cUpdatedAt}      TEXT NOT NULL
)''',
    'CREATE INDEX ix_leaves_emp_dates '
        'ON ${Db.leaves}(${Db.cEmployeeId}, ${Db.cStartDate}, ${Db.cEndDate})',
    'CREATE INDEX ix_leaves_type ON ${Db.leaves}(${Db.cLeaveTypeId})',
    'CREATE INDEX ix_leaves_start ON ${Db.leaves}(${Db.cStartDate})',
    'CREATE INDEX ix_leaves_end ON ${Db.leaves}(${Db.cEndDate})',
    'CREATE INDEX ix_leaves_return ON ${Db.leaves}(${Db.cReturnDate})',
    'CREATE INDEX ix_leaves_active ON ${Db.leaves}(${Db.cIsCancelled})',

    // ── permanence ────────────────────────────────────────────
    '''
CREATE TABLE ${Db.permanence} (
  ${Db.cId}             INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cDate}           TEXT NOT NULL,
  ${Db.cEmployeeId}     INTEGER REFERENCES ${Db.employees}(${Db.cId})
                              ON DELETE SET NULL,
  ${Db.cMatricule}      TEXT NOT NULL,
  ${Db.cPermanencier}   TEXT,
  ${Db.cSection}        TEXT,
  ${Db.cGrade}          TEXT,
  ${Db.cHpad}           TEXT,
  ${Db.cPhone}          TEXT,
  ${Db.cStartTime}      TEXT,
  ${Db.cEndTime}        TEXT,
  ${Db.cTimeSlot}       TEXT NOT NULL DEFAULT '',
  ${Db.cScheduleText}   TEXT,
  ${Db.cSourceFile}     TEXT,
  ${Db.cCreatedAt}      TEXT NOT NULL,
  ${Db.cUpdatedAt}      TEXT NOT NULL
)''',
    // مفتاح فريد يسمح بأكثر من فترة لنفس الموظف في اليوم نفسه (D-010).
    'CREATE UNIQUE INDEX uq_perm_date_emp_slot '
        'ON ${Db.permanence}(${Db.cDate}, ${Db.cEmployeeId}, ${Db.cTimeSlot})'
        ' WHERE ${Db.cEmployeeId} IS NOT NULL',
    'CREATE INDEX ix_perm_date ON ${Db.permanence}(${Db.cDate})',
    'CREATE INDEX ix_perm_employee '
        'ON ${Db.permanence}(${Db.cEmployeeId}, ${Db.cDate})',
    'CREATE INDEX ix_perm_matricule ON ${Db.permanence}(${Db.cMatricule})',
    'CREATE INDEX ix_perm_section ON ${Db.permanence}(${Db.cSection})',
    'CREATE INDEX ix_perm_start_time ON ${Db.permanence}(${Db.cStartTime})',

    // ── holidays ──────────────────────────────────────────────
    '''
CREATE TABLE ${Db.holidays} (
  ${Db.cId}         INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cDate}       TEXT NOT NULL,
  ${Db.cNameAr}     TEXT,
  ${Db.cNameFr}     TEXT,
  is_recurring      INTEGER NOT NULL DEFAULT 0,
  ${Db.cIsActive}   INTEGER NOT NULL DEFAULT 1,
  ${Db.cCreatedAt}  TEXT NOT NULL
)''',
    'CREATE UNIQUE INDEX uq_holiday_date ON ${Db.holidays}(${Db.cDate})',

    // ── audit_logs ────────────────────────────────────────────
    '''
CREATE TABLE ${Db.auditLogs} (
  ${Db.cId}          INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cAction}      TEXT NOT NULL,
  ${Db.cEntityType}  TEXT NOT NULL,
  ${Db.cEntityId}    INTEGER,
  ${Db.cDescription} TEXT,
  ${Db.cOldValue}    TEXT,
  ${Db.cNewValue}    TEXT,
  ${Db.cCreatedAt}   TEXT NOT NULL
)''',
    'CREATE INDEX ix_audit_entity '
        'ON ${Db.auditLogs}(${Db.cEntityType}, ${Db.cEntityId})',
    'CREATE INDEX ix_audit_created ON ${Db.auditLogs}(${Db.cCreatedAt})',
    'CREATE INDEX ix_audit_action ON ${Db.auditLogs}(${Db.cAction})',

    // ── saved_filters ─────────────────────────────────────────
    '''
CREATE TABLE ${Db.savedFilters} (
  ${Db.cId}         INTEGER PRIMARY KEY AUTOINCREMENT,
  ${Db.cName}       TEXT NOT NULL,
  criteria          TEXT NOT NULL,
  logic             TEXT NOT NULL DEFAULT 'AND',
  ${Db.cCreatedAt}  TEXT NOT NULL,
  ${Db.cUpdatedAt}  TEXT NOT NULL
)''',
    'CREATE UNIQUE INDEX uq_saved_filter_name ON ${Db.savedFilters}(${Db.cName})',

    // ── import_history ────────────────────────────────────────
    '''
CREATE TABLE ${Db.importHistory} (
  ${Db.cId}         INTEGER PRIMARY KEY AUTOINCREMENT,
  kind              TEXT NOT NULL,
  file_name         TEXT,
  delimiter         TEXT,
  encoding          TEXT,
  date_format       TEXT,
  mode              TEXT,
  total_rows        INTEGER NOT NULL DEFAULT 0,
  new_rows          INTEGER NOT NULL DEFAULT 0,
  updated_rows      INTEGER NOT NULL DEFAULT 0,
  dup_rows          INTEGER NOT NULL DEFAULT 0,
  error_rows        INTEGER NOT NULL DEFAULT 0,
  status            TEXT NOT NULL,
  message           TEXT,
  ${Db.cCreatedAt}  TEXT NOT NULL
)''',
  ];
}
