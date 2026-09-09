import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';
import 'package:padelclub_desktop/features/returns/domain/repositories/return_requests_repository.dart';

class CreateReturnRequest {
  const CreateReturnRequest(this._repository);

  final ReturnRequestsRepository _repository;

  Future<ReturnRequestSubmission> call({
    required int orderId,
    required String reason,
    required List<ReturnRequestLine> items,
  }) =>
      _repository.createRequest(orderId: orderId, reason: reason, items: items);
}
