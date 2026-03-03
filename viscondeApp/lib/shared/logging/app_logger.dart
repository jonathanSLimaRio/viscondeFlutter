import 'dart:developer' as developer;

class AppLogger {
  const AppLogger._();

  static const String _rootName = 'visconde_app';

  static void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String scope = 'app',
  }) {
    developer.log(
      message,
      name: '$_rootName.$scope',
      error: error,
      stackTrace: stackTrace,
      level: 900,
    );
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String scope = 'app',
  }) {
    developer.log(
      message,
      name: '$_rootName.$scope',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
