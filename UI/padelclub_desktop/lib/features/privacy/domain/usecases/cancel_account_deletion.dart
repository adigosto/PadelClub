import 'package:padelclub_desktop/features/privacy/domain/repositories/privacy_repository.dart';

class CancelAccountDeletion {
  const CancelAccountDeletion(this._repository);

  final PrivacyRepository _repository;

  Future<void> call() => _repository.cancelDeletion();
}
