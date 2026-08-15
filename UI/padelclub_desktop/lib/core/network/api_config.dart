import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static String get baseUrl {
    const configured = String.fromEnvironment('baseUrl');
    if (configured.isNotEmpty) return configured.replaceAll(RegExp(r'/$'), '');
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }
}
