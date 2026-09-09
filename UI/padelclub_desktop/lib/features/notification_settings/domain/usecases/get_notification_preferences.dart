import 'package:padelclub_desktop/features/notification_settings/domain/entities/notification_preferences.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/repositories/notification_settings_repository.dart';

class GetNotificationPreferences {
  const GetNotificationPreferences(this._repository);

  final NotificationSettingsRepository _repository;

  Future<NotificationPreferences> call() => _repository.getMine();
}
