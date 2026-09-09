import 'package:padelclub_desktop/features/privacy/data/datasources/privacy_remote_data_source.dart';
import 'package:padelclub_desktop/features/privacy/domain/entities/privacy_deletion_status.dart';
import 'package:padelclub_desktop/features/privacy/domain/repositories/privacy_repository.dart';

class PrivacyRepositoryImpl implements PrivacyRepository {
  const PrivacyRepositoryImpl(this._remoteDataSource);

  final PrivacyRemoteDataSource _remoteDataSource;

  @override
  Future<void> cancelDeletion() => _remoteDataSource.cancelDeletion();

  @override
  Future<Map<String, dynamic>> exportMine() => _remoteDataSource.exportMine();

  @override
  Future<PrivacyDeletionStatus?> getDeletionStatus() {
    return _remoteDataSource.getDeletionStatus();
  }

  @override
  Future<PrivacyDeletionStatus> requestDeletion() {
    return _remoteDataSource.requestDeletion();
  }
}
