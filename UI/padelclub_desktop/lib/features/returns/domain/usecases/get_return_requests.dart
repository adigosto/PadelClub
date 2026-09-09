import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';
import 'package:padelclub_desktop/features/returns/domain/repositories/return_requests_repository.dart';

class GetReturnRequests {
  const GetReturnRequests(this._repository);

  final ReturnRequestsRepository _repository;

  Future<List<ReturnRequestStatus>> call({String? status}) =>
      _repository.getAll(status: status);
}
