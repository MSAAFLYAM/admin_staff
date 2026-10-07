/// ثوابت أسماء الجداول والأعمدة والمؤشرات.
///
/// كل الـ DDL يستعمل هذه الثوابت لتجنّب أخطاء الكتابة اليدوية.
abstract final class Db {
  // ── Schema version (قاعدة 60) ────────────────────────────────
  static const int schemaVersion = 1;
  static const String dbFileName = 'admin_staff.db';

  // ── Tables ───────────────────────────────────────────────────
  static const String settings = 'settings';
  static const String sections = 'sections';
  static const String grades = 'grades';
  static const String functions = 'functions';
  static const String statusTypes = 'status_types';
  static const String statusHistory = 'status_history';
  static const String employees = 'employees';
  static const String leaveTypes = 'leave_types';
  static const String leaves = 'leaves';
  static const String permanence = 'permanence';
  static const String holidays = 'holidays';
  static const String auditLogs = 'audit_logs';
  static const String savedFilters = 'saved_filters';
  static const String importHistory = 'import_history';

  // ── Employees ────────────────────────────────────────────────
  static const String cId = 'id';
  static const String cMatricule = 'matricule';
  static const String cPpr = 'ppr';
  static const String cNomAr = 'nom_ar';
  static const String cPrenomAr = 'prenom_ar';
  static const String cNomFr = 'nom_fr';
  static const String cPrenomFr = 'prenom_fr';
  static const String cSectionId = 'section_id';
  static const String cFunctionId = 'function_id';
  static const String cQuality = 'quality';
  static const String cGradeId = 'grade_id';
  static const String cPhone = 'mobile_phone';
  static const String cStatusId = 'current_status_id';
  static const String cIsActive = 'is_active';
  static const String cNotes = 'notes';
  static const String cCreatedAt = 'created_at';
  static const String cUpdatedAt = 'updated_at';

  // ── Status types ─────────────────────────────────────────────
  /// `1` = حالة نهائية (تقاعد) — لا تُلغى بسجل لاحق.
  static const String cIsTerminal = 'is_terminal';

  // ── Leave types ─────────────────────────────────────────────
  /// مدة الرخصة الافتراضية في `leave_types`.
  /// **ليست** `duration` — تلك في `leaves` هي المدة المحتسبة فعلياً.
  static const String cDefaultDuration = 'default_duration';

  /// المدة كما أُدخلت حرفيّاً ("48h" أو "3d") في `leaves`.
  static const String cRawDuration = 'raw_duration';

  // ── عمود البحث المطبَّع (قاعدة 25 و61) ──────────────────────
  /// نص البحث المطبَّع (`TextNormalizer.searchText`) — يُملأ عند الكتابة.
  ///
  /// **لماذا عمود مستقل؟** لأن SQL لا يستطيع تطبيع الحروف العربية
  /// (`أ/إ/آ → ا`، `ة → ه`، إزالة التشكيل) — `LOWER()` في SQLite
  /// للاتينية فقط. لو بحثنا عن `أحمد` دون تطبيع الطرفين لكان
  /// `LIKE '%احمد%'` **لا يطابق** `أحمد` المسجّلة.
  ///
  /// الحل: نطبّع مرة واحدة عند الكتابة، فيصبح البحث مطابقة مباشرة
  /// بين نصّين متطابقين التطبيع — **و** أسرع (عمود واحد بدل 11).
  static const String cSearchText = 'search_text';

  // ── Generic reference columns ────────────────────────────────
  static const String cName = 'name';
  static const String cNameAr = 'name_ar';
  static const String cNameFr = 'name_fr';
  static const String cPriority = 'priority';
  static const String cSortOrder = 'sort_order';

  // ── Status history ───────────────────────────────────────────
  static const String cEmployeeId = 'employee_id';
  static const String cStatusTypeId = 'status_type_id';
  static const String cStartDate = 'start_date';
  static const String cEndDate = 'end_date';

  // ── Leaves ───────────────────────────────────────────────────
  static const String cLeaveTypeId = 'leave_type_id';
  static const String cReturnDate = 'return_date';
  static const String cDuration = 'duration';
  static const String cDurationUnit = 'duration_unit';
  static const String cIsCancelled = 'is_cancelled';

  // ── Permanence ───────────────────────────────────────────────
  static const String cDate = 'date';
  static const String cEmployeeIdCol = 'employee_id';
  static const String cPermanencier = 'permanencier';
  static const String cSection = 'section';
  static const String cGrade = 'grade';
  static const String cHpad = 'hpad';
  static const String cStartTime = 'start_time';
  static const String cEndTime = 'end_time';
  static const String cTimeSlot = 'time_slot';
  static const String cScheduleText = 'schedule_text';
  static const String cSourceFile = 'source_file';

  // ── Audit ────────────────────────────────────────────────────
  static const String cAction = 'action';
  static const String cEntityType = 'entity_type';
  static const String cEntityId = 'entity_id';
  static const String cDescription = 'description';
  static const String cOldValue = 'old_value';
  static const String cNewValue = 'new_value';

  // ── Settings ─────────────────────────────────────────────────
  static const String cKey = 'key';
  static const String cValue = 'value';

  /// `saved_filters` (المخطط §10) — المعايير كـ JSON والمنطق
  /// كعمود مستقل.
  static const String cCriteria = 'criteria';
  static const String cLogic = 'logic';

  // ── Enums مخزّنة كنص ─────────────────────────────────────────
  static const String unitHours = 'hours';
  static const String unitDays = 'days';
  static const String modeCalendar = 'calendar';
  static const String modeWorking = 'working';
  static const String returnImmediate = 'immediate';
  static const String returnNextWorking = 'next_working_day';

  // ── مفاتيح settings المحفوظة ─────────────────────────────────
  static const String keyLocale = 'locale';
  static const String keyPinHash = 'pin_hash';
  static const String keyPinSalt = 'pin_salt';
  static const String keyPinEnabled = 'pin_enabled';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyAutoLockMinutes = 'auto_lock_minutes';

  /// خيار «معطّل» في القفل التلقائي — مستقل عن الدقائق لأن
  /// `auto_lock_minutes = 0` تُعامَل كقيمة غير منطقية لا كإطفاء.
  static const String keyAutoLockEnabled = 'auto_lock_enabled';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyImportMappingEmployees = 'import_mapping_employees';
  static const String keyImportMappingPermanence = 'import_mapping_permanence';
  static const String keySavedDelimiterEmployees = 'saved_delimiter_employees';
  static const String keySavedDelimiterPermanence = 'saved_delimiter_permanence';
}
