import 'package:padelclub_desktop/features/privacy/domain/entities/privacy_deletion_status.dart';
import 'package:padelclub_desktop/features/privacy/domain/repositories/privacy_repository.dart';

class RequestAccountDeletion {
  const RequestAccountDeletion(this._repository);

  final PrivacyRepository _repository;

  Future<PrivacyDeletionStatus> call() => _repository.requestDeletion();
}
