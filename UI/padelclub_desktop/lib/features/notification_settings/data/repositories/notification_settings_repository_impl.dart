import 'package:padelclub_desktop/features/notification_settings/data/datasources/notification_settings_remote_data_source.dart';
import 'package:padelclub_desktop/features/notification_settings/data/models/notification_preferences_model.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/entities/notification_preferences.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/repositories/notification_settings_repository.dart';

class NotificationSettingsRepositoryImpl
    implements NotificationSettingsRepository {
  const NotificationSettingsRepositoryImpl(this._remoteDataSource);

  final NotificationSettingsRemoteDataSource _remoteDataSource;

  @override
  Future<NotificationPreferences> getMine() => _remoteDataSource.getMine();

  @override
  Future<NotificationPreferences> saveMine(
    NotificationPreferences preferences,
  ) {
    return _remoteDataSource.saveMine(
      NotificationPreferencesModel(
        inAppEnabled: preferences.inAppEnabled,
        emailEnabled: preferences.emailEnabled,
        pushEnabled: preferences.pushEnabled,
      ),
    );
  }
}
