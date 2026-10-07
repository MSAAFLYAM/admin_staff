import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants/db_constants.dart';
import '../core/database/app_database.dart';
import '../core/error/app_exception.dart';
import '../repositories/audit_repository.dart';

/// ★ النسخ الاحتياطي والاستعادة — AES-256-GCM + SHA-256 (D-012).
///
/// **لا مفتاح يُخزَّن ولا يُكتب في الكود:** المفتاح يُشتقّ من
/// كلمة مرور المستخدم بـ PBKDF2-HMAC-SHA256 (120 ألف تكرار، ملحّ
/// عشوائي 16 بايت لكل نسخة)، والململف يحمل الملحّ ورقم العشوائية
/// فقط — لا كلمة المرور ولا المفتاح.
///
/// **صيغة الملف (v1):**
/// ```text
/// "ASBK" | الإصدار(1) | طول الترويسة(uint32 BE) | ترويسة JSON | الشيفرة
/// الترويسة: format, created_at, schema_version, kdf, iterations,
///           salt(b64), nonce(b64), checksum(sha256 الشيفرة), counts
/// ```
/// الترويسة **غير مشفّرة** عمداً حتى يستطيع التطبيق عرض تاريخ
/// النسخة وعدّ صفوفها قبل سؤاله عن كلمة المرور؛ لا تحوي بيانات
/// شخصية (CLI/خيار). أمّا `checksum` (SHA-256) فيُتحقّق منه
/// **قبل** فك التشفير — ملف مبتور يُرفض برسالة عربية بلا حساب.
///
/// **الاستعادة استبدال نقطة زمنية:** كل جداول البيانات تعود كما
/// كانت عند الإنشاء داخل معاملة واحدة (أي فشل = تراجع كامل)،
/// ويُضاف بعدها قيد `restore` واحد في سجل التدقيق. مفاتيح
/// `settings` الجهازية والأمنية **لا تُستعاد** أبداً (ملف PIN
/// من جهاز آخر كان سيقفل المستخدم خارج تطبيقه).
class BackupService {
  BackupService(this._database, {AuditRepository? audit})
      : _audit = audit ?? AuditRepository(_database);

  final AppDatabase _database;
  final AuditRepository _audit;

  Database get _db => _database.db;

  // ── ثوابت الصيغة ────────────────────────────────────────────

  static const List<int> _magic = <int>[0x41, 0x53, 0x42, 0x4B]; // "ASBK"
  static const int _formatVersion = 1;
  static const int _headerLengthSize = 4;

  /// PBKDF2 — نفس عدد تكرارات PIN (D-012).
  static const int kdfIterations = 120000;
  static const int _saltLength = 16;
  static const int _nonceLength = AesGcm.defaultNonceLength;
  static const int _macLength = 16;

  /// حدود معقولة لمعامل التكرار الخارج من ملف (يمنع طلباً
  /// احتيالياً يعلّق التطبيق بلا حساب).
  static const int _minIterations = 1000;
  static const int _maxIterations = 5000000;

  /// الجداول بترتيب **الإدراج** (الآباء أولاً)؛ الحذف يسير
  /// عكسه تماماً حتى لا ينتقض قيد `FOREIGN KEY`.
  static const List<String> tables = <String>[
    Db.sections,
    Db.grades,
    Db.functions,
    Db.statusTypes,
    Db.leaveTypes,
    Db.holidays,
    Db.employees,
    Db.statusHistory,
    Db.leaves,
    Db.permanence,
    Db.savedFilters,
    Db.importHistory,
    Db.auditLogs,
  ];

  /// ما يُصدَّر ويُستعاد من `settings` — **قائمة بيضاء**، فما لم
  /// يُدرج فيها صراحة لا يخرج من الجهاز أبداً.
  static const List<String> restorableSettingsKeys = <String>[
    Db.keyImportMappingEmployees,
    Db.keyImportMappingPermanence,
    Db.keySavedDelimiterEmployees,
    Db.keySavedDelimiterPermanence,
  ];

  // ── الإنشاء ────────────────────────────────────────────────

  /// يكتب نسخة مشفّرة إلى [destinationPath].
  Future<BackupInfo> create({
    required String password,
    required String destinationPath,
  }) async =>
      writeFile(
        path: destinationPath,
        password: password,
        payload: await _snapshot(),
      );

  /// يبني الملف من لقطة جاهزة — يستعمله الإنتاج عبر [create]،
  /// والاختبارات لصناعة صيغ خاطئة (مخطط أقدم، جدول مجهول).
  @visibleForTesting
  Future<BackupInfo> writeFile({
    required String path,
    required String password,
    required Map<String, Object?> payload,
  }) async {
    _checkPassword(password);

    final List<int> clearText = utf8.encode(jsonEncode(payload));

    final Random rnd = Random.secure();
    final Uint8List salt = _randomBytes(_saltLength, rnd);
    final Uint8List nonce = _randomBytes(_nonceLength, rnd);

    final SecretKey key = await _deriveKey(password, salt);
    final SecretBox box = await AesGcm.with256bits().encrypt(
      clearText,
      secretKey: key,
      nonce: nonce,
    );
    final Uint8List blob = Uint8List.fromList(
      <int>[...box.cipherText, ...box.mac.bytes],
    );
    final String checksum = sha256.convert(blob).toString();

    final Map<String, int> counts = _countsOf(payload);
    final String createdAt = DateTime.now().toIso8601String();

    final Map<String, Object?> header = <String, Object?>{
      'format': 'admin_staff_backup',
      'created_at': createdAt,
      'schema_version': Db.schemaVersion,
      'kdf': 'pbkdf2-sha256',
      'iterations': kdfIterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'checksum': checksum,
      'counts': counts,
    };
    final Uint8List headerBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(header)),
    );

    final BytesBuilder out = BytesBuilder();
    out.add(_magic);
    out.addByte(_formatVersion);
    _addUint32(out, headerBytes.length);
    out.add(headerBytes);
    out.add(blob);

    final Uint8List fileBytes = out.toBytes();
    final File file = File(path);
    await file.writeAsBytes(fileBytes, flush: true);

    await _audit.logBackup(
      'نسخة احتياطية مشفّرة (${counts.values.fold<int>(0, (int a, int b) => a + b)} صفّ، '
      '${_baseName(path)})',
    );

    return BackupInfo(
      createdAt: createdAt,
      schemaVersion: Db.schemaVersion,
      rowCounts: counts,
      fileBytes: fileBytes.length,
      checksum: checksum,
    );
  }

  /// معلومات الملف **بلا كلمة مرور** — للتعرّف على النسخة قبل
  /// سؤال المستخدم عن كلمة المرور.
  Future<BackupInfo> preview(String sourcePath) async {
    final Uint8List bytes = await _readBytes(sourcePath);
    final _Header h = _parseHeader(bytes);
    return BackupInfo(
      createdAt: h.createdAt,
      schemaVersion: h.schemaVersion,
      rowCounts: h.counts,
      fileBytes: bytes.length,
      checksum: h.checksum,
    );
  }

  // ── الاستعادة ─────────────────────────────────────────────

  /// يستبدل بيانات القاعدة بمحتوى الملف — **معاملة واحدة**، أي
  /// فشل في أي صفّ يرجع كل شيء كما كان.
  Future<RestoreReport> restore({
    required String sourcePath,
    required String password,
  }) async {
    _checkPassword(password);

    final Uint8List bytes = await _readBytes(sourcePath);
    final _Header h = _parseHeader(bytes);

    // 1) البصمة قبل أي حساب — ملف مبتور يُرفض بلا تشفير.
    final Uint8List blob = bytes.sublist(_headerStart(h.length));
    final String actual = sha256.convert(blob).toString();
    if (actual != h.checksum) {
      throw const AppException(
        'ملف النسخة الاحتياطية تالف أو ناقص (تعذّر التحقق من البصمة).',
      );
    }
    if (blob.length <= _macLength) {
      throw const AppException('ملف النسخة الاحتياطية فارغ أو مبتور.');
    }

    // 2) فك التشفير.
    final SecretKey key = await _deriveKey(
      password,
      base64Decode(h.salt),
      iterations: h.iterations,
    );
    final Uint8List mac = Uint8List.fromList(
      blob.sublist(blob.length - _macLength),
    );
    final SecretBox box = SecretBox(
      Uint8List.fromList(blob.sublist(0, blob.length - _macLength)),
      nonce: base64Decode(h.nonce),
      mac: Mac(mac),
    );

    final List<int> clearText;
    try {
      clearText = await AesGcm.with256bits().decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const AppException(
        'كلمة مرور النسخة الاحتياطية غير صحيحة، أو الملف عُوّج.',
      );
    }

    // 3) المحتوى ومطابقة المخطط.
    final _Payload payload = _parsePayload(clearText);
    await _validateAgainstSchema(payload);

    // 4) التطبيق ذرياً — أي فشل داخل المعاملة = تراجع كامل.
    try {
      await _database.transaction((Transaction txn) async {
        for (final String t in tables.reversed) {
          await txn.delete(t);
        }
        await txn.delete(
          Db.settings,
          where:
              '${Db.cKey} IN (${_placeholders(restorableSettingsKeys.length)})',
          whereArgs: restorableSettingsKeys,
        );

        for (final String t in tables) {
          final List<Map<String, Object?>> rows =
              payload.tables[t] ?? const <Map<String, Object?>>[];
          final Batch b = txn.batch();
          for (final Map<String, Object?> row in rows) {
            b.insert(t, row);
          }
          await b.commit(noResult: true);
        }

        if (payload.settings.isNotEmpty) {
          final Batch b = txn.batch();
          for (final Map<String, Object?> row in payload.settings) {
            b.insert(
              Db.settings,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await b.commit(noResult: true);
        }

        await _audit.logRestore(
          'استعادة نسخة احتياطية (${payload.createdAt}) — '
          '${payload.rowCount} صفّ',
          txn: txn,
        );
      });
    } on DatabaseException catch (e) {
      throw AppException.wrap(
        e,
        fallbackMessage:
            'تعذّرت الاستعادة — تراجعت كل التغييرات ولم يتغيّر شيء.',
      );
    }

    return RestoreReport(
      createdAt: payload.createdAt,
      schemaVersion: payload.schemaVersion,
      rowCounts: payload.rowCounts,
      restoredSettingsKeys: <String>[
        for (final Map<String, Object?> r in payload.settings)
          if (r[Db.cKey] is String) r[Db.cKey] as String,
      ],
    );
  }

  // ── القراءة والتحقق ────────────────────────────────────────

  Future<Uint8List> _readBytes(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      throw AppException('ملف النسخة الاحتياطية غير موجود: ${_baseName(path)}');
    }
    try {
      return Uint8List.fromList(await file.readAsBytes());
    } on FileSystemException catch (e) {
      throw AppException.wrap(
        e,
        fallbackMessage: 'تعذّرت قراءة ملف النسخة الاحتياطية.',
      );
    }
  }

  /// "ASBK" + إصدار + طول الترويسة + الترويسة JSON.
  static _Header _parseHeader(Uint8List bytes) {
    final int min = _magic.length + 1 + _headerLengthSize;
    if (bytes.length < min) {
      throw const AppException('الملف أقصر من أن يكون نسخة احتياطية.');
    }
    for (int i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) {
        throw const AppException(
          'هذا ليس ملف نسخة احتياطية لهذا النظام.',
        );
      }
    }
    if (bytes[_magic.length] != _formatVersion) {
      throw AppException(
        'صيغة النسخة الاحتياطية غير مدعومة '
        '(الإصدار ${bytes[_magic.length]} والإصدار $_formatVersion).',
      );
    }

    final int headerLength = _readUint32(bytes, _magic.length + 1);
    final int start = _headerStart(headerLength);
    if (headerLength <= 0 || start > bytes.length) {
      throw const AppException('ملف النسخة الاحتياطية مبتور أو تالف.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes.sublist(_magic.length + 1 + _headerLengthSize, start)));
    } on FormatException {
      throw const AppException('ترويسة ملف النسخة الاحتياطية غير صالحة.');
    }
    if (decoded is! Map) {
      throw const AppException('ترويسة ملف النسخة الاحتياطية ليست كائناً.');
    }

    final Map<String, Object?> j = Map<String, Object?>.from(decoded);
    if (j['format'] != 'admin_staff_backup') {
      throw const AppException('ملف بصيغة غير معروفة.');
    }

    final Object? salt = j['salt'];
    final Object? nonce = j['nonce'];
    final Object? checksum = j['checksum'];
    if (salt is! String || nonce is! String || checksum is! String) {
      throw const AppException('ترويسة ملف النسخة الاحتياطية ناقصة.');
    }

    final int iterations = (j['iterations'] is num)
        ? (j['iterations'] as num).toInt()
        : kdfIterations;
    if (iterations < _minIterations || iterations > _maxIterations) {
      throw const AppException('معاملات تشفير الملف غير معقولة.');
    }

    return _Header(
      createdAt: (j['created_at'] is String) ? j['created_at'] as String : '',
      schemaVersion: (j['schema_version'] is num)
          ? (j['schema_version'] as num).toInt()
          : -1,
      iterations: iterations,
      salt: salt,
      nonce: nonce,
      checksum: checksum,
      counts: _countsOfJson(j['counts']),
      length: headerLength,
    );
  }

  _Payload _parsePayload(List<int> clearText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(clearText));
    } on FormatException {
      throw const AppException('محتوى النسخة الاحتياطية غير صالح.');
    }
    if (decoded is! Map) {
      throw const AppException('محتوى النسخة الاحتياطية ليس كائناً.');
    }
    final Map<String, Object?> j = Map<String, Object?>.from(decoded);

    if (j['format'] != 'admin_staff_backup') {
      throw const AppException('محتوى الملف بصيغة غير معروفة.');
    }

    final int version = (j['schema_version'] is num)
        ? (j['schema_version'] as num).toInt()
        : -1;
    if (version > Db.schemaVersion) {
      throw AppException(
        'الملف من إصدار أحدث ($version) وهو إصدار التطبيق '
        '${Db.schemaVersion} — حدّث التطبيق أولاً.',
      );
    }
    if (version != Db.schemaVersion) {
      throw AppException(
        'الملف بإصدار مخطط $version والمطلوب ${Db.schemaVersion} — '
        'لا توجد هجرة مطابقة لهذا الإصدار.',
      );
    }

    final Object? rawTables = j['tables'];
    if (rawTables is! Map) {
      throw const AppException('الملف بلا جداول بيانات.');
    }

    final Map<String, List<Map<String, Object?>>> out =
        <String, List<Map<String, Object?>>>{};
    for (final MapEntry<Object?, Object?> e in rawTables.entries) {
      final String table = '${e.key}';
      if (!tables.contains(table)) {
        throw AppException('جدول غير معروف في الملف: $table');
      }
      if (e.value is! List) {
        throw AppException('محتوى الجدول $table ليس قائمة صفوف.');
      }
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
      for (final Object? r in e.value as List) {
        if (r is! Map) {
          throw AppException('صفّ غير صالح في الجدول $table.');
        }
        rows.add(Map<String, Object?>.from(r));
      }
      out[table] = rows;
    }

    final List<Map<String, Object?>> settings = <Map<String, Object?>>[];
    final Object? rawSettings = j['settings'];
    if (rawSettings is List) {
      for (final Object? r in rawSettings) {
        if (r is! Map) continue;
        final Map<String, Object?> row = Map<String, Object?>.from(r);
        final Object? key = row[Db.cKey];
        if (key is! String || !restorableSettingsKeys.contains(key)) {
          continue; // مفتاح جهازي/أمني لا يدخل أبداً.
        }
        settings.add(row);
      }
    }

    return _Payload(
      schemaVersion: version,
      createdAt: (j['created_at'] is String) ? j['created_at'] as String : '',
      tables: out,
      settings: settings,
      rowCounts: _countsOf(<String, Object?>{'tables': out, 'settings': settings}),
    );
  }

  /// مطابقة كل عمود في الملف مع المخطط الفعلي **قبل** اللمس.
  Future<void> _validateAgainstSchema(_Payload payload) async {
    final Map<String, Set<String>> columns = <String, Set<String>>{};
    for (final String t in tables) {
      final List<Map<String, Object?>> info =
          await _db.rawQuery('PRAGMA table_info($t)');
      columns[t] = <String>{
        for (final Map<String, Object?> r in info) '${r['name']}',
      };
    }

    for (final MapEntry<String, List<Map<String, Object?>>> e
        in payload.tables.entries) {
      final Set<String>? known = columns[e.key];
      if (known == null) continue;
      for (final Map<String, Object?> row in e.value) {
        for (final String col in row.keys) {
          if (!known.contains(col)) {
            throw AppException(
              'الملف يحوي عموداً غير موجود في المخطط: '
              '${e.key}.$col',
            );
          }
        }
      }
    }
  }

  // ── أدوات ──────────────────────────────────────────────────

  static void _checkPassword(String password) {
    if (password.trim().length < 4) {
      throw const AppException(
        'كلمة مرور النسخة الاحتياطية قصيرة جداً — 4 خانات على الأقل.',
      );
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt, {
    int iterations = kdfIterations,
  }) =>
      Pbkdf2.hmacSha256(iterations: iterations, bits: 256)
          .deriveKeyFromPassword(password: password, nonce: salt);

  /// لقطة كل الجداول + مفاتيح settings المسموح تصديرها.
  Future<Map<String, Object?>> _snapshot() async {
    final Map<String, Object?> out = <String, Object?>{
      'format': 'admin_staff_backup',
      'schema_version': Db.schemaVersion,
      'created_at': DateTime.now().toIso8601String(),
      'tables': <String, Object?>{},
      'settings': <Map<String, Object?>>[],
    };

    final Map<String, Object?> tablesJson =
        out['tables']! as Map<String, Object?>;
    for (final String t in tables) {
      tablesJson[t] = await _db.query(t, orderBy: '${Db.cId} ASC');
    }

    out['settings'] = await _db.query(
      Db.settings,
      columns: <String>[Db.cKey, Db.cValue, Db.cUpdatedAt],
      where: '${Db.cKey} IN (${_placeholders(restorableSettingsKeys.length)})',
      whereArgs: restorableSettingsKeys,
    );
    return out;
  }

  static Map<String, int> _countsOf(Map<String, Object?> payload) {
    final Map<String, int> out = <String, int>{};
    final Object? t = payload['tables'];
    if (t is Map) {
      for (final MapEntry<Object?, Object?> e in t.entries) {
        out['${e.key}'] = (e.value is List) ? (e.value as List).length : 0;
      }
    }
    final Object? s = payload['settings'];
    if (s is List) out[Db.settings] = s.length;
    return out;
  }

  static Map<String, int> _countsOfJson(Object? raw) {
    if (raw is! Map) return <String, int>{};
    return <String, int>{
      for (final MapEntry<Object?, Object?> e in raw.entries)
        if (e.value is num) '${e.key}': (e.value as num).toInt(),
    };
  }

  static Uint8List _randomBytes(int n, Random rnd) =>
      Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));

  static void _addUint32(BytesBuilder out, int v) => out.add(<int>[
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
        v & 0xFF,
      ]);

  static int _readUint32(Uint8List b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  static int _headerStart(int headerLength) =>
      _magic.length + 1 + _headerLengthSize + headerLength;

  static String _placeholders(int n) => List<String>.filled(n, '?').join(', ');

  static String _baseName(String path) =>
      path.replaceAll(r'\', '/').split('/').last;
}

/// ترويسة الملف — تُقرأ بلا كلمة مرور.
class _Header {
  const _Header({
    required this.createdAt,
    required this.schemaVersion,
    required this.iterations,
    required this.salt,
    required this.nonce,
    required this.checksum,
    required this.counts,
    required this.length,
  });

  final String createdAt;
  final int schemaVersion;
  final int iterations;
  final String salt;
  final String nonce;
  final String checksum;
  final Map<String, int> counts;
  final int length;
}

/// محتوى الملف بعد فك التشفير والتحقق من المخطط.
class _Payload {
  const _Payload({
    required this.schemaVersion,
    required this.createdAt,
    required this.tables,
    required this.settings,
    required this.rowCounts,
  });

  final int schemaVersion;
  final String createdAt;
  final Map<String, List<Map<String, Object?>>> tables;
  final List<Map<String, Object?>> settings;
  final Map<String, int> rowCounts;

  int get rowCount => rowCounts.values.fold<int>(0, (int a, int b) => a + b);
}

/// معلومات ملف نسخة احتياطية (لشاشة العرض قبل إدخال كلمة المرور).
class BackupInfo {
  const BackupInfo({
    required this.createdAt,
    required this.schemaVersion,
    required this.rowCounts,
    required this.fileBytes,
    required this.checksum,
  });

  final String createdAt;
  final int schemaVersion;
  final Map<String, int> rowCounts;
  final int fileBytes;
  final String checksum;

  int get totalRows =>
      rowCounts.values.fold<int>(0, (int a, int b) => a + b);

  int get employeeCount => rowCounts[Db.employees] ?? 0;
}

/// نتيجة الاستعادة.
class RestoreReport {
  const RestoreReport({
    required this.createdAt,
    required this.schemaVersion,
    required this.rowCounts,
    required this.restoredSettingsKeys,
  });

  final String createdAt;
  final int schemaVersion;
  final Map<String, int> rowCounts;
  final List<String> restoredSettingsKeys;

  int get totalRows =>
      rowCounts.values.fold<int>(0, (int a, int b) => a + b);

  int get employeeCount => rowCounts[Db.employees] ?? 0;
}
