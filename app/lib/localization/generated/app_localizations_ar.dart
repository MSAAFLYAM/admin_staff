// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'إدارة الموظفين';

  @override
  String get appShortName => 'ADMIN STAFF';

  @override
  String get ok => 'موافق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get add => 'إضافة';

  @override
  String get close => 'إغلاق';

  @override
  String get back => 'رجوع';

  @override
  String get confirm => 'تأكيد';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get search => 'بحث';

  @override
  String get filter => 'فلترة';

  @override
  String get filters => 'الفلاتر';

  @override
  String get apply => 'تطبيق';

  @override
  String get reset => 'إعادة تعيين';

  @override
  String get clear => 'مسح';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get refresh => 'تحديث';

  @override
  String get all => 'الكل';

  @override
  String get none => 'لا شيء';

  @override
  String get loading => 'جاري التحميل…';

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String get noResultsHint => 'جرّب تعديل كلمات البحث أو الفلاتر.';

  @override
  String get unknown => 'غير معروف';

  @override
  String get optional => 'اختياري';

  @override
  String get required => 'إلزامي';

  @override
  String get from => 'من';

  @override
  String get to => 'إلى';

  @override
  String get date => 'التاريخ';

  @override
  String get startDate => 'تاريخ البداية';

  @override
  String get endDate => 'تاريخ النهاية';

  @override
  String get returnDate => 'تاريخ العودة';

  @override
  String get notes => 'ملاحظات';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get tomorrow => 'غداً';

  @override
  String get count => 'العدد';

  @override
  String get total => 'المجموع';

  @override
  String get actions => 'إجراءات';

  @override
  String get details => 'التفاصيل';

  @override
  String get name => 'الاسم';

  @override
  String get value => 'القيمة';

  @override
  String get status => 'الوضعية';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'معطّل';

  @override
  String get inactiveRecords => 'السجلات المعطّلة';

  @override
  String get showInactive => 'إظهار المعطّل';

  @override
  String get valueExists => 'هذه القيمة موجودة مسبقاً.';

  @override
  String get confirmDeleteTitle => 'تأكيد الحذف';

  @override
  String get confirmDeleteMessage =>
      'هل أنت متأكد من الحذف؟ لا يمكن التراجع عن هذه العملية.';

  @override
  String get confirmArchiveTitle => 'تأكيد الأرشفة';

  @override
  String get confirmArchiveMessage =>
      'سيتم نقل السجل إلى الأرشيف مع الاحتفاظ بكامل تاريخه. هل تريد المتابعة؟';

  @override
  String get savedSuccessfully => 'تم الحفظ بنجاح';

  @override
  String get deletedSuccessfully => 'تم الحذف بنجاح';

  @override
  String get unsavedChangesTitle => 'تغييرات غير محفوظة';

  @override
  String get unsavedChangesMessage => 'لديك تغييرات لم تُحفظ. هل تريد الخروج؟';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navEmployees => 'الموظفون';

  @override
  String get navPermanence => 'المداومة';

  @override
  String get navLeaves => 'الرخص';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get dashboardTitle => 'لوحة التحكم';

  @override
  String get globalSearchHint => 'ابحث عن موظف…';

  @override
  String get searchPlaceholder => 'ابحث بالاسم، الرقم، القسم، الرتبة…';

  @override
  String get totalEmployees => 'إجمالي الموظفين';

  @override
  String get inService => 'في الخدمة';

  @override
  String get onLeave => 'في عطلة';

  @override
  String get sickLeave => 'رخصة مرضية';

  @override
  String get exceptionalLeave => 'رخصة استثنائية';

  @override
  String get suspended => 'موقوفون';

  @override
  String get retired => 'متقاعدون';

  @override
  String get archivedCount => 'مؤرشفون';

  @override
  String get otherStatuses => 'حالات أخرى';

  @override
  String get todaysPermanence => 'مداومة اليوم';

  @override
  String get todaysAlerts => 'تنبيهات اليوم';

  @override
  String get leavesEndingToday => 'رخص تنتهي اليوم';

  @override
  String get leavesEndingTomorrow => 'رخص تنتهي غداً';

  @override
  String get employeesReturningToday => 'موظفون يعودون اليوم';

  @override
  String get leavesEndingIn3Days => 'رخص تنتهي خلال 3 أيام';

  @override
  String todaysPermanenceCount(int count) {
    return '$count موظف مداوم اليوم';
  }

  @override
  String get noAlertsToday => 'لا توجد تنبيهات لليوم';

  @override
  String get noPermanenceToday => 'لا توجد مداومة لهذا اليوم';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get reports => 'التقارير';

  @override
  String get employeesTitle => 'الموظفون';

  @override
  String get addEmployee => 'إضافة موظف';

  @override
  String get editEmployee => 'تعديل الموظف';

  @override
  String get employeeProfile => 'ملف الموظف';

  @override
  String get employeeCard => 'بطاقة موظف';

  @override
  String get openProfile => 'فتح الملف';

  @override
  String get noEmployees => 'لا يوجد موظفون';

  @override
  String get noEmployeesHint => 'استورد ملف CSV أو أضف موظفاً يدوياً للبدء.';

  @override
  String searchResultsCount(int count) {
    return '$count نتيجة';
  }

  @override
  String get tabInfo => 'المعلومات';

  @override
  String get tabStatus => 'الوضعية';

  @override
  String get tabLeaves => 'العطل والرخص';

  @override
  String get tabPermanence => 'المداومة';

  @override
  String get tabHistory => 'السجل';

  @override
  String get matricule => 'Matricule';

  @override
  String get ppr => 'PPR';

  @override
  String get nomAr => 'الاسم (عربي)';

  @override
  String get prenomAr => 'اللقب (عربي)';

  @override
  String get nomFr => 'Nom';

  @override
  String get prenomFr => 'Prénom';

  @override
  String get fullNameAr => 'الاسم بالعربية';

  @override
  String get fullNameFr => 'الاسم بالفرنسية';

  @override
  String get section => 'القسم';

  @override
  String get grade => 'الرتبة';

  @override
  String get fonction => 'الوظيفة';

  @override
  String get quality => 'Qualité';

  @override
  String get phone => 'الهاتف';

  @override
  String get mobilePhone => 'الهاتف المحمول';

  @override
  String get currentStatus => 'الوضعية الحالية';

  @override
  String get chooseSection => 'اختر القسم';

  @override
  String get chooseGrade => 'اختر الرتبة';

  @override
  String get chooseFunction => 'اختر الوظيفة';

  @override
  String get chooseStatus => 'اختر الوضعية';

  @override
  String get chooseEmployee => 'اختر الموظف';

  @override
  String get chooseLeaveType => 'اختر نوع الرخصة';

  @override
  String get chooseDate => 'اختر التاريخ';

  @override
  String get searchEmployee => 'ابحث عن موظف…';

  @override
  String get errMatriculeRequired =>
      'حقل Matricule إلزامي ولا يمكن أن يكون فارغاً.';

  @override
  String get errMatriculeDuplicate => 'رقم Matricule مستخدم لموظف آخر.';

  @override
  String get errPprDuplicate => 'رقم PPR مستخدم لموظف آخر.';

  @override
  String get errNameRequired => 'يجب إدخال الاسم بالعربية أو الفرنسية.';

  @override
  String get errFieldRequired => 'هذا الحقل إلزامي.';

  @override
  String get errInvalidDate => 'تاريخ غير صالح.';

  @override
  String get errEndBeforeStart =>
      'تاريخ النهاية يجب أن يكون بعد تاريخ البداية.';

  @override
  String get errNegativeDuration => 'المدة يجب أن تكون أكبر من صفر.';

  @override
  String get errInvalidHours => 'قيمة ساعات غير صالحة.';

  @override
  String get errInvalidPhone => 'رقم هاتف غير صالح.';

  @override
  String get errInvalidPpr => 'قيمة PPR غير صالحة.';

  @override
  String get errEmptyFile => 'الملف فارغ.';

  @override
  String errMissingColumn(String column) {
    return 'تعذر استيراد الملف لأن العمود $column غير موجود.';
  }

  @override
  String errInvalidDateFormat(String value) {
    return 'تنسيق تاريخ غير معروف: \"$value\"';
  }

  @override
  String get errUnknown => 'حدث خطأ غير متوقع. راجع السجل التقني للتفاصيل.';

  @override
  String get errSaveFailed => 'تعذر حفظ البيانات. تأكد من صحة المدخلات.';

  @override
  String get errImportFailed => 'تعذر استيراد الملف.';

  @override
  String get importTitle => 'استيراد CSV';

  @override
  String get importEmployees => 'استيراد CSV موظفين';

  @override
  String get importPermanence => 'استيراد CSV مداومة';

  @override
  String get selectFile => 'اختر ملفاً';

  @override
  String get fileName => 'اسم الملف';

  @override
  String get preview => 'معاينة';

  @override
  String get previewTitle => 'معاينة الاستيراد';

  @override
  String get columns => 'الأعمدة';

  @override
  String get delimiter => 'Delimiter';

  @override
  String get encoding => 'الترميز';

  @override
  String get dateFormat => 'تنسيق التاريخ';

  @override
  String get detectedFormat => 'التنسيق المتعرَّف عليه';

  @override
  String get columnMapping => 'مطابقة الأعمدة';

  @override
  String get csvColumn => 'عمود CSV';

  @override
  String get mapsTo => 'يطابق';

  @override
  String get ignoreColumn => 'تجاهل';

  @override
  String get totalRows => 'إجمالي السجلات';

  @override
  String get newRows => 'سجلات جديدة';

  @override
  String get updatedRows => 'سجلات سيتم تحديثها';

  @override
  String get duplicateRows => 'سجلات مكررة';

  @override
  String get errorRows => 'سجلات بها أخطاء';

  @override
  String get validRows => 'سجلات مقبولة';

  @override
  String get rejectedRows => 'سجلات مرفوضة';

  @override
  String get invalidRowsTitle => 'الصفوف المرفوضة';

  @override
  String rowNumber(int n) {
    return 'صف $n';
  }

  @override
  String get confirmImport => 'تأكيد الاستيراد';

  @override
  String get importSucceeded => 'تم الاستيراد بنجاح';

  @override
  String get importRolledBack => 'فشل الاستيراد وتم التراجع عن كل التغييرات.';

  @override
  String get unmatchedEmployees => 'موظفون غير مربوطون';

  @override
  String get unmatchedHint =>
      'لم يتم العثور على هؤلاء الموظفين في قاعدة البيانات. لن يتم إنشاؤهم تلقائياً.';

  @override
  String matchedCount(int count) {
    return 'مرتبطة: $count';
  }

  @override
  String unmatchedCount(int count) {
    return 'غير مربوطة: $count';
  }

  @override
  String get importMode => 'سياسة الاستيراد';

  @override
  String get modeAddWeek => 'إضافة السجلات الجديدة';

  @override
  String get modeUpdateWeek => 'تحديث السجلات الموجودة';

  @override
  String get modeReplaceRange => 'استبدال الفترة المحددة';

  @override
  String get replaceWarning =>
      'هل أنت متأكد من استبدال بيانات الفترة المحددة؟ سيتم حذف السجلات الموجودة في هذه الفترة أولاً.';

  @override
  String get manualAddEmployee => 'إنشاء الموظفين المفقودين يدوياً';

  @override
  String get skipUnmatched => 'تجاهل السجلات غير المربوطة';

  @override
  String get statusHistory => 'سجل الوضعيات';

  @override
  String get addStatus => 'إضافة وضعية';

  @override
  String get editStatus => 'تعديل الوضعية';

  @override
  String get statusType => 'نوع الوضعية';

  @override
  String get priority => 'الأولوية';

  @override
  String get priorityHint => 'كلما زادت الأولوية تغلّبت الحالة عند التداخل.';

  @override
  String get startDateRequired => 'تاريخ البداية إلزامي.';

  @override
  String get noStatusHistory => 'لا يوجد سجل للوضعيات';

  @override
  String get noStatusHistoryHint => 'عند تغيير وضعية الموظف سيظهر السجل هنا.';

  @override
  String get currentRecord => 'السجل الحالي';

  @override
  String get previousRecords => 'السجل السابق';

  @override
  String get terminalStatus => 'حالة نهائية';

  @override
  String get derivedStatus => 'مشتقة من الرخصة';

  @override
  String get changeStatus => 'تغيير الوضعية';

  @override
  String get conflictDetected => 'تم رصد تعارض';

  @override
  String get conflictMessage =>
      'هناك فترة متداخلة مع سجل موجود. لم يتم تطبيق الحالة تلقائياً.';

  @override
  String get conflictPeriod => 'فترة التداخل';

  @override
  String get existingRecord => 'السجل الحالي';

  @override
  String get newRecord => 'السجل الجديد';

  @override
  String get saveAnyway => 'حفظ على أي حال';

  @override
  String get leavesTitle => 'العطل والرخص';

  @override
  String get addLeave => 'إضافة رخصة';

  @override
  String get editLeave => 'تعديل الرخصة';

  @override
  String get leaveType => 'نوع الرخصة';

  @override
  String get leaveTypes => 'أنواع الرخص';

  @override
  String get addLeaveType => 'إضافة نوع رخصة';

  @override
  String get editLeaveType => 'تعديل نوع الرخصة';

  @override
  String get leavesCurrent => 'الحالية';

  @override
  String get leavesUpcoming => 'القادمة';

  @override
  String get leavesEnded => 'المنتهية';

  @override
  String get noLeaves => 'لا توجد رخص حالياً';

  @override
  String get noLeavesHint => 'اضغط «إضافة رخصة» لتسجيل رخصة جديدة.';

  @override
  String get duration => 'المدة';

  @override
  String get unit => 'الوحدة';

  @override
  String get unitHours => 'ساعات';

  @override
  String get unitDays => 'أيام';

  @override
  String get calculated => 'المحسوب تلقائياً';

  @override
  String get calculatedEnd => 'تاريخ النهاية المحسوب';

  @override
  String get calculatedReturn => 'تاريخ العودة المحسوب';

  @override
  String get countStartDay => 'احتساب يوم البداية';

  @override
  String get includeWeekends => 'احتساب نهاية الأسبوع';

  @override
  String get includeHolidays => 'احتساب العطل الرسمية';

  @override
  String get dayCountMode => 'طريقة احتساب الأيام';

  @override
  String get modeCalendar => 'أيام تقويم';

  @override
  String get modeWorking => 'أيام عمل';

  @override
  String get returnDayMode => 'طريقة حساب العودة';

  @override
  String get returnImmediate => 'مباشرة (اليوم التالي)';

  @override
  String get returnNextWorking => 'أول يوم عمل';

  @override
  String get cancelLeave => 'إلغاء الرخصة';

  @override
  String get leaveCancelled => 'تم إلغاء الرخصة';

  @override
  String get conflictLeaveOverlap => 'توجد رخصة أخرى متداخلة مع هذه الفترة.';

  @override
  String get businessDefaults => 'القيم الافتراضية القابلة للتعديل';

  @override
  String get businessDefaultsHint =>
      'كل المدد والقواعد قابلة للتعديل ولا توجد قيم ثابتة في الكود.';

  @override
  String get permanenceTitle => 'المداومة';

  @override
  String get addPermanence => 'إضافة مداومة يدوياً';

  @override
  String get editPermanence => 'تعديل المداومة';

  @override
  String get permanenceToday => 'اليوم';

  @override
  String get permanenceWeek => 'الأسبوع';

  @override
  String get permanenceArchive => 'الأرشيف';

  @override
  String get prevDay => 'اليوم السابق';

  @override
  String get nextDay => 'اليوم التالي';

  @override
  String get prevWeek => 'الأسبوع السابق';

  @override
  String get nextWeek => 'الأسبوع التالي';

  @override
  String get currentWeek => 'الأسبوع الحالي';

  @override
  String weekRange(String from, String to) {
    return '$from — $to';
  }

  @override
  String get noPermanence => 'لا توجد مداومة لهذا اليوم';

  @override
  String get noPermanenceWeek => 'لا توجد مداومة لهذا الأسبوع';

  @override
  String get noPermanenceArchive => 'لا توجد سجلات مداومة';

  @override
  String get permanencier => 'المناوب';

  @override
  String get schedule => 'المناوبة';

  @override
  String get hpad => 'H-pad';

  @override
  String get startTime => 'وقت البداية';

  @override
  String get endTime => 'وقت النهاية';

  @override
  String get timeRange => 'الفترة الزمنية';

  @override
  String get unlinkedRecord => 'غير مربوط بموظف';

  @override
  String get linkedTo => 'مرتبط بـ';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get sectionSecurity => 'الأمان';

  @override
  String get sectionLanguage => 'اللغة والمظهر';

  @override
  String get sectionData => 'البيانات';

  @override
  String get sectionLeaves => 'الرخص';

  @override
  String get sectionReferences => 'الأقسام والرتب';

  @override
  String get sectionBackup => 'النسخ الاحتياطي';

  @override
  String get sectionAbout => 'حول التطبيق';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageFrench => 'Français';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get changePin => 'تغيير رمز PIN';

  @override
  String get enablePin => 'تفعيل رمز PIN';

  @override
  String get disablePin => 'تعطيل رمز PIN';

  @override
  String get biometric => 'البصمة';

  @override
  String get biometricEnable => 'تفعيل البصمة';

  @override
  String get biometricUnavailable => 'البصمة غير متاحة على هذا الجهاز';

  @override
  String get autoLock => 'القفل التلقائي';

  @override
  String get autoLock1m => 'دقيقة';

  @override
  String get autoLock5m => '5 دقائق';

  @override
  String get autoLock15m => '15 دقيقة';

  @override
  String get autoLockOff => 'معطّل';

  @override
  String get createPin => 'أنشئ رمز PIN';

  @override
  String get confirmPin => 'أكّد رمز PIN';

  @override
  String get wrongPin => 'رمز PIN غير صحيح';

  @override
  String get pinMismatch => 'الرمزان غير متطابقين';

  @override
  String get pinTooShort => 'يجب أن يتكون الرمز من 4 أرقام على الأقل';

  @override
  String get sections => 'الأقسام';

  @override
  String get grades => 'الرتب';

  @override
  String get functionsList => 'الوظائف';

  @override
  String get statusTypesList => 'أنواع الوضعيات';

  @override
  String get holidays => 'العطل الرسمية';

  @override
  String get addSection => 'إضافة قسم';

  @override
  String get addGrade => 'إضافة رتبة';

  @override
  String get addFunction => 'إضافة وظيفة';

  @override
  String get addHoliday => 'إضافة عطلة رسمية';

  @override
  String get manage => 'إدارة';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get deactivate => 'تعطيل';

  @override
  String get reactivate => 'إعادة تفعيل';

  @override
  String get historyKept => 'إعادة التسمية لا تكسر السجل التاريخي.';

  @override
  String get noSections => 'لا توجد أقسام';

  @override
  String get noGrades => 'لا توجد رتب';

  @override
  String get noFunctions => 'لا توجد وظائف';

  @override
  String get noHolidays => 'لا توجد عطل رسمية';

  @override
  String get exportData => 'تصدير البيانات';

  @override
  String get exportCsv => 'تصدير CSV';

  @override
  String get importData => 'استيراد البيانات';

  @override
  String get aboutTitle => 'حول التطبيق';

  @override
  String get version => 'الإصدار';

  @override
  String get schemaVersion => 'إصدار المخطط';

  @override
  String get offlineNote =>
      'هذا التطبيق يعمل محلياً بالكامل ولا يرسل أي بيانات خارج الجهاز.';

  @override
  String get createBackup => 'إنشاء نسخة احتياطية';

  @override
  String get restoreBackup => 'استعادة نسخة احتياطية';

  @override
  String get backupCreated => 'تم إنشاء النسخة الاحتياطية';

  @override
  String get backupEncrypted => 'مشفّرة (AES-256-GCM)';

  @override
  String get restoreTitle => 'استعادة النسخة الاحتياطية';

  @override
  String get restoreWarning =>
      'استعادة النسخة الاحتياطية ستستبدل كل البيانات الحالية. هل أنت متأكد؟';

  @override
  String get restoreSucceeded => 'تمت الاستعادة بنجاح';

  @override
  String get backupCorrupt => 'ملف النسخة الاحتياطية تالف أو غير متوافق.';

  @override
  String get backupWrongKey => 'تعذر فك التشفير. مفتاح الاستعادة غير صحيح.';

  @override
  String get backupChecksum => 'فشل التحقق من السلامة (checksum).';

  @override
  String get backupVersionMismatch => 'إصدار النسخة غير مدعوم.';

  @override
  String get backupNoFile => 'لم يتم اختيار ملف.';

  @override
  String get backupIncludeAudit => 'تضمين سجل التدقيق';

  @override
  String get recentBackups => 'آخر النسخ';

  @override
  String get reportEmployeesBySection => 'الموظفون حسب القسم';

  @override
  String get reportEmployeesByStatus => 'الموظفون حسب الوضعية';

  @override
  String get reportCurrentLeaves => 'العطل الحالية';

  @override
  String get reportEndedLeaves => 'الرخص المنتهية';

  @override
  String get reportUpcomingLeaves => 'الرخص القادمة';

  @override
  String get reportPermanenceByDay => 'المداومون حسب اليوم';

  @override
  String get reportPermanenceByWeek => 'المداومون حسب الأسبوع';

  @override
  String get reportEmployeesByGrade => 'الموظفون حسب الرتبة';

  @override
  String get reportEmployeesByFunction => 'الموظفون حسب الوظيفة';

  @override
  String get generateReport => 'إنشاء التقرير';

  @override
  String get exportResults => 'تصدير النتائج';

  @override
  String get auditLog => 'سجل التدقيق';

  @override
  String get auditCreated => 'إنشاء';

  @override
  String get auditUpdated => 'تعديل';

  @override
  String get auditDeleted => 'حذف';

  @override
  String get auditImported => 'استيراد';

  @override
  String get auditRestored => 'استعادة';

  @override
  String get auditNoLogs => 'لا توجد سجلات';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get notificationsEnable => 'تفعيل الإشعارات المحلية';

  @override
  String notifLeaveEndsTomorrow(String name) {
    return 'تنتهي رخصة $name غداً.';
  }

  @override
  String notifEmployeeReturnsToday(String name) {
    return 'يعود الموظف $name اليوم.';
  }

  @override
  String notifPermanenceCount(int count) {
    return 'لديك $count موظف مداوم اليوم.';
  }

  @override
  String get lockedTitle => 'التطبيق مقفل';

  @override
  String get unlockWithPin => 'أدخل رمز PIN';

  @override
  String get unlockWithBiometric => 'استخدم البصمة لفتح التطبيق';

  @override
  String get unlock => 'فتح';

  @override
  String get forgotPin => 'نسيت الرمز؟';

  @override
  String get forgotPinHint =>
      'لا يمكن استرجاع رمز PIN محفوظ. يجب إعادة تثبيت التطبيق مع فقدان البيانات ما لم تملك نسخة احتياطية.';
}
