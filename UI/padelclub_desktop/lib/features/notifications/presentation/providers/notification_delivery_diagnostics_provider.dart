import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/notifications/data/notification_delivery_remote_data_source.dart';
import 'package:padelclub_desktop/features/notifications/domain/entities/notification_delivery.dart';

/// Owns the current immutable server snapshot of notification deliveries.
class NotificationDeliveryDiagnosticsProvider extends ChangeNotifier {
  NotificationDeliveryDiagnosticsProvider(this._dataSource);

  factory NotificationDeliveryDiagnosticsProvider.live() =>
      NotificationDeliveryDiagnosticsProvider(
        NotificationDeliveryRemoteDataSourceImpl(),
      );

  final NotificationDeliveryRemoteDataSource _dataSource;

  List<NotificationDelivery> _deliveries = const [];
  String? _activeStatus;
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationDelivery> get deliveries => List.unmodifiable(_deliveries);
  String? get activeStatus => _activeStatus;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({String? status}) async {
    if (_isLoading) return;

    _activeStatus = _normalizedStatus(status);
    _isLoading = true;
    _deliveries = const [];
    _errorMessage = null;
    notifyListeners();
    try {
      _deliveries = List.unmodifiable(
        await _dataSource.getDeliveries(status: _activeStatus),
      );
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _normalizedStatus(String? status) {
    final value = status?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
