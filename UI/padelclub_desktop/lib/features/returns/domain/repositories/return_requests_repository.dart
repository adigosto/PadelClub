import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';

abstract interface class ReturnRequestsRepository {
  Future<List<ReturnEligibleOrder>> getEligibleOrders();

  Future<ReturnRequestSubmission> createRequest({
    required int orderId,
    required String reason,
    required List<ReturnRequestLine> items,
  });

  Future<List<ReturnRequestStatus>> getMine();

  Future<List<ReturnRequestStatus>> getAll({String? status});

  Future<void> resolve({
    required int returnRequestId,
    required bool approve,
    String? adminNotes,
  });
}
