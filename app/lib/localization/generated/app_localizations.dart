import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الموظفين'**
  String get appName;

  /// No description provided for @appShortName.
  ///
  /// In ar, this message translates to:
  /// **'ADMIN STAFF'**
  String get appShortName;

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'موافق'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get saveChanges;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get add;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get no;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In ar, this message translates to:
  /// **'فلترة'**
  String get filter;

  /// No description provided for @filters.
  ///
  /// In ar, this message translates to:
  /// **'الفلاتر'**
  String get filters;

  /// No description provided for @apply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get apply;

  /// No description provided for @reset.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين'**
  String get reset;

  /// No description provided for @clear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get clear;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get refresh;

  /// No description provided for @all.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get all;

  /// No description provided for @none.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء'**
  String get none;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل…'**
  String get loading;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get noResults;

  /// No description provided for @noResultsHint.
  ///
  /// In ar, this message translates to:
  /// **'جرّب تعديل كلمات البحث أو الفلاتر.'**
  String get noResultsHint;

  /// No description provided for @unknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get unknown;

  /// No description provided for @optional.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get optional;

  /// No description provided for @required.
  ///
  /// In ar, this message translates to:
  /// **'إلزامي'**
  String get required;

  /// No description provided for @from.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get from;

  /// No description provided for @to.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get to;

  /// No description provided for @date.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get date;

  /// No description provided for @startDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ البداية'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ النهاية'**
  String get endDate;

  /// No description provided for @returnDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ العودة'**
  String get returnDate;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notes;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غداً'**
  String get tomorrow;

  /// No description provided for @count.
  ///
  /// In ar, this message translates to:
  /// **'العدد'**
  String get count;

  /// No description provided for @total.
  ///
  /// In ar, this message translates to:
  /// **'المجموع'**
  String get total;

  /// No description provided for @actions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات'**
  String get actions;

  /// No description provided for @details.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get details;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// No description provided for @value.
  ///
  /// In ar, this message translates to:
  /// **'القيمة'**
  String get value;

  /// No description provided for @status.
  ///
  /// In ar, this message translates to:
  /// **'الوضعية'**
  String get status;

  /// No description provided for @active.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In ar, this message translates to:
  /// **'معطّل'**
  String get inactive;

  /// No description provided for @inactiveRecords.
  ///
  /// In ar, this message translates to:
  /// **'السجلات المعطّلة'**
  String get inactiveRecords;

  /// No description provided for @showInactive.
  ///
  /// In ar, this message translates to:
  /// **'إظهار المعطّل'**
  String get showInactive;

  /// No description provided for @valueExists.
  ///
  /// In ar, this message translates to:
  /// **'هذه القيمة موجودة مسبقاً.'**
  String get valueExists;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من الحذف؟ لا يمكن التراجع عن هذه العملية.'**
  String get confirmDeleteMessage;

  /// No description provided for @confirmArchiveTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الأرشفة'**
  String get confirmArchiveTitle;

  /// No description provided for @confirmArchiveMessage.
  ///
  /// In ar, this message translates to:
  /// **'سيتم نقل السجل إلى الأرشيف مع الاحتفاظ بكامل تاريخه. هل تريد المتابعة؟'**
  String get confirmArchiveMessage;

  /// No description provided for @savedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ بنجاح'**
  String get savedSuccessfully;

  /// No description provided for @deletedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم الحذف بنجاح'**
  String get deletedSuccessfully;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغييرات غير محفوظة'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In ar, this message translates to:
  /// **'لديك تغييرات لم تُحفظ. هل تريد الخروج؟'**
  String get unsavedChangesMessage;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navEmployees.
  ///
  /// In ar, this message translates to:
  /// **'الموظفون'**
  String get navEmployees;

  /// No description provided for @navPermanence.
  ///
  /// In ar, this message translates to:
  /// **'المداومة'**
  String get navPermanence;

  /// No description provided for @navLeaves.
  ///
  /// In ar, this message translates to:
  /// **'الرخص'**
  String get navLeaves;

  /// No description provided for @navSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// No description provided for @dashboardTitle.
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get dashboardTitle;

  /// No description provided for @globalSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن موظف…'**
  String get globalSearchHint;

  /// No description provided for @searchPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم، الرقم، القسم، الرتبة…'**
  String get searchPlaceholder;

  /// No description provided for @totalEmployees.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الموظفين'**
  String get totalEmployees;

  /// No description provided for @inService.
  ///
  /// In ar, this message translates to:
  /// **'في الخدمة'**
  String get inService;

  /// No description provided for @onLeave.
  ///
  /// In ar, this message translates to:
  /// **'في عطلة'**
  String get onLeave;

  /// No description provided for @sickLeave.
  ///
  /// In ar, this message translates to:
  /// **'رخصة مرضية'**
  String get sickLeave;

  /// No description provided for @exceptionalLeave.
  ///
  /// In ar, this message translates to:
  /// **'رخصة استثنائية'**
  String get exceptionalLeave;

  /// No description provided for @suspended.
  ///
  /// In ar, this message translates to:
  /// **'موقوفون'**
  String get suspended;

  /// No description provided for @retired.
  ///
  /// In ar, this message translates to:
  /// **'متقاعدون'**
  String get retired;

  /// No description provided for @archivedCount.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشفون'**
  String get archivedCount;

  /// No description provided for @otherStatuses.
  ///
  /// In ar, this message translates to:
  /// **'حالات أخرى'**
  String get otherStatuses;

  /// No description provided for @todaysPermanence.
  ///
  /// In ar, this message translates to:
  /// **'مداومة اليوم'**
  String get todaysPermanence;

  /// No description provided for @todaysAlerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات اليوم'**
  String get todaysAlerts;

  /// No description provided for @leavesEndingToday.
  ///
  /// In ar, this message translates to:
  /// **'رخص تنتهي اليوم'**
  String get leavesEndingToday;

  /// No description provided for @leavesEndingTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'رخص تنتهي غداً'**
  String get leavesEndingTomorrow;

  /// No description provided for @employeesReturningToday.
  ///
  /// In ar, this message translates to:
  /// **'موظفون يعودون اليوم'**
  String get employeesReturningToday;

  /// No description provided for @leavesEndingIn3Days.
  ///
  /// In ar, this message translates to:
  /// **'رخص تنتهي خلال 3 أيام'**
  String get leavesEndingIn3Days;

  /// No description provided for @todaysPermanenceCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} موظف مداوم اليوم'**
  String todaysPermanenceCount(int count);

  /// No description provided for @noAlertsToday.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تنبيهات لليوم'**
  String get noAlertsToday;

  /// No description provided for @noPermanenceToday.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مداومة لهذا اليوم'**
  String get noPermanenceToday;

  /// No description provided for @quickActions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get quickActions;

  /// No description provided for @reports.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get reports;

  /// No description provided for @employeesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الموظفون'**
  String get employeesTitle;

  /// No description provided for @addEmployee.
  ///
  /// In ar, this message translates to:
  /// **'إضافة موظف'**
  String get addEmployee;

  /// No description provided for @editEmployee.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الموظف'**
  String get editEmployee;

  /// No description provided for @employeeProfile.
  ///
  /// In ar, this message translates to:
  /// **'ملف الموظف'**
  String get employeeProfile;

  /// No description provided for @employeeCard.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة موظف'**
  String get employeeCard;

  /// No description provided for @openProfile.
  ///
  /// In ar, this message translates to:
  /// **'فتح الملف'**
  String get openProfile;

  /// No description provided for @noEmployees.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موظفون'**
  String get noEmployees;

  /// No description provided for @noEmployeesHint.
  ///
  /// In ar, this message translates to:
  /// **'استورد ملف CSV أو أضف موظفاً يدوياً للبدء.'**
  String get noEmployeesHint;

  /// No description provided for @searchResultsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} نتيجة'**
  String searchResultsCount(int count);

  /// No description provided for @tabInfo.
  ///
  /// In ar, this message translates to:
  /// **'المعلومات'**
  String get tabInfo;

  /// No description provided for @tabStatus.
  ///
  /// In ar, this message translates to:
  /// **'الوضعية'**
  String get tabStatus;

  /// No description provided for @tabLeaves.
  ///
  /// In ar, this message translates to:
  /// **'العطل والرخص'**
  String get tabLeaves;

  /// No description provided for @tabPermanence.
  ///
  /// In ar, this message translates to:
  /// **'المداومة'**
  String get tabPermanence;

  /// No description provided for @tabHistory.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get tabHistory;

  /// No description provided for @matricule.
  ///
  /// In ar, this message translates to:
  /// **'Matricule'**
  String get matricule;

  /// No description provided for @ppr.
  ///
  /// In ar, this message translates to:
  /// **'PPR'**
  String get ppr;

  /// No description provided for @nomAr.
  ///
  /// In ar, this message translates to:
  /// **'الاسم (عربي)'**
  String get nomAr;

  /// No description provided for @prenomAr.
  ///
  /// In ar, this message translates to:
  /// **'اللقب (عربي)'**
  String get prenomAr;

  /// No description provided for @nomFr.
  ///
  /// In ar, this message translates to:
  /// **'Nom'**
  String get nomFr;

  /// No description provided for @prenomFr.
  ///
  /// In ar, this message translates to:
  /// **'Prénom'**
  String get prenomFr;

  /// No description provided for @fullNameAr.
  ///
  /// In ar, this message translates to:
  /// **'الاسم بالعربية'**
  String get fullNameAr;

  /// No description provided for @fullNameFr.
  ///
  /// In ar, this message translates to:
  /// **'الاسم بالفرنسية'**
  String get fullNameFr;

  /// No description provided for @section.
  ///
  /// In ar, this message translates to:
  /// **'القسم'**
  String get section;

  /// No description provided for @grade.
  ///
  /// In ar, this message translates to:
  /// **'الرتبة'**
  String get grade;

  /// No description provided for @fonction.
  ///
  /// In ar, this message translates to:
  /// **'الوظيفة'**
  String get fonction;

  /// No description provided for @quality.
  ///
  /// In ar, this message translates to:
  /// **'Qualité'**
  String get quality;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف'**
  String get phone;

  /// No description provided for @mobilePhone.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف المحمول'**
  String get mobilePhone;

  /// No description provided for @currentStatus.
  ///
  /// In ar, this message translates to:
  /// **'الوضعية الحالية'**
  String get currentStatus;

  /// No description provided for @chooseSection.
  ///
  /// In ar, this message translates to:
  /// **'اختر القسم'**
  String get chooseSection;

  /// No description provided for @chooseGrade.
  ///
  /// In ar, this message translates to:
  /// **'اختر الرتبة'**
  String get chooseGrade;

  /// No description provided for @chooseFunction.
  ///
  /// In ar, this message translates to:
  /// **'اختر الوظيفة'**
  String get chooseFunction;

  /// No description provided for @chooseStatus.
  ///
  /// In ar, this message translates to:
  /// **'اختر الوضعية'**
  String get chooseStatus;

  /// No description provided for @chooseEmployee.
  ///
  /// In ar, this message translates to:
  /// **'اختر الموظف'**
  String get chooseEmployee;

  /// No description provided for @chooseLeaveType.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الرخصة'**
  String get chooseLeaveType;

  /// No description provided for @chooseDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ'**
  String get chooseDate;

  /// No description provided for @searchEmployee.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن موظف…'**
  String get searchEmployee;

  /// No description provided for @errMatriculeRequired.
  ///
  /// In ar, this message translates to:
  /// **'حقل Matricule إلزامي ولا يمكن أن يكون فارغاً.'**
  String get errMatriculeRequired;

  /// No description provided for @errMatriculeDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'رقم Matricule مستخدم لموظف آخر.'**
  String get errMatriculeDuplicate;

  /// No description provided for @errPprDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'رقم PPR مستخدم لموظف آخر.'**
  String get errPprDuplicate;

  /// No description provided for @errNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'يجب إدخال الاسم بالعربية أو الفرنسية.'**
  String get errNameRequired;

  /// No description provided for @errFieldRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل إلزامي.'**
  String get errFieldRequired;

  /// No description provided for @errInvalidDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ غير صالح.'**
  String get errInvalidDate;

  /// No description provided for @errEndBeforeStart.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ النهاية يجب أن يكون بعد تاريخ البداية.'**
  String get errEndBeforeStart;

  /// No description provided for @errNegativeDuration.
  ///
  /// In ar, this message translates to:
  /// **'المدة يجب أن تكون أكبر من صفر.'**
  String get errNegativeDuration;

  /// No description provided for @errInvalidHours.
  ///
  /// In ar, this message translates to:
  /// **'قيمة ساعات غير صالحة.'**
  String get errInvalidHours;

  /// No description provided for @errInvalidPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتف غير صالح.'**
  String get errInvalidPhone;

  /// No description provided for @errInvalidPpr.
  ///
  /// In ar, this message translates to:
  /// **'قيمة PPR غير صالحة.'**
  String get errInvalidPpr;

  /// No description provided for @errEmptyFile.
  ///
  /// In ar, this message translates to:
  /// **'الملف فارغ.'**
  String get errEmptyFile;

  /// No description provided for @errMissingColumn.
  ///
  /// In ar, this message translates to:
  /// **'تعذر استيراد الملف لأن العمود {column} غير موجود.'**
  String errMissingColumn(String column);

  /// No description provided for @errInvalidDateFormat.
  ///
  /// In ar, this message translates to:
  /// **'تنسيق تاريخ غير معروف: \"{value}\"'**
  String errInvalidDateFormat(String value);

  /// No description provided for @errUnknown.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع. راجع السجل التقني للتفاصيل.'**
  String get errUnknown;

  /// No description provided for @errSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر حفظ البيانات. تأكد من صحة المدخلات.'**
  String get errSaveFailed;

  /// No description provided for @errImportFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر استيراد الملف.'**
  String get errImportFailed;

  /// No description provided for @importTitle.
  ///
  /// In ar, this message translates to:
  /// **'استيراد CSV'**
  String get importTitle;

  /// No description provided for @importEmployees.
  ///
  /// In ar, this message translates to:
  /// **'استيراد CSV موظفين'**
  String get importEmployees;

  /// No description provided for @importPermanence.
  ///
  /// In ar, this message translates to:
  /// **'استيراد CSV مداومة'**
  String get importPermanence;

  /// No description provided for @selectFile.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملفاً'**
  String get selectFile;

  /// No description provided for @fileName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الملف'**
  String get fileName;

  /// No description provided for @preview.
  ///
  /// In ar, this message translates to:
  /// **'معاينة'**
  String get preview;

  /// No description provided for @previewTitle.
  ///
  /// In ar, this message translates to:
  /// **'معاينة الاستيراد'**
  String get previewTitle;

  /// No description provided for @columns.
  ///
  /// In ar, this message translates to:
  /// **'الأعمدة'**
  String get columns;

  /// No description provided for @delimiter.
  ///
  /// In ar, this message translates to:
  /// **'Delimiter'**
  String get delimiter;

  /// No description provided for @encoding.
  ///
  /// In ar, this message translates to:
  /// **'الترميز'**
  String get encoding;

  /// No description provided for @dateFormat.
  ///
  /// In ar, this message translates to:
  /// **'تنسيق التاريخ'**
  String get dateFormat;

  /// No description provided for @detectedFormat.
  ///
  /// In ar, this message translates to:
  /// **'التنسيق المتعرَّف عليه'**
  String get detectedFormat;

  /// No description provided for @columnMapping.
  ///
  /// In ar, this message translates to:
  /// **'مطابقة الأعمدة'**
  String get columnMapping;

  /// No description provided for @csvColumn.
  ///
  /// In ar, this message translates to:
  /// **'عمود CSV'**
  String get csvColumn;

  /// No description provided for @mapsTo.
  ///
  /// In ar, this message translates to:
  /// **'يطابق'**
  String get mapsTo;

  /// No description provided for @ignoreColumn.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get ignoreColumn;

  /// No description provided for @totalRows.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي السجلات'**
  String get totalRows;

  /// No description provided for @newRows.
  ///
  /// In ar, this message translates to:
  /// **'سجلات جديدة'**
  String get newRows;

  /// No description provided for @updatedRows.
  ///
  /// In ar, this message translates to:
  /// **'سجلات سيتم تحديثها'**
  String get updatedRows;

  /// No description provided for @duplicateRows.
  ///
  /// In ar, this message translates to:
  /// **'سجلات مكررة'**
  String get duplicateRows;

  /// No description provided for @errorRows.
  ///
  /// In ar, this message translates to:
  /// **'سجلات بها أخطاء'**
  String get errorRows;

  /// No description provided for @validRows.
  ///
  /// In ar, this message translates to:
  /// **'سجلات مقبولة'**
  String get validRows;

  /// No description provided for @rejectedRows.
  ///
  /// In ar, this message translates to:
  /// **'سجلات مرفوضة'**
  String get rejectedRows;

  /// No description provided for @invalidRowsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصفوف المرفوضة'**
  String get invalidRowsTitle;

  /// No description provided for @rowNumber.
  ///
  /// In ar, this message translates to:
  /// **'صف {n}'**
  String rowNumber(int n);

  /// No description provided for @confirmImport.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الاستيراد'**
  String get confirmImport;

  /// No description provided for @importSucceeded.
  ///
  /// In ar, this message translates to:
  /// **'تم الاستيراد بنجاح'**
  String get importSucceeded;

  /// No description provided for @importRolledBack.
  ///
  /// In ar, this message translates to:
  /// **'فشل الاستيراد وتم التراجع عن كل التغييرات.'**
  String get importRolledBack;

  /// No description provided for @unmatchedEmployees.
  ///
  /// In ar, this message translates to:
  /// **'موظفون غير مربوطون'**
  String get unmatchedEmployees;

  /// No description provided for @unmatchedHint.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على هؤلاء الموظفين في قاعدة البيانات. لن يتم إنشاؤهم تلقائياً.'**
  String get unmatchedHint;

  /// No description provided for @matchedCount.
  ///
  /// In ar, this message translates to:
  /// **'مرتبطة: {count}'**
  String matchedCount(int count);

  /// No description provided for @unmatchedCount.
  ///
  /// In ar, this message translates to:
  /// **'غير مربوطة: {count}'**
  String unmatchedCount(int count);

  /// No description provided for @importMode.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الاستيراد'**
  String get importMode;

  /// No description provided for @modeAddWeek.
  ///
  /// In ar, this message translates to:
  /// **'إضافة السجلات الجديدة'**
  String get modeAddWeek;

  /// No description provided for @modeUpdateWeek.
  ///
  /// In ar, this message translates to:
  /// **'تحديث السجلات الموجودة'**
  String get modeUpdateWeek;

  /// No description provided for @modeReplaceRange.
  ///
  /// In ar, this message translates to:
  /// **'استبدال الفترة المحددة'**
  String get modeReplaceRange;

  /// No description provided for @replaceWarning.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من استبدال بيانات الفترة المحددة؟ سيتم حذف السجلات الموجودة في هذه الفترة أولاً.'**
  String get replaceWarning;

  /// No description provided for @manualAddEmployee.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الموظفين المفقودين يدوياً'**
  String get manualAddEmployee;

  /// No description provided for @skipUnmatched.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل السجلات غير المربوطة'**
  String get skipUnmatched;

  /// No description provided for @statusHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل الوضعيات'**
  String get statusHistory;

  /// No description provided for @addStatus.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وضعية'**
  String get addStatus;

  /// No description provided for @editStatus.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الوضعية'**
  String get editStatus;

  /// No description provided for @statusType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الوضعية'**
  String get statusType;

  /// No description provided for @priority.
  ///
  /// In ar, this message translates to:
  /// **'الأولوية'**
  String get priority;

  /// No description provided for @priorityHint.
  ///
  /// In ar, this message translates to:
  /// **'كلما زادت الأولوية تغلّبت الحالة عند التداخل.'**
  String get priorityHint;

  /// No description provided for @startDateRequired.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ البداية إلزامي.'**
  String get startDateRequired;

  /// No description provided for @noStatusHistory.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سجل للوضعيات'**
  String get noStatusHistory;

  /// No description provided for @noStatusHistoryHint.
  ///
  /// In ar, this message translates to:
  /// **'عند تغيير وضعية الموظف سيظهر السجل هنا.'**
  String get noStatusHistoryHint;

  /// No description provided for @currentRecord.
  ///
  /// In ar, this message translates to:
  /// **'السجل الحالي'**
  String get currentRecord;

  /// No description provided for @previousRecords.
  ///
  /// In ar, this message translates to:
  /// **'السجل السابق'**
  String get previousRecords;

  /// No description provided for @terminalStatus.
  ///
  /// In ar, this message translates to:
  /// **'حالة نهائية'**
  String get terminalStatus;

  /// No description provided for @derivedStatus.
  ///
  /// In ar, this message translates to:
  /// **'مشتقة من الرخصة'**
  String get derivedStatus;

  /// No description provided for @changeStatus.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الوضعية'**
  String get changeStatus;

  /// No description provided for @conflictDetected.
  ///
  /// In ar, this message translates to:
  /// **'تم رصد تعارض'**
  String get conflictDetected;

  /// No description provided for @conflictMessage.
  ///
  /// In ar, this message translates to:
  /// **'هناك فترة متداخلة مع سجل موجود. لم يتم تطبيق الحالة تلقائياً.'**
  String get conflictMessage;

  /// No description provided for @conflictPeriod.
  ///
  /// In ar, this message translates to:
  /// **'فترة التداخل'**
  String get conflictPeriod;

  /// No description provided for @existingRecord.
  ///
  /// In ar, this message translates to:
  /// **'السجل الحالي'**
  String get existingRecord;

  /// No description provided for @newRecord.
  ///
  /// In ar, this message translates to:
  /// **'السجل الجديد'**
  String get newRecord;

  /// No description provided for @saveAnyway.
  ///
  /// In ar, this message translates to:
  /// **'حفظ على أي حال'**
  String get saveAnyway;

  /// No description provided for @leavesTitle.
  ///
  /// In ar, this message translates to:
  /// **'العطل والرخص'**
  String get leavesTitle;

  /// No description provided for @addLeave.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رخصة'**
  String get addLeave;

  /// No description provided for @editLeave.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرخصة'**
  String get editLeave;

  /// No description provided for @leaveType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الرخصة'**
  String get leaveType;

  /// No description provided for @leaveTypes.
  ///
  /// In ar, this message translates to:
  /// **'أنواع الرخص'**
  String get leaveTypes;

  /// No description provided for @addLeaveType.
  ///
  /// In ar, this message translates to:
  /// **'إضافة نوع رخصة'**
  String get addLeaveType;

  /// No description provided for @editLeaveType.
  ///
  /// In ar, this message translates to:
  /// **'تعديل نوع الرخصة'**
  String get editLeaveType;

  /// No description provided for @leavesCurrent.
  ///
  /// In ar, this message translates to:
  /// **'الحالية'**
  String get leavesCurrent;

  /// No description provided for @leavesUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get leavesUpcoming;

  /// No description provided for @leavesEnded.
  ///
  /// In ar, this message translates to:
  /// **'المنتهية'**
  String get leavesEnded;

  /// No description provided for @noLeaves.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رخص حالياً'**
  String get noLeaves;

  /// No description provided for @noLeavesHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «إضافة رخصة» لتسجيل رخصة جديدة.'**
  String get noLeavesHint;

  /// No description provided for @duration.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get duration;

  /// No description provided for @unit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get unit;

  /// No description provided for @unitHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات'**
  String get unitHours;

  /// No description provided for @unitDays.
  ///
  /// In ar, this message translates to:
  /// **'أيام'**
  String get unitDays;

  /// No description provided for @calculated.
  ///
  /// In ar, this message translates to:
  /// **'المحسوب تلقائياً'**
  String get calculated;

  /// No description provided for @calculatedEnd.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ النهاية المحسوب'**
  String get calculatedEnd;

  /// No description provided for @calculatedReturn.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ العودة المحسوب'**
  String get calculatedReturn;

  /// No description provided for @countStartDay.
  ///
  /// In ar, this message translates to:
  /// **'احتساب يوم البداية'**
  String get countStartDay;

  /// No description provided for @includeWeekends.
  ///
  /// In ar, this message translates to:
  /// **'احتساب نهاية الأسبوع'**
  String get includeWeekends;

  /// No description provided for @includeHolidays.
  ///
  /// In ar, this message translates to:
  /// **'احتساب العطل الرسمية'**
  String get includeHolidays;

  /// No description provided for @dayCountMode.
  ///
  /// In ar, this message translates to:
  /// **'طريقة احتساب الأيام'**
  String get dayCountMode;

  /// No description provided for @modeCalendar.
  ///
  /// In ar, this message translates to:
  /// **'أيام تقويم'**
  String get modeCalendar;

  /// No description provided for @modeWorking.
  ///
  /// In ar, this message translates to:
  /// **'أيام عمل'**
  String get modeWorking;

  /// No description provided for @returnDayMode.
  ///
  /// In ar, this message translates to:
  /// **'طريقة حساب العودة'**
  String get returnDayMode;

  /// No description provided for @returnImmediate.
  ///
  /// In ar, this message translates to:
  /// **'مباشرة (اليوم التالي)'**
  String get returnImmediate;

  /// No description provided for @returnNextWorking.
  ///
  /// In ar, this message translates to:
  /// **'أول يوم عمل'**
  String get returnNextWorking;

  /// No description provided for @cancelLeave.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الرخصة'**
  String get cancelLeave;

  /// No description provided for @leaveCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الرخصة'**
  String get leaveCancelled;

  /// No description provided for @conflictLeaveOverlap.
  ///
  /// In ar, this message translates to:
  /// **'توجد رخصة أخرى متداخلة مع هذه الفترة.'**
  String get conflictLeaveOverlap;

  /// No description provided for @businessDefaults.
  ///
  /// In ar, this message translates to:
  /// **'القيم الافتراضية القابلة للتعديل'**
  String get businessDefaults;

  /// No description provided for @businessDefaultsHint.
  ///
  /// In ar, this message translates to:
  /// **'كل المدد والقواعد قابلة للتعديل ولا توجد قيم ثابتة في الكود.'**
  String get businessDefaultsHint;

  /// No description provided for @permanenceTitle.
  ///
  /// In ar, this message translates to:
  /// **'المداومة'**
  String get permanenceTitle;

  /// No description provided for @addPermanence.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مداومة يدوياً'**
  String get addPermanence;

  /// No description provided for @editPermanence.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المداومة'**
  String get editPermanence;

  /// No description provided for @permanenceToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get permanenceToday;

  /// No description provided for @permanenceWeek.
  ///
  /// In ar, this message translates to:
  /// **'الأسبوع'**
  String get permanenceWeek;

  /// No description provided for @permanenceArchive.
  ///
  /// In ar, this message translates to:
  /// **'الأرشيف'**
  String get permanenceArchive;

  /// No description provided for @prevDay.
  ///
  /// In ar, this message translates to:
  /// **'اليوم السابق'**
  String get prevDay;

  /// No description provided for @nextDay.
  ///
  /// In ar, this message translates to:
  /// **'اليوم التالي'**
  String get nextDay;

  /// No description provided for @prevWeek.
  ///
  /// In ar, this message translates to:
  /// **'الأسبوع السابق'**
  String get prevWeek;

  /// No description provided for @nextWeek.
  ///
  /// In ar, this message translates to:
  /// **'الأسبوع التالي'**
  String get nextWeek;

  /// No description provided for @currentWeek.
  ///
  /// In ar, this message translates to:
  /// **'الأسبوع الحالي'**
  String get currentWeek;

  /// No description provided for @weekRange.
  ///
  /// In ar, this message translates to:
  /// **'{from} — {to}'**
  String weekRange(String from, String to);

  /// No description provided for @noPermanence.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مداومة لهذا اليوم'**
  String get noPermanence;

  /// No description provided for @noPermanenceWeek.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مداومة لهذا الأسبوع'**
  String get noPermanenceWeek;

  /// No description provided for @noPermanenceArchive.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سجلات مداومة'**
  String get noPermanenceArchive;

  /// No description provided for @permanencier.
  ///
  /// In ar, this message translates to:
  /// **'المناوب'**
  String get permanencier;

  /// No description provided for @schedule.
  ///
  /// In ar, this message translates to:
  /// **'المناوبة'**
  String get schedule;

  /// No description provided for @hpad.
  ///
  /// In ar, this message translates to:
  /// **'H-pad'**
  String get hpad;

  /// No description provided for @startTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت البداية'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت النهاية'**
  String get endTime;

  /// No description provided for @timeRange.
  ///
  /// In ar, this message translates to:
  /// **'الفترة الزمنية'**
  String get timeRange;

  /// No description provided for @unlinkedRecord.
  ///
  /// In ar, this message translates to:
  /// **'غير مربوط بموظف'**
  String get unlinkedRecord;

  /// No description provided for @linkedTo.
  ///
  /// In ar, this message translates to:
  /// **'مرتبط بـ'**
  String get linkedTo;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @sectionSecurity.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get sectionSecurity;

  /// No description provided for @sectionLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة والمظهر'**
  String get sectionLanguage;

  /// No description provided for @sectionData.
  ///
  /// In ar, this message translates to:
  /// **'البيانات'**
  String get sectionData;

  /// No description provided for @sectionLeaves.
  ///
  /// In ar, this message translates to:
  /// **'الرخص'**
  String get sectionLeaves;

  /// No description provided for @sectionReferences.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام والرتب'**
  String get sectionReferences;

  /// No description provided for @sectionBackup.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي'**
  String get sectionBackup;

  /// No description provided for @sectionAbout.
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get sectionAbout;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @languageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageFrench.
  ///
  /// In ar, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @darkMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get darkMode;

  /// No description provided for @changePin.
  ///
  /// In ar, this message translates to:
  /// **'تغيير رمز PIN'**
  String get changePin;

  /// No description provided for @enablePin.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل رمز PIN'**
  String get enablePin;

  /// No description provided for @disablePin.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل رمز PIN'**
  String get disablePin;

  /// No description provided for @biometric.
  ///
  /// In ar, this message translates to:
  /// **'البصمة'**
  String get biometric;

  /// No description provided for @biometricEnable.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل البصمة'**
  String get biometricEnable;

  /// No description provided for @biometricUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'البصمة غير متاحة على هذا الجهاز'**
  String get biometricUnavailable;

  /// No description provided for @autoLock.
  ///
  /// In ar, this message translates to:
  /// **'القفل التلقائي'**
  String get autoLock;

  /// No description provided for @autoLock1m.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get autoLock1m;

  /// No description provided for @autoLock5m.
  ///
  /// In ar, this message translates to:
  /// **'5 دقائق'**
  String get autoLock5m;

  /// No description provided for @autoLock15m.
  ///
  /// In ar, this message translates to:
  /// **'15 دقيقة'**
  String get autoLock15m;

  /// No description provided for @autoLockOff.
  ///
  /// In ar, this message translates to:
  /// **'معطّل'**
  String get autoLockOff;

  /// No description provided for @createPin.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ رمز PIN'**
  String get createPin;

  /// No description provided for @confirmPin.
  ///
  /// In ar, this message translates to:
  /// **'أكّد رمز PIN'**
  String get confirmPin;

  /// No description provided for @wrongPin.
  ///
  /// In ar, this message translates to:
  /// **'رمز PIN غير صحيح'**
  String get wrongPin;

  /// No description provided for @pinMismatch.
  ///
  /// In ar, this message translates to:
  /// **'الرمزان غير متطابقين'**
  String get pinMismatch;

  /// No description provided for @pinTooShort.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن يتكون الرمز من 4 أرقام على الأقل'**
  String get pinTooShort;

  /// No description provided for @sections.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام'**
  String get sections;

  /// No description provided for @grades.
  ///
  /// In ar, this message translates to:
  /// **'الرتب'**
  String get grades;

  /// No description provided for @functionsList.
  ///
  /// In ar, this message translates to:
  /// **'الوظائف'**
  String get functionsList;

  /// No description provided for @statusTypesList.
  ///
  /// In ar, this message translates to:
  /// **'أنواع الوضعيات'**
  String get statusTypesList;

  /// No description provided for @holidays.
  ///
  /// In ar, this message translates to:
  /// **'العطل الرسمية'**
  String get holidays;

  /// No description provided for @addSection.
  ///
  /// In ar, this message translates to:
  /// **'إضافة قسم'**
  String get addSection;

  /// No description provided for @addGrade.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رتبة'**
  String get addGrade;

  /// No description provided for @addFunction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وظيفة'**
  String get addFunction;

  /// No description provided for @addHoliday.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عطلة رسمية'**
  String get addHoliday;

  /// No description provided for @manage.
  ///
  /// In ar, this message translates to:
  /// **'إدارة'**
  String get manage;

  /// No description provided for @rename.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تسمية'**
  String get rename;

  /// No description provided for @deactivate.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل'**
  String get deactivate;

  /// No description provided for @reactivate.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تفعيل'**
  String get reactivate;

  /// No description provided for @historyKept.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التسمية لا تكسر السجل التاريخي.'**
  String get historyKept;

  /// No description provided for @noSections.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أقسام'**
  String get noSections;

  /// No description provided for @noGrades.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رتب'**
  String get noGrades;

  /// No description provided for @noFunctions.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وظائف'**
  String get noFunctions;

  /// No description provided for @noHolidays.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عطل رسمية'**
  String get noHolidays;

  /// No description provided for @exportData.
  ///
  /// In ar, this message translates to:
  /// **'تصدير البيانات'**
  String get exportData;

  /// No description provided for @exportCsv.
  ///
  /// In ar, this message translates to:
  /// **'تصدير CSV'**
  String get exportCsv;

  /// No description provided for @importData.
  ///
  /// In ar, this message translates to:
  /// **'استيراد البيانات'**
  String get importData;

  /// No description provided for @aboutTitle.
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get aboutTitle;

  /// No description provided for @version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get version;

  /// No description provided for @schemaVersion.
  ///
  /// In ar, this message translates to:
  /// **'إصدار المخطط'**
  String get schemaVersion;

  /// No description provided for @offlineNote.
  ///
  /// In ar, this message translates to:
  /// **'هذا التطبيق يعمل محلياً بالكامل ولا يرسل أي بيانات خارج الجهاز.'**
  String get offlineNote;

  /// No description provided for @createBackup.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء نسخة احتياطية'**
  String get createBackup;

  /// No description provided for @restoreBackup.
  ///
  /// In ar, this message translates to:
  /// **'استعادة نسخة احتياطية'**
  String get restoreBackup;

  /// No description provided for @backupCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء النسخة الاحتياطية'**
  String get backupCreated;

  /// No description provided for @backupEncrypted.
  ///
  /// In ar, this message translates to:
  /// **'مشفّرة (AES-256-GCM)'**
  String get backupEncrypted;

  /// No description provided for @restoreTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة النسخة الاحتياطية'**
  String get restoreTitle;

  /// No description provided for @restoreWarning.
  ///
  /// In ar, this message translates to:
  /// **'استعادة النسخة الاحتياطية ستستبدل كل البيانات الحالية. هل أنت متأكد؟'**
  String get restoreWarning;

  /// No description provided for @restoreSucceeded.
  ///
  /// In ar, this message translates to:
  /// **'تمت الاستعادة بنجاح'**
  String get restoreSucceeded;

  /// No description provided for @backupCorrupt.
  ///
  /// In ar, this message translates to:
  /// **'ملف النسخة الاحتياطية تالف أو غير متوافق.'**
  String get backupCorrupt;

  /// No description provided for @backupWrongKey.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فك التشفير. مفتاح الاستعادة غير صحيح.'**
  String get backupWrongKey;

  /// No description provided for @backupChecksum.
  ///
  /// In ar, this message translates to:
  /// **'فشل التحقق من السلامة (checksum).'**
  String get backupChecksum;

  /// No description provided for @backupVersionMismatch.
  ///
  /// In ar, this message translates to:
  /// **'إصدار النسخة غير مدعوم.'**
  String get backupVersionMismatch;

  /// No description provided for @backupNoFile.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم اختيار ملف.'**
  String get backupNoFile;

  /// No description provided for @backupIncludeAudit.
  ///
  /// In ar, this message translates to:
  /// **'تضمين سجل التدقيق'**
  String get backupIncludeAudit;

  /// No description provided for @recentBackups.
  ///
  /// In ar, this message translates to:
  /// **'آخر النسخ'**
  String get recentBackups;

  /// No description provided for @reportEmployeesBySection.
  ///
  /// In ar, this message translates to:
  /// **'الموظفون حسب القسم'**
  String get reportEmployeesBySection;

  /// No description provided for @reportEmployeesByStatus.
  ///
  /// In ar, this message translates to:
  /// **'الموظفون حسب الوضعية'**
  String get reportEmployeesByStatus;

  /// No description provided for @reportCurrentLeaves.
  ///
  /// In ar, this message translates to:
  /// **'العطل الحالية'**
  String get reportCurrentLeaves;

  /// No description provided for @reportEndedLeaves.
  ///
  /// In ar, this message translates to:
  /// **'الرخص المنتهية'**
  String get reportEndedLeaves;

  /// No description provided for @reportUpcomingLeaves.
  ///
  /// In ar, this message translates to:
  /// **'الرخص القادمة'**
  String get reportUpcomingLeaves;

  /// No description provided for @reportPermanenceByDay.
  ///
  /// In ar, this message translates to:
  /// **'المداومون حسب اليوم'**
  String get reportPermanenceByDay;

  /// No description provided for @reportPermanenceByWeek.
  ///
  /// In ar, this message translates to:
  /// **'المداومون حسب الأسبوع'**
  String get reportPermanenceByWeek;

  /// No description provided for @reportEmployeesByGrade.
  ///
  /// In ar, this message translates to:
  /// **'الموظفون حسب الرتبة'**
  String get reportEmployeesByGrade;

  /// No description provided for @reportEmployeesByFunction.
  ///
  /// In ar, this message translates to:
  /// **'الموظفون حسب الوظيفة'**
  String get reportEmployeesByFunction;

  /// No description provided for @generateReport.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء التقرير'**
  String get generateReport;

  /// No description provided for @exportResults.
  ///
  /// In ar, this message translates to:
  /// **'تصدير النتائج'**
  String get exportResults;

  /// No description provided for @auditLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل التدقيق'**
  String get auditLog;

  /// No description provided for @auditCreated.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get auditCreated;

  /// No description provided for @auditUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get auditUpdated;

  /// No description provided for @auditDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get auditDeleted;

  /// No description provided for @auditImported.
  ///
  /// In ar, this message translates to:
  /// **'استيراد'**
  String get auditImported;

  /// No description provided for @auditRestored.
  ///
  /// In ar, this message translates to:
  /// **'استعادة'**
  String get auditRestored;

  /// No description provided for @auditNoLogs.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سجلات'**
  String get auditNoLogs;

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @notificationsEnable.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الإشعارات المحلية'**
  String get notificationsEnable;

  /// No description provided for @notifLeaveEndsTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي رخصة {name} غداً.'**
  String notifLeaveEndsTomorrow(String name);

  /// No description provided for @notifEmployeeReturnsToday.
  ///
  /// In ar, this message translates to:
  /// **'يعود الموظف {name} اليوم.'**
  String notifEmployeeReturnsToday(String name);

  /// No description provided for @notifPermanenceCount.
  ///
  /// In ar, this message translates to:
  /// **'لديك {count} موظف مداوم اليوم.'**
  String notifPermanenceCount(int count);

  /// No description provided for @lockedTitle.
  ///
  /// In ar, this message translates to:
  /// **'التطبيق مقفل'**
  String get lockedTitle;

  /// No description provided for @unlockWithPin.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز PIN'**
  String get unlockWithPin;

  /// No description provided for @unlockWithBiometric.
  ///
  /// In ar, this message translates to:
  /// **'استخدم البصمة لفتح التطبيق'**
  String get unlockWithBiometric;

  /// No description provided for @unlock.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get unlock;

  /// No description provided for @forgotPin.
  ///
  /// In ar, this message translates to:
  /// **'نسيت الرمز؟'**
  String get forgotPin;

  /// No description provided for @forgotPinHint.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن استرجاع رمز PIN محفوظ. يجب إعادة تثبيت التطبيق مع فقدان البيانات ما لم تملك نسخة احتياطية.'**
  String get forgotPinHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
