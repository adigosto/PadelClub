import 'package:padelclub_desktop/features/notification_settings/domain/entities/notification_preferences.dart';

class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.inAppEnabled,
    required super.emailEnabled,
    required super.pushEnabled,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    bool readBool(String key) {
      final value = json[key];
      if (value is bool) return value;
      throw FormatException('Notification preference "$key" is missing.');
    }

    return NotificationPreferencesModel(
      inAppEnabled: readBool('inAppEnabled'),
      emailEnabled: readBool('emailEnabled'),
      pushEnabled: readBool('pushEnabled'),
    );
  }

  Map<String, dynamic> toJson() => {
    'inAppEnabled': inAppEnabled,
    'emailEnabled': emailEnabled,
    'pushEnabled': pushEnabled,
  };
}
