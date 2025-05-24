import 'package:logger/logger.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  late final Logger _logger;

  // Private constructor
  LoggerService._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  // Singleton instance
  static LoggerService get instance => _instance;

  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance._logger.d(message);
  }

  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance._logger.i(message);
  }

  static void warning(
    dynamic message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    if (error != null) {
      instance._logger.w(
        '$message\nError: $error${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}',
      );
    } else {
      instance._logger.w(message);
    }
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      instance._logger.e(
        '$message\nError: $error${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}',
      );
    } else {
      instance._logger.e(message);
    }
  }

  static void trace(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    instance._logger.t(message);
  }

  static void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      instance._logger.f(
        '$message\nError: $error${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}',
      );
    } else {
      instance._logger.f(message);
    }
  }
}
