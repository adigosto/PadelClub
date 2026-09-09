import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';
import 'package:padelclub_desktop/features/returns/domain/repositories/return_requests_repository.dart';

class GetMyReturnRequests {
  const GetMyReturnRequests(this._repository);

  final ReturnRequestsRepository _repository;

  Future<List<ReturnRequestStatus>> call() => _repository.getMine();
}
