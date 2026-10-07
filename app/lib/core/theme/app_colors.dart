import 'package:flutter/material.dart';

/// لوحة ألوان التطبيق: **Dark Administrative UI**.
///
/// القواعد (Rule 5):
///  - الخلفية سوداء / شبه سوداء.
///  - الأخضر المضيء (Neon Green) للأزرار والعناصر النشطة فقط.
///  - الأبيض للنصوص الأساسية، الرمادي للثانوية.
///  - ألوان منفصلة للحالات (نجاح/تحذير/خطأ/معلومات).
///  - لا نصوص خضراء عامة → الحالة تُعرض أيضاً بنص (قاعدة 64).
abstract final class AppColors {
  // ── Backgrounds ─────────────────────────────────────────────
  /// الخلفية الأساسية — شبه سوداء.
  static const Color background = Color(0xFF0A0C0B);

  /// خلفية البطاقات والحاويات.
  static const Color surface = Color(0xFF121614);

  /// خلفية مرتفعة قليلاً (inputs, sheets).
  static const Color surfaceElevated = Color(0xFF1A201D);

  /// خلفية العناصر المحدّدة / المميزة.
  static const Color surfaceSelected = Color(0xFF10201A);

  /// خط فاصل.
  static const Color border = Color(0xFF242B27);
  static const Color borderStrong = Color(0xFF333C37);

  // ── Neon Green (accent) ─────────────────────────────────────
  /// اللون المميز — يُستخدم للأزرار والعناصر النشطة فقط.
  static const Color neon = Color(0xFF39FF6A);

  /// نيون أخف للخلفيات الملوّنة.
  static const Color neonDim = Color(0xFF1FD155);

  /// خلفية شفافة للعناصر النشطة.
  static const Color neonSurface = Color(0x1A39FF6A);

  /// نيون محجوب — للاستخدام فوق خلفيات فاتحة نظرياً.
  static const Color onNeon = Color(0xFF03150A);

  // ── Text ────────────────────────────────────────────────────
  /// النص الأساسي — أبيض.
  static const Color textPrimary = Color(0xFFF4F7F5);

  /// النص الثانوي — رمادي.
  static const Color textSecondary = Color(0xFF9AA39E);

  /// النص الثالثي / المتعطّل.
  static const Color textTertiary = Color(0xFF666E6A);
  static const Color textDisabled = Color(0xFF4A514D);

  // ── Status / semantic (مفصولة عن النيون) ───────────────────
  /// في الخدمة — أخضر هادئ (مختلف عن النيون).
  static const Color success = Color(0xFF4ADE80);
  static const Color successSurface = Color(0x1A4ADE80);

  /// تحذير / عطلة — برتقالي.
  static const Color warning = Color(0xFFFBBF24);
  static const Color warningSurface = Color(0x1AFBBF24);

  /// خطأ / إلغاء / موقوف — أحمر.
  static const Color danger = Color(0xFFF87171);
  static const Color dangerSurface = Color(0x1AF87171);

  /// معلومات / رخصة استثنائية — أزرق.
  static const Color info = Color(0xFF60A5FA);
  static const Color infoSurface = Color(0x1A60A5FA);

  /// محايد / مؤرشف — رمادي.
  static const Color neutral = Color(0xFF9AA39E);
  static const Color neutralSurface = Color(0x149AA39E);

  /// بنفسجي — رخصة مرضية.
  static const Color purple = Color(0xFFC084FC);
  static const Color purpleSurface = Color(0x1AC084FC);

  // ── Overlay / misc ──────────────────────────────────────────
  static const Color scrim = Color(0xB3000000);
  static const Color focusRing = Color(0x6639FF6A);

  // ── Charts (dashboard) ──────────────────────────────────────
  static const List<Color> chartPalette = [
    Color(0xFF39FF6A),
    Color(0xFF60A5FA),
    Color(0xFFFBBF24),
    Color(0xFFF87171),
    Color(0xFFC084FC),
    Color(0xFF4ADE80),
    Color(0xFF2DD4BF),
    Color(0xFFF472B6),
  ];

  /// يُرجع لوناً ثابتاً من لوحة الرسوم حسب الفهرس.
  static Color chart(int index) =>
      chartPalette[index % chartPalette.length];
}
