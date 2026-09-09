import 'package:flutter_test/flutter_test.dart';

import 'package:padelclub_desktop/features/notification_settings/domain/entities/notification_preferences.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/repositories/notification_settings_repository.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/usecases/get_notification_preferences.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/usecases/save_notification_preferences.dart';
import 'package:padelclub_desktop/features/notification_settings/presentation/providers/notification_settings_provider.dart';

void main() {
  test('loads, edits, and persists player notification preferences', () async {
    final repository = _NotificationSettingsRepositoryFake(
      current: const NotificationPreferences(
        inAppEnabled: true,
        emailEnabled: true,
        pushEnabled: false,
      ),
    );
    final provider = NotificationSettingsProvider(
      GetNotificationPreferences(repository),
      SaveNotificationPreferences(repository),
    );

    await provider.load();

    expect(provider.preferences.pushEnabled, isFalse);
    expect(provider.hasChanges, isFalse);

    provider.updateDraft(emailEnabled: false, pushEnabled: true);

    expect(provider.preferences.emailEnabled, isFalse);
    expect(provider.preferences.pushEnabled, isTrue);
    expect(provider.hasChanges, isTrue);

    expect(await provider.save(), isTrue);
    expect(repository.saved?.inAppEnabled, isTrue);
    expect(repository.saved?.emailEnabled, isFalse);
    expect(repository.saved?.pushEnabled, isTrue);
    expect(provider.hasChanges, isFalse);
  });
}

class _NotificationSettingsRepositoryFake
    implements NotificationSettingsRepository {
  _NotificationSettingsRepositoryFake({required this.current});

  NotificationPreferences current;
  NotificationPreferences? saved;

  @override
  Future<NotificationPreferences> getMine() async => current;

  @override
  Future<NotificationPreferences> saveMine(
    NotificationPreferences preferences,
  ) async {
    saved = preferences;
    current = preferences;
    return preferences;
  }
}
