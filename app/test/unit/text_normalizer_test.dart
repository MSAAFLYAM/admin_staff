import 'package:admin_staff/core/utils/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات قاعدة 25 — تطبيع البحث عربي/فرنسي.
///
/// كل تطبيع هنا يعمل على **طرفين** المطابقة: النص المخزَّن في
/// `search_text` عند الكتابة، واستعلام المستخدم عند البحث.
/// إن اختلف الطرفان انهار البحث صامتاً، لذا نثبتهما معاً.
void main() {
  group('الهمزات والتشكيل', () {
    test('أ إ آ ٱ تؤول إلى ا', () {
      const String expected = 'اااا';
      expect(TextNormalizer.normalize('أ'), 'ا');
      expect(TextNormalizer.normalize('إ'), 'ا');
      expect(TextNormalizer.normalize('آ'), 'ا');
      expect(TextNormalizer.normalize('ٱ'), 'ا');
      expect(TextNormalizer.normalize('أإآٱ'), expected);
    });

    test('البحث بلا همزة يجد صاحب الهمزة (في الاتجاهين)', () {
      expect(TextNormalizer.normalize('أحمد'), TextNormalizer.normalize('احمد'));
      expect(TextNormalizer.normalize('إسلام'), TextNormalizer.normalize('اسلام'));
    });

    test('ة → ه و ى → ي', () {
      expect(TextNormalizer.normalize('المالية'), 'الماليه');
      expect(TextNormalizer.normalize('موسى'), 'موسي');
      expect(
        TextNormalizer.normalize('مصطفى'),
        TextNormalizer.normalize('مصطفي'),
      );
    });

    test('ؤ → و و ئ → ي', () {
      expect(TextNormalizer.normalize('مسؤول'), 'مسوول');
      expect(TextNormalizer.normalize('شئ'), 'شي');
      expect(TextNormalizer.normalize('مئونه'), 'ميونه');
    });

    test('التشكيل وعلامات المد تُحذف', () {
      expect(
        TextNormalizer.normalize('مُحَمَّد'),
        TextNormalizer.normalize('محمد'),
      );
      expect(TextNormalizer.normalize('ٱلْعَرَبِيَّة'), 'العربيه');
      // التاء المربوطة أحياناً مُشكَّلة: "رُخَّصَة".
      expect(
        TextNormalizer.normalize('رخصه'),
        TextNormalizer.normalize('رُخَّصَة'),
      );
    });

    test('التطبيع انعكاسي: نص بلا تشكيل = نص به', () {
      expect(
        TextNormalizer.normalize('قسم الموارد البشرية'),
        TextNormalizer.normalize('قِسْمُ الْمَوارِدِ الْبَشَريَّة'),
      );
    });
  });

  group('اللاتينية', () {
    test('غير حساس لحالة الأحرف', () {
      expect(TextNormalizer.normalize('Ahmed'), 'ahmed');
      expect(TextNormalizer.normalize('AHMED'), 'ahmed');
      expect(TextNormalizer.normalize('AhMeD'), 'ahmed');
    });

    test('طيّ الحروف المُشكَّلة (générale = generale)', () {
      expect(TextNormalizer.normalize('Direction générale'), 'direction generale');
      expect(TextNormalizer.normalize('GÉNÉRALE'), 'generale');
      expect(TextNormalizer.normalize('établissements'), 'etablissements');
      expect(TextNormalizer.normalize('François'), 'francois');
      expect(TextNormalizer.normalize('århus'), 'arhus');
      expect(TextNormalizer.normalize('straße'), 'strasse');
      expect(TextNormalizer.normalize('Ærø'), 'aero');
      expect(TextNormalizer.normalize('œuvre'), 'oeuvre');
    });

    test('التطبيع انعكاسي للفرنسي أيضاً', () {
      expect(
        TextNormalizer.normalize('Établissement Public'),
        TextNormalizer.normalize('Etablissement public'),
      );
    });
  });

  group('المسافات والترقيم', () {
    test('المسافات الزائدة تُضغط', () {
      expect(TextNormalizer.normalize('  a   b  '), 'a b');
      expect(TextNormalizer.normalize('\ta\nb'), 'a b');
    });

    test('الترقيم يصبح مسافة لا يلتصق بالكلمات', () {
      expect(TextNormalizer.normalize('ben-amar'), 'ben amar');
      expect(TextNormalizer.normalize('ben_amar'), 'ben amar');
      expect(TextNormalizer.normalize("ben's"), 'ben s');
    });

    test('النقطة المئوية % لا تُمحى (تُهرب لاحقاً)', () {
      expect(TextNormalizer.normalize('100%'), '100%');
    });

    test('النص الفارغ والملآن بالمسافات', () {
      expect(TextNormalizer.normalize(null), '');
      expect(TextNormalizer.normalize(''), '');
      expect(TextNormalizer.normalize('   '), '');
    });
  });

  group('searchText — عمود البحث المخزَّن', () {
    test('يجمع الأجزاء غير الفارغة بمسافة واحدة', () {
      expect(
        TextNormalizer.searchText(<String?>['1001', null, '', 'أحمد', 'Ahmed']),
        '1001 احمد ahmed',
      );
    });

    test('كل الأجزاء فارغة → سلسلة فارغة (لا مسافات متبقية)', () {
      expect(TextNormalizer.searchText(<String?>[null, '', '   ']), '');
    });

    test('مطابقة البحث بالسؤال بـ searchText متطابقة', () {
      final String stored =
          TextNormalizer.searchText(<String?>['بن عيسى', 'Direction générale']);
      expect(stored, 'بن عيسي direction generale',
          reason: 'searchText تُطبّع كل جزء — ى→ي من بينها');

      // كل مصطلح من الاستعلام يجب أن يظهر في النص المخزَّن.
      for (final String q
          in <String>['عيسى', 'بن عيسى', 'generale', 'générale', 'Direction']) {
        expect(
          TextNormalizer.tokens(q)
              .every((String t) => stored.contains(t)),
          isTrue,
          reason: 'المصطلحات $q غير موجودة في "$stored"',
        );
      }
    });
  });

  group('tokens / contains / likePattern', () {
    test('tokens تفصل على المسافات وتهمل الفراغات', () {
      expect(TextNormalizer.tokens('  احمد   محمد '), <String>['احمد', 'محمد']);
      expect(TextNormalizer.tokens(''), isEmpty);
      expect(TextNormalizer.tokens(null), isEmpty);
    });

    test('contains تطبّع الطرفين', () {
      expect(TextNormalizer.contains('أحمد بن عيسى', 'احمد'), isTrue);
      expect(TextNormalizer.contains('أحمد بن عيسى', 'École'), isFalse);
      expect(TextNormalizer.contains('x', ''), isTrue, reason: 'بحث فارغ');
    });

    test('likePattern يهرب % (و_وشَطوباً تُمحى أصلاً في التطبيع)', () {
      expect(TextNormalizer.likePattern('100%'), r'%100\%%');
      // `_` و `\` من علامات الترقيم فتُستبدل بمسافة قبل الهروب —
      // فلا تصلان إلى SQL أبداً كأحرف جامدة.
      expect(TextNormalizer.likePattern('a_b'), '%a b%');
      expect(TextNormalizer.likePattern(r'a\b'), '%a b%');
      expect(TextNormalizer.likePattern('أحمد'), '%احمد%');
    });
  });

  group('tidy — للعرض فقط لا للبحث', () {
    test('يزيل المسافات لكنه لا يُطبّع', () {
      expect(TextNormalizer.tidy('  أ  ح  مَد '), 'أ ح مَد');
      expect(TextNormalizer.tidy(null), '');
    });
  });
}
