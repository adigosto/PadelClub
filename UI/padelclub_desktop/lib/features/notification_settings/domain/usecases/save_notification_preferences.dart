import 'package:padelclub_desktop/features/notification_settings/domain/entities/notification_preferences.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/repositories/notification_settings_repository.dart';

class SaveNotificationPreferences {
  const SaveNotificationPreferences(this._repository);

  final NotificationSettingsRepository _repository;

  Future<NotificationPreferences> call(NotificationPreferences preferences) {
    return _repository.saveMine(preferences);
  }
}
