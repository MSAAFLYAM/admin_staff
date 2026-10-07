import 'package:flutter/material.dart';

/// المسافات والزوايا الموحّدة — Mobile First، سهلة بيد واحدة.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const EdgeInsets page = EdgeInsets.fromLTRB(lg, lg, lg, xl);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets tight = EdgeInsets.all(sm);

  /// أصغر لمسة مريحة للأزرار (Accessibility 64).
  static const double touchTarget = 48;
  static const double minTouchTarget = 44;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;
}
