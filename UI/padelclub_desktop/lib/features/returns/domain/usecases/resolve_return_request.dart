import 'package:padelclub_desktop/features/returns/domain/repositories/return_requests_repository.dart';

class ResolveReturnRequest {
  const ResolveReturnRequest(this._repository);

  final ReturnRequestsRepository _repository;

  Future<void> call({
    required int returnRequestId,
    required bool approve,
    String? adminNotes,
  }) => _repository.resolve(
    returnRequestId: returnRequestId,
    approve: approve,
    adminNotes: adminNotes,
  );
}
