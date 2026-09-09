import 'package:padelclub_desktop/features/privacy/domain/entities/privacy_deletion_status.dart';
import 'package:padelclub_desktop/features/privacy/domain/repositories/privacy_repository.dart';

class GetAccountDeletionStatus {
  const GetAccountDeletionStatus(this._repository);

  final PrivacyRepository _repository;

  Future<PrivacyDeletionStatus?> call() => _repository.getDeletionStatus();
}
