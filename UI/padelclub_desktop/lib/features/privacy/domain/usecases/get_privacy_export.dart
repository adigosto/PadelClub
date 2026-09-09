import 'package:padelclub_desktop/features/privacy/domain/repositories/privacy_repository.dart';

class GetPrivacyExport {
  const GetPrivacyExport(this._repository);

  final PrivacyRepository _repository;

  Future<Map<String, dynamic>> call() => _repository.exportMine();
}
