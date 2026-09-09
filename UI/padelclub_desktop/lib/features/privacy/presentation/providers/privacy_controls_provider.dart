import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/privacy/data/datasources/privacy_remote_data_source.dart';
import 'package:padelclub_desktop/features/privacy/data/repositories/privacy_repository_impl.dart';
import 'package:padelclub_desktop/features/privacy/domain/entities/privacy_deletion_status.dart';
import 'package:padelclub_desktop/features/privacy/domain/usecases/cancel_account_deletion.dart';
import 'package:padelclub_desktop/features/privacy/domain/usecases/get_account_deletion_status.dart';
import 'package:padelclub_desktop/features/privacy/domain/usecases/get_privacy_export.dart';
import 'package:padelclub_desktop/features/privacy/domain/usecases/request_account_deletion.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class PrivacyControlsProvider extends ChangeNotifier {
  PrivacyControlsProvider(
    this._getDeletionStatus,
    this._requestDeletion,
    this._cancelDeletion,
    this._getPrivacyExport,
  );

  factory PrivacyControlsProvider.live() {
    final remote = PrivacyRemoteDataSourceImpl(
      headersProvider: AuthProvider.authenticatedHeaders,
    );
    final repository = PrivacyRepositoryImpl(remote);
    return PrivacyControlsProvider(
      GetAccountDeletionStatus(repository),
      RequestAccountDeletion(repository),
      CancelAccountDeletion(repository),
      GetPrivacyExport(repository),
    );
  }

  final GetAccountDeletionStatus _getDeletionStatus;
  final RequestAccountDeletion _requestDeletion;
  final CancelAccountDeletion _cancelDeletion;
  final GetPrivacyExport _getPrivacyExport;

  PrivacyDeletionStatus? _deletionStatus;
  bool _isLoadingStatus = false;
  bool _isRequestingDeletion = false;
  bool _isCancellingDeletion = false;
  bool _isLoadingExport = false;
  String? _errorMessage;

  PrivacyDeletionStatus? get deletionStatus => _deletionStatus;
  bool get isLoadingStatus => _isLoadingStatus;
  bool get isRequestingDeletion => _isRequestingDeletion;
  bool get isCancellingDeletion => _isCancellingDeletion;
  bool get isLoadingExport => _isLoadingExport;
  bool get isMutatingDeletion => _isRequestingDeletion || _isCancellingDeletion;
  String? get errorMessage => _errorMessage;

  Future<void> loadDeletionStatus() async {
    if (_isLoadingStatus || isMutatingDeletion) return;
    _isLoadingStatus = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _deletionStatus = await _getDeletionStatus();
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _isLoadingStatus = false;
      notifyListeners();
    }
  }

  Future<bool> requestDeletion() async {
    if (isMutatingDeletion || _isLoadingStatus) return false;
    _isRequestingDeletion = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _deletionStatus = await _requestDeletion();
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _isRequestingDeletion = false;
      notifyListeners();
    }
  }

  Future<bool> cancelDeletion() async {
    if (isMutatingDeletion || _isLoadingStatus) return false;
    _isCancellingDeletion = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _cancelDeletion();
      final existing = _deletionStatus;
      if (existing != null) {
        _deletionStatus = existing.copyWith(status: 'Cancelled');
      }
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _isCancellingDeletion = false;
      notifyListeners();
    }
  }

  /// Fetches the authenticated player's JSON export for immediate display only.
  ///
  /// The provider deliberately does not retain or write this sensitive payload.
  Future<Map<String, dynamic>?> viewExport() async {
    if (_isLoadingExport) return null;
    _isLoadingExport = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return Map<String, dynamic>.unmodifiable(await _getPrivacyExport());
    } catch (error) {
      _errorMessage = _message(error);
      return null;
    } finally {
      _isLoadingExport = false;
      notifyListeners();
    }
  }

  String _message(Object error) {
    return error.toString().replaceFirst('Bad state: ', '');
  }
}
