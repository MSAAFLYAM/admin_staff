import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:admin_staff/app.dart';
import 'package:admin_staff/core/database/app_database.dart';
import 'package:admin_staff/core/providers/app_providers.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets(
    'App builds and shows bottom navigation',
    (WidgetTester tester) async {
      // كل العمل غير المتزامن (SQLite FFI) يجب أن يجري داخل runAsync،
      // مع مَضَبّطات (pump) بين الدورات — وإلا لا تكتمل بوابة القفل أبداً
      // داخل منطقة الزمن الوهمي لـ testWidgets.
      await tester.runAsync(() async {
        final Database db =
            await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        addTearDown(db.close);
        await AppDatabase.createSchema(db);
        await AppDatabase.seed(db);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider
                  .overrideWith((_) async => AppDatabase.fromDatabase(db)),
            ],
            child: const AdminStaffApp(),
          ),
        );

        // دورة: انتظر الحقيقية ← ارسم ← كرّر (فتح القاعدة → بوابة القفل → اللوحة).
        for (int i = 0; i < 6; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
        }
      });

      // يجب أن يكون التنقل السفلي ظاهراً بخمس وجهات.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    },
  );
}
