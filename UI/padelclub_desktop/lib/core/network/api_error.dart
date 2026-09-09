import 'dart:convert';

/// Extracts readable validation messages without exposing JSON or stack traces.
String apiErrorMessage(
  String body, {
  String fallback = 'Could not save changes. Please try again.',
}) {
  final text = body.trim();
  if (text.isEmpty) return fallback;
  try {
    final decoded = jsonDecode(text);
    if (decoded is String) return decoded;
    if (decoded is Map) {
      final errors = decoded['errors'];
      if (errors is Map) {
        final messages = errors.values
            .expand((value) => value is List ? value : [value])
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .toSet();
        if (messages.isNotEmpty) return messages.join('\n');
      }
      for (final key in ['message', 'detail', 'title']) {
        final message = decoded[key];
        if (message is String && message.trim().isNotEmpty) return message;
      }
      return fallback;
    }
    return fallback;
  } on FormatException {
    return text.startsWith('<') ||
            text.contains('StackTrace') ||
            text.length > 1000
        ? fallback
        : text;
  }
}
