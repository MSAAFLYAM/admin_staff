import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// نقطة دخول التطبيق — **لا منطق أعمال هنا**.
///
/// كل التهيئة تتم عبر المزوّدات داخل [AdminStaffApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: AdminStaffApp(),
    ),
  );
}
