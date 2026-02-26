import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ErrorLogger {
  static const MethodChannel _channel = MethodChannel('error_log');

  static Future<void> append(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final payload = '[$timestamp] $message\n';
    try {
      await _channel.invokeMethod('appendToDownloads', {
        'filename': 'error_log.txt',
        'text': payload,
      });
    } catch (e) {
      debugPrint('ErrorLogger: failed to write log: $e');
    }
  }
}
