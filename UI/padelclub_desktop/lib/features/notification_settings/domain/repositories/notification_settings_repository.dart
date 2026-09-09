import 'package:padelclub_desktop/features/notification_settings/domain/entities/notification_preferences.dart';

abstract interface class NotificationSettingsRepository {
  Future<NotificationPreferences> getMine();

  Future<NotificationPreferences> saveMine(NotificationPreferences preferences);
}
