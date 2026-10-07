import 'package:flutter/foundation.dart';

/// خطأ قابل للعرض للمستخدم (قاعدة 49).
///
/// - [userMessage]: ما يراه المستخدم — بلغة واضحة وعربية/فرنسية.
/// - [techDetail]: ما يُسجَّل في Debug Logs فقط.
///
/// المستخدم **لا يرى أبداً** `SQLiteException` أو `Null Pointer`.
class AppException implements Exception {
  const AppException(this.userMessage, {this.techDetail, this.cause});

  /// الرسالة المعروضة في الواجهة.
  final String userMessage;

  /// التفاصيل التقنية — تُطبع في الـ debug log فقط.
  final String? techDetail;

  /// الاستثناء الأصلي إن وجد.
  final Object? cause;

  /// يلفّ أي استثناء غير متوقع برسالة مفهومة.
  static AppException wrap(Object error, {String? fallbackMessage}) {
    if (error is AppException) return error;
    return AppException(
      fallbackMessage ?? 'حدث خطأ غير متوقع. راجع السجل التقني للتفاصيل.',
      techDetail: error.toString(),
      cause: error,
    );
  }

  /// يسجَّل التفاصيل التقنية فقط في وضع التطوير.
  void log() {
    if (kDebugMode) {
      debugPrint('[ERROR] $userMessage | detail=$techDetail');
      if (cause != null) debugPrint('  cause: $cause');
    }
  }

  @override
  String toString() => 'AppException: $userMessage'
      '${techDetail == null ? '' : ' ($techDetail)'}';
}

/// نتيجة فشل/نجاح موحّدة للخدمات.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(:final T value) => value,
        Failure<T>() => null,
      };

  AppException? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final AppException error) => error,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(AppException error) failure,
  }) =>
      switch (this) {
        Success<T>(:final T value) => success(value),
        Failure<T>(:final AppException error) => failure(error),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppException error;
}
