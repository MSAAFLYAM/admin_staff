# ADMIN STAFF — نظام تدبير قاعدة بيانات موظفي مصلحة إدارية ولائية

تطبيق Android (Flutter + SQLite) يعمل **بالكامل بدون إنترنت**
لإدارة الموظفين والمداومة والوضعيات الإدارية والعطل والرخص،
بواجهة Dark احترافية تدعم **العربية (RTL)** و**الفرنسية (LTR)**.

---

## ✨ المزايا

| القسم | الوظائف |
|---|---|
| **الموظفون** | CRUD كامل، ملف موظف بـ 5 تبويبات، أرشفة (soft delete) |
| **الاستيراد CSV** | Preview + Column Mapping + Validation + كشف تكرار + Transaction |
| **البحث** | عالمي في كل الحقول + Advanced Filter (AND/OR) + فلاتر محفوظة |
| **الوضعيات** | جدول مرجعي قابل للإدارة + سجل تاريخي كامل + حالات مستنتجة |
| **الرخص** | أنواع قابلة للتعديل + محرك حساب منفصل (ساعات/أيام/أيام عمل) |
| **المداومة** | يومي/أسبوعي/أرشيف + ربط بـ Matricule + Unmatched + منع تكرار |
| **Dashboard** | إحصائيات حقيقية من SQL + مداومة اليوم + تنبيهات اليوم |
| **Backup** | مشفّر AES-256-GCM + checksum + schema_version |
| **الأمان** | PIN (PBKDF2) + Biometric + Auto Lock |
| **التصدير** | CSV مع UTF-8 BOM للتوافق مع Excel |

**التكلفة التشغيلية: $0** — راجع [COSTS.md](COSTS.md)

---

## 🏗️ البنية

**Clean Architecture / Feature-based** — راجع [ARCHITECTURE.md](docs/ARCHITECTURE.md)

```
lib/
├── core/           # Database, Theme, Utils, CSV, Logging
├── models/         # نماذج نقيّة (pure Dart)
├── repositories/   # طبقة الوصول للبيانات
├── services/       # منطق الأعمال (Leave Calculator, Import, Backup…)
├── features/       # شاشات مقسّمة حسب الميزة
├── localization/   # ARB files (ar / fr)
└── widgets/        # عناصر عامة قابلة لإعادة الاستخدام
```

---

## 📚 التوثيق

| الملف | المحتوى |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | هندسة المشروع وتدفق البيانات |
| [DATABASE.md](docs/DATABASE.md) | مخطط SQLite الكامل + الفهارس |
| [IMPORT_FORMAT.md](docs/IMPORT_FORMAT.md) | صيغ CSV الرسمية |
| [LEAVE_RULES.md](docs/LEAVE_RULES.md) | قواعد الرخص ومحرك الحساب |
| [DECISIONS.md](docs/DECISIONS.md) | القرارات التقنية الموثّقة |
| [TESTING.md](TESTING.md) | خطة الاختبارات |
| [COSTS.md](COSTS.md) | فحص التكلفة ($0) |
| [CHANGELOG.md](CHANGELOG.md) | سجل التغييرات |

---

## 🛠️ متطلبات البناء

| الأداة | الإصدار | الحالة |
|---|---|---|
| Flutter SDK | 3.47.6 stable (Dart 3.13.5) | ✅ مثبّت |
| JDK | 17 (Temurin) | ✅ مثبّت |
| Android SDK | platform-35 + build-tools 35.0.0 + platform-tools | ✅ مثبّت |
| Android cmdline-tools | latest | ✅ مثبّت |

> **مجانية بالكامل** — لا حسابات، لا بطاقات بنكية، لا اشتراكات.

---

## 📦 التبعيات

| الحزمة | الرخصة | الغرض |
|---|---|---|
| `sqflite` | BSD-3-Clause | SQLite على Android |
| `sqflite_common_ffi` | BSD-3-Clause | SQLite في الاختبارات |
| `flutter_riverpod` | MIT | إدارة الحالة + DI |
| `go_router` | BSD-3-Clause | التنقل |
| `intl` | MIT | التنسيق + l10n |
| `flutter_secure_storage` | Apache-2.0 | تخزين آمن |
| `local_auth` | BSD-3-Clause | البصمة |
| `flutter_local_notifications` | Apache-2.0 | إشعارات محلية |
| `file_picker` | MIT | اختيار ملفات |
| `share_plus` | BSD-3-Clause | مشاركة ملفات |
| `cryptography` | MIT | AES-256-GCM |
| `crypto` | BSD-3-Clause | SHA-256 |
| `csv` | MIT | تحليل/كتابة CSV |

كلها مفتوحة المصدر ومجانية — التفاصيل في [COSTS.md](COSTS.md).

---

## 🚀 بناء التطبيق

```bash
# 1) تجهيز البيئة
export PATH="/c/flutter/bin:$PATH"
export ANDROID_HOME="/c/android-sdk"
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"

# 2) التحقق
flutter doctor

# 3) تثبيت التبعيات + توليد الترجمات
flutter pub get
flutter gen-l10n

# 4) التشغيل على جهاز متصل
flutter run

# 5) بناء APK للإنتاج
flutter build apk --release
# الناتج: build/app/outputs/flutter-apk/app-release.apk

# 6) تثبيت APK مباشرة على هاتف متصل
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### بناء App Bundle (للمتجر)

```bash
flutter build appbundle --release
# الناتج: build/app/outputs/bundle/release/app-release.aab
```

> ⚠️ **مساحة القرص:** بناء Android يستهلك 3–4 GB مؤقتاً
> (`~/.gradle/caches` + `build/` + NDK). إن توقف البناء بـ
> `There is not enough space on the disk` حرّر مساحة ثم أعد الأمر —
> لا ينتج ملف ناقص، البناء إمّا ينجح كاملاً أو يفشل كلياً.
>
> ✅ **التوقيع:** `signingConfig = debug` في `build.gradle.kts`
> — الـ APK قابل للتثبيت المباشر على أي هاتف (زر واحد).

### تشغيله على الحاسوب (Windows) — مرة واحدة فقط

المشروع يشمل `android/` فقط، فلإنشاء قشرة سطح المكتب:

```bash
flutter create --platforms=windows .     # يضيف مجلد windows/
flutter build windows --release          # exe جاهز
flutter run -d windows                   # تشغيل أثناء التطوير
# الناتج: build\windows\x64\runner\Release\admin_staff.exe
```

**لا يحتاج أي إعداد إضافي** — `AppDatabase._open()` يكتشف Windows
ويردّل تلقائياً إلى محرّك **`sqflite_common_ffi`** نفسه المستعمل في
الاختبارات، فـ SQL موحّد بين الهاتف والحاسوب. مكتبة SQLite تُحلّ
من `winsqlite3.dll` المدمجة في Windows 10/11 (لا حاجة لحزمة إضافية)،
وحفظ الملفات عبر `path_provider` في مجلد المستندات.

---

## 🧪 الاختبارات

```bash
flutter test                 # كل الاختبارات
flutter test test/unit       # وحدة فقط
flutter test test/database   # قاعدة البيانات
flutter test --coverage      # مع التغطية
flutter analyze              # تحليل الجودة
```

---

## 📥 الاستيراد

### 1. استيراد الموظفين

```
الموظفون  →  ⋮  →  استيراد CSV موظفين
  → اختر الملف
  → راجع Preview (الأعمدة، delimiter، تنسيق التاريخ)
  → عدّل Column Mapping إن لزم
  → راجع الأرقام (جديد / تحديث / مكرر / خطأ)
  → Confirm Import
```

الملف: [`sample_employees.csv`](sample_employees.csv)

### 2. استيراد المداومة

```
المداومة  →  ⋮  →  استيراد CSV مداومة
  → اختر الملف
  → اختر السياسة (Add / Update / Replace)
  → راجع Unmatched Employees
  → Confirm Import
```

الملف: [`sample_permanence.csv`](sample_permanence.csv)

الصيغة الكاملة: [IMPORT_FORMAT.md](docs/IMPORT_FORMAT.md)

---

## 📁 النسخ الاحتياطي

| البند | التفاصيل |
|---|---|
| الصيغة | `.asbak` (ZIP → AES-256-GCM) |
| المحتوى | كل الجداول + `schema_version` |
| التحقق | SHA-256 checksum |
| التشفير | AES-256-GCM بمفتاح من Android Keystore |
| الحماية | يُرفض أي ملف تالف أو مفتاح خاطئ |

---

## 🔒 الخصوصية والأمن

- ✅ لا بيانات تُرسل لخدمة خارجية
- ✅ لا Analytics خارجية
- ✅ لا AI API
- ✅ لا إعلانات ولا IAP
- ✅ لا نصوص حساسة في logs
- ✅ PIN مُجزّأ بـ PBKDF2 (120K iterations + salt)
- ✅ مفاتيح التشفير في Secure Storage فقط — **لا شيء في Git**

---

## 📱 اللغات

| اللغة | الاتجاه | الحالة |
|---|---|---|
| العربية | RTL | الافتراضية |
| الفرنسية | LTR | مدعومة |

كل النصوص في `lib/localization/l10n/*.arb` — **صفر نصوص في الكود**.

---

## 📋 Definition of Done

- [x] تثبيت التطبيق
- [x] فتحه بـ PIN
- [x] استيراد CSV الموظفين
- [x] البحث بأي حقل
- [x] Advanced Filters
- [x] فتح ملف الموظف
- [x] إضافة وضعية
- [x] إضافة رخصة
- [x] حساب تاريخ النهاية والعودة
- [x] تعديل أنواع الرخص
- [x] استيراد CSV المداومة
- [x] رؤية مداومة اليوم والأسبوع
- [x] ربط المداومة بالموظفين
- [x] منع التكرار
- [x] حفظ التاريخ
- [x] إنشاء Backup + Restore
- [x] Export
- [x] تشغيل جميع الاختبارات
- [x] عدم وجود أخطاء build
- [x] العمل Offline

---

## 📄 الرخصة

مشروع داخلي لإدارة إدارية. الحزم المستخدمة برخص مفتوحة المصدر
(MIT / BSD / Apache-2.0) — موثّقة في [COSTS.md](COSTS.md).
