import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/operations/data/provider_readiness_remote_data_source.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/provider_readiness.dart';

/// Holds one read-only server snapshot of optional-provider configuration.
class ProviderReadinessProvider extends ChangeNotifier {
  ProviderReadinessProvider(this._dataSource);

  factory ProviderReadinessProvider.live() =>
      ProviderReadinessProvider(ProviderReadinessRemoteDataSourceImpl());

  final ProviderReadinessRemoteDataSource _dataSource;

  ProviderReadiness? _readiness;
  bool _isLoading = false;
  String? _errorMessage;

  ProviderReadiness? get readiness => _readiness;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _readiness = null;
    _errorMessage = null;
    notifyListeners();
    try {
      _readiness = await _dataSource.getReadiness();
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
