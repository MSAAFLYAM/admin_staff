import 'dart:async';

/// مؤجّل التنفيذ — يُستخدم لتأخير البحث أثناء الكتابة (قاعدة 39).
///
/// ```dart
/// final _debouncer = Debouncer(milliseconds: 300);
/// onChanged: (v) => _debouncer.run(() => search(v));
/// ```
class Debouncer {
  Debouncer({this.milliseconds = 300});

  final int milliseconds;
  Timer? _timer;

  /// يجدّل التنفيذ؛ أي استدعاء سابق فيُلغى.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// يلغي أي تنفيذ مجدول.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isPending => _timer?.isActive ?? false;

  void dispose() => cancel();

  @override
  String toString() => 'Debouncer(${milliseconds}ms)';
}

/// نسخة ثابتة قابلة للاستخدام مع Riverpod.
/// ملاحظة: لا تُنشئ كـ global لأن الحالة قد تتراكم في الاختبارات.
// ignore: avoid_classes_with_only_static_members
final class SearchDebouncer {
  SearchDebouncer._();

  static final Debouncer instance = Debouncer(milliseconds: 300);

  static void debugDispose() => instance.cancel();
}
