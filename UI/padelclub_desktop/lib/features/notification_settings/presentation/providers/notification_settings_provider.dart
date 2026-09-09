import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/notification_settings/domain/entities/notification_preferences.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/usecases/get_notification_preferences.dart';
import 'package:padelclub_desktop/features/notification_settings/domain/usecases/save_notification_preferences.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  NotificationSettingsProvider(this._getPreferences, this._savePreferences);

  final GetNotificationPreferences _getPreferences;
  final SaveNotificationPreferences _savePreferences;

  NotificationPreferences _preferences =
      const NotificationPreferences.defaults();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  String? _errorMessage;

  NotificationPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasChanges => _hasChanges;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _preferences = await _getPreferences();
      _hasChanges = false;
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateDraft({
    bool? inAppEnabled,
    bool? emailEnabled,
    bool? pushEnabled,
  }) {
    final updated = _preferences.copyWith(
      inAppEnabled: inAppEnabled,
      emailEnabled: emailEnabled,
      pushEnabled: pushEnabled,
    );
    if (updated.inAppEnabled == _preferences.inAppEnabled &&
        updated.emailEnabled == _preferences.emailEnabled &&
        updated.pushEnabled == _preferences.pushEnabled) {
      return;
    }
    _preferences = updated;
    _hasChanges = true;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> save() async {
    if (_isSaving || _isLoading || !_hasChanges) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _preferences = await _savePreferences(_preferences);
      _hasChanges = false;
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  String _message(Object error) {
    return error.toString().replaceFirst('Bad state: ', '');
  }
}
