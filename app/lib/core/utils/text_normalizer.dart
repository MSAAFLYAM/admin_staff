/// تطبيع النصوص للبحث العربي/الفرنسي (قاعدة 25).
///
/// الأهداف:
///  - غير حساس لحالة الأحرف (Ahmed = ahmed = AHMED)
///  - متسامح مع المسافات الزائدة
///  - توحيد التشكيل والنقط (مقبوض/مفتوح) للعربية
///  - تطبيع الألف/الهمزة والتاء المربوطة
///  - طيّ الحروف اللاتينية المُشكَّلة (générale = generale)
abstract final class TextNormalizer {
  /// يطبّع نصاً للبحث: يحذف التشكيل، يوحّد الهمزات،
  /// يحوّل للحروف الصغيرة، ويضغط المسافات.
  static String normalize(String? input) {
    if (input == null || input.isEmpty) return '';

    String s = input;

    // 1) أشكال "أ/إ/آ/ٱ" → "ا"
    s = s.replaceAll(RegExp(r'[آأإٱ]'), 'ا');

    // 2) "ة" → "ه" ، "ى" → "ي"
    s = s.replaceAll('ة', 'ه');
    s = s.replaceAll('ى', 'ي');

    // 3) إزالة التشكيل (harakat) وعلامات المد.
    s = s.replaceAll(
      RegExp(
        r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8'
        r'\u06EA-\u06ED\u0640]',
      ),
      '',
    );

    // 4) الألف مقصورة/معقوبة … توحيد بسيط.
    s = s.replaceAll('ؤ', 'و');
    s = s.replaceAll('ئ', 'ي');

    // 5) تحويل للحروف الصغيرة (يدعم اللاتينية والعربي في Dart).
    s = s.toLowerCase();

    // 5ب) طيّ الحروف المُشكَّلة اللاتينية: "générale" = "generale".
    // التطبيق على **طرفين** البحث (الكتابة والسؤال) فيتناظران.
    s = _foldLatin(s);

    // 6) إزالة علامات الترقيم اللاتينية الشائعة.
    s = s.replaceAll(
      RegExp(r'''[.,;:!'()[\]{}\-_/\\|+*=&#@?<>~^$]'''),
      ' ',
    );

    // 7) ضغط المسافات (بما فيها المكررة والمنقوطة).
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    return s.trim();
  }

  /// طيّ الحروف اللاتينية المُشكَّلة إلى أساسها (`é→e`, `ç→c`).
  ///
  /// لا توجد تطبيع Unicode في Dart، وقائمة `latin` تكفي أسماء
  /// الإدارات والوظائف والمدن. تُستدعى **بعد** `toLowerCase()`
  /// لذا تكفي المفاتيح الصغيرة.
  static const Map<String, String> _latin = <String, String>{
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ě': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ų': 'u',
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    'č': 'c', 'ć': 'c', 'ç': 'c', 'ĉ': 'c', 'ċ': 'c',
    'š': 's', 'ś': 's', 'ş': 's', 'ß': 'ss',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
    'ñ': 'n', 'ń': 'n', 'ņ': 'n',
    'đ': 'd', 'ð': 'd',
    'þ': 'th',
    'æ': 'ae', 'œ': 'oe', 'ﬁ': 'fi', 'ﬂ': 'fl',
  };

  static String _foldLatin(String s) {
    if (s.isEmpty) return s;
    final StringBuffer out = StringBuffer();
    for (final int rune in s.runes) {
      final String ch = String.fromCharCode(rune);
      out.write(_latin[ch] ?? ch);
    }
    return out.toString();
  }

  /// نص للعرض في القوائم المنسدلة — يزيل المسافات الزائدة فقط.
  static String tidy(String? input) =>
      (input ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// هل [query] موجودة في [text] بعد التطبيع؟
  static bool contains(String? text, String? query) {
    final String q = normalize(query);
    if (q.isEmpty) return true;
    return normalize(text).contains(q);
  }

  /// يبني نمط `LIKE` آمناً للبحث الجزئي.
  ///
  /// يُهرّب `%` و`_` و`\` لمنع سلوك غير متوقع.
  static String likePattern(String query) {
    final String escaped = normalize(query)
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  /// يحوّل كلمة البحث إلى مصطلحات منفصلة (للبحث بكل الكلمات).
  static List<String> tokens(String? query) => normalize(query)
      .split(' ')
      .where((String t) => t.isNotEmpty)
      .toList();

  /// ★ يبني عمود البحث `search_text` المطبَّع لجلب بياناتك.
  ///
  /// **لماذا نخزّن نصاً مطبَّعاً؟** لأن SQL لا يستطيع تطبيع الحروف
  /// العربية (`أ/إ/آ → ا`، `ة → ه`، إزالة التشكيل) — SQLite تدعم
  /// `LOWER()` للاتينية فقط. لو بحثنا عن `أحمد` وفهرسنا `أحمد`
  /// فإن `LIKE '%احمد%'` **لا يطابق شيئاً**.
  ///
  /// الحل: نطبّع مرة واحدة عند الكتابة، ويصبح البحث مطابقة مباشرة
  /// بين نصّين متطابقين التطبيع — أسرع أيضاً (عمود واحد بدل 11).
  ///
  /// الأجزاء الفارغة تُهمل، والباقي يُفصل بمسافة واحدة.
  static String searchText(Iterable<String?> parts) => parts
      .map(normalize)
      .where((String p) => p.isNotEmpty)
      .join(' ');
}
