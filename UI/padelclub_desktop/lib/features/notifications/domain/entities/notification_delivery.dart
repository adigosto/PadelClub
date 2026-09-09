/// A read-only notification delivery-attempt record returned to an
/// administrator by `GET /NotificationSettings/deliveries`.
class NotificationDelivery {
  const NotificationDelivery({
    required this.id,
    required this.notificationId,
    required this.userId,
    required this.channel,
    required this.status,
    required this.attemptCount,
    required this.nextAttemptAt,
    required this.sentAt,
    required this.lastError,
  });

  final int id;
  final int notificationId;
  final int userId;
  final String channel;
  final String status;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final DateTime? sentAt;
  final String? lastError;

  factory NotificationDelivery.fromJson(Map<String, dynamic> json) {
    int requiredInteger(String key) {
      final value = json[key];
      if (value is num) return value.toInt();
      throw FormatException('Delivery record contains an invalid $key.');
    }

    String requiredText(String key) {
      final value = json[key];
      if (value is String) return value;
      throw FormatException('Delivery record contains an invalid $key.');
    }

    DateTime requiredDate(String key) {
      final value = requiredText(key);
      return DateTime.tryParse(value) ??
          (throw FormatException('Delivery record contains an invalid $key.'));
    }

    DateTime? optionalDate(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) {
        throw FormatException('Delivery record contains an invalid $key.');
      }
      return DateTime.tryParse(value) ??
          (throw FormatException('Delivery record contains an invalid $key.'));
    }

    String? optionalText(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is String) return value;
      throw FormatException('Delivery record contains an invalid $key.');
    }

    return NotificationDelivery(
      id: requiredInteger('id'),
      notificationId: requiredInteger('notificationId'),
      userId: requiredInteger('userId'),
      channel: requiredText('channel'),
      status: requiredText('status'),
      attemptCount: requiredInteger('attemptCount'),
      nextAttemptAt: requiredDate('nextAttemptAt'),
      sentAt: optionalDate('sentAt'),
      lastError: optionalText('lastError'),
    );
  }
}
