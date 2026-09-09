import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';
import 'package:padelclub_desktop/features/returns/domain/repositories/return_requests_repository.dart';

class GetEligibleReturnOrders {
  const GetEligibleReturnOrders(this._repository);

  final ReturnRequestsRepository _repository;

  Future<List<ReturnEligibleOrder>> call() => _repository.getEligibleOrders();
}
