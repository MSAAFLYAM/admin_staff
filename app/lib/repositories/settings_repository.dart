import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';

/// ★ مستودع الإعدادات (جدول `settings`: `key` / `value`).
///
/// **لا منطق ولا افتراضات في الكود:** القيم الافتراضية تُزرع مع
/// قاعدة البيانات (`AppDatabase.seed`)، والمستودع يقرأ ما هو
/// مكتوب ويرجع [fallback] فقط حين **لم يُكتب** المفتاح أصلاً.
///
/// لا يُسجّل في سجل التدقيق هنا (التدقيق طبقة الخدمات) — تغيير
/// الـ PIN مثلاً يُسجَّل من طبقة الأمان لا من هنا.
class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static String _now() => DateTime.now().toIso8601String();

  // ── القراءة والكتابة العامة ─────────────────────────────────

  /// قيمة المفتاح أو `null` إن لم يكن موجوداً.
  Future<String?> read(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      Db.settings,
      columns: <String>[Db.cValue],
      where: '${Db.cKey} = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[Db.cValue] as String?;
  }

  /// القيمة أو [fallback] إن لم يُكتب المفتاح (يختلف عن قيمة
  /// مكتوبة صراحةً بـ `''`).
  Future<String> readOr(String key, String fallback) async =>
      (await read(key)) ?? fallback;

  /// يكتب المفتاح — إنشاءً أو استبدالاً — ويحدّث `updated_at`.
  Future<void> write(String key, String value) async {
    await _db.insert(
      Db.settings,
      <String, Object?>{
        Db.cKey: key,
        Db.cValue: value,
        Db.cUpdatedAt: _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// كتابة عدة مفاتيح **داخل معاملة واحدة** — لا إعداد ناقص
  /// حين يفشل المنتصف.
  Future<void> writeMany(Map<String, String> values) async {
    if (values.isEmpty) return;
    await _db.transaction((Transaction txn) async {
      final Batch batch = txn.batch();
      for (final MapEntry<String, String> e in values.entries) {
        batch.insert(
          Db.settings,
          <String, Object?>{
            Db.cKey: e.key,
            Db.cValue: e.value,
            Db.cUpdatedAt: _now(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// يحذف مفتاحاً — يعود إلى القيمة الافتراضية عند القراءة.
  Future<void> delete(String key) async {
    await _db.delete(
      Db.settings,
      where: '${Db.cKey} = ?',
      whereArgs: <Object?>[key],
    );
  }

  /// كل الإعدادات المكتوبة — تُستعمل في النسخ الاحتياطي والتصدير.
  Future<Map<String, String>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(Db.settings);
    return <String, String>{
      for (final Map<String, Object?> r in rows)
        if (r[Db.cKey] is String) r[Db.cKey] as String: (r[Db.cValue] as String?) ?? '',
    };
  }

  // ── القيم المركّبة (JSON) ───────────────────────────────────

  /// يكتب قيمة JSON — تُستعمل لخرائط الاستيراد.
  Future<void> writeJson(String key, Object value) =>
      write(key, jsonEncode(value));

  /// يقرأ قيمة JSON — **ملف تالف يُرجع `null` ولا يوقف التطبيق**
  /// (قاعدة 49: المستخدم لا يرى `FormatException`).
  Future<Object?> readJson(String key) async {
    final String? raw = await read(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  // ── واجهات نوعية (لا نص مبعثّر في الواجهات) ────────────────

  /// لغة الواجهة — `ar` افتراضياً (D-015).
  Future<String> locale() => readOr(Db.keyLocale, 'ar');

  Future<void> setLocale(String code) async {
    const Set<String> supported = <String>{'ar', 'fr'};
    if (!supported.contains(code)) {
      throw AppException('لغة غير مدعومة: $code — المتاح: عربية أو فرنسية.');
    }
    await write(Db.keyLocale, code);
  }

  /// قراءة مفتاح ثنائي (`'1'`/`'0'`) — أي قيمة غير محددة تُعامل
  /// كـ «مطفأ» بدل أن تُسقط التطبيق.
  Future<bool> flag(String key, {bool fallback = false}) async {
    final String? v = await read(key);
    if (v == null) return fallback;
    return v.trim() == '1';
  }

  Future<void> setFlag(String key, bool enabled) =>
      write(key, enabled ? '1' : '0');

  Future<bool> pinEnabled() => flag(Db.keyPinEnabled);
  Future<void> setPinEnabled(bool on) => setFlag(Db.keyPinEnabled, on);

  Future<bool> biometricEnabled() => flag(Db.keyBiometricEnabled);
  Future<void> setBiometricEnabled(bool on) =>
      setFlag(Db.keyBiometricEnabled, on);

  Future<bool> notificationsEnabled({bool fallback = true}) =>
      flag(Db.keyNotificationsEnabled, fallback: fallback);
  Future<void> setNotificationsEnabled(bool on) =>
      setFlag(Db.keyNotificationsEnabled, on);

  /// دقائق القفل التلقائي — الافتراضي من القاعدة (`5`).
  ///
  /// قيمة مخزَّنة غير منطقية (صفرية/سالبة/أكبر من ساعة) تُعامَل
  /// كافتراضي ولا توقف التطبيق.
  Future<int> autoLockMinutes() async {
    final String? raw = await read(Db.keyAutoLockMinutes);
    final int? parsed = int.tryParse((raw ?? '').trim());
    if (parsed == null || parsed <= 0 || parsed > 60) return _autoLockFallback;
    return parsed;
  }

  /// يعكس `AppDatabase.seed` (`auto_lock_minutes = 5`) ويُستدعى
  /// فقط حين مُسح المفتاح أو كُتبت فيه قيمة غير منطقية.
  static const int _autoLockFallback = 5;

  Future<void> setAutoLockMinutes(int minutes) async {
    if (minutes <= 0 || minutes > 60) {
      throw AppException(
        'زمن القفل التلقائي يجب أن يكون بين دقيقة و60 دقيقة.',
      );
    }
    await write(Db.keyAutoLockMinutes, '$minutes');
  }

  /// هل القفل التلقائي مفعّل؟ **لا وجود = مفعّل** (الافتراضي من
  /// الزرع)، والـ `0` لا يُخزَّن في `auto_lock_minutes` لأن ذلك
  /// يقرأه [autoLockMinutes] كقيمة غير منطقية — بل مفتاح مستقل
  /// حتى يبقى معنى «معطّل» صريحاً.
  Future<bool> autoLockEnabled() =>
      flag(Db.keyAutoLockEnabled, fallback: true);

  Future<void> setAutoLockEnabled(bool on) =>
      setFlag(Db.keyAutoLockEnabled, on);

  /// تصفير مفتاح أمني (يُستدعى عند إلغاء PIN).
  Future<void> clearPinSecrets() => deleteMany(
        <String>[Db.keyPinHash, Db.keyPinSalt],
      );

  /// حذف عدة مفاتيح في معاملة واحدة.
  Future<void> deleteMany(List<String> keys) async {
    if (keys.isEmpty) return;
    await _db.delete(
      Db.settings,
      where: '${Db.cKey} IN (${List<String>.filled(keys.length, '?').join(',')})',
      whereArgs: keys,
    );
  }
}
