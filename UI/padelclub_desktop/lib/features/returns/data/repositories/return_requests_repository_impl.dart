import 'package:padelclub_desktop/features/returns/data/datasources/return_requests_remote_data_source.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';
import 'package:padelclub_desktop/features/returns/domain/repositories/return_requests_repository.dart';

class ReturnRequestsRepositoryImpl implements ReturnRequestsRepository {
  const ReturnRequestsRepositoryImpl(this._remoteDataSource);

  final ReturnRequestsRemoteDataSource _remoteDataSource;

  @override
  Future<List<ReturnEligibleOrder>> getEligibleOrders() =>
      _remoteDataSource.getEligibleOrders();

  @override
  Future<ReturnRequestSubmission> createRequest({
    required int orderId,
    required String reason,
    required List<ReturnRequestLine> items,
  }) => _remoteDataSource.createRequest(
    orderId: orderId,
    reason: reason,
    items: items,
  );

  @override
  Future<List<ReturnRequestStatus>> getMine() => _remoteDataSource.getMine();

  @override
  Future<List<ReturnRequestStatus>> getAll({String? status}) =>
      _remoteDataSource.getAll(status: status);

  @override
  Future<void> resolve({
    required int returnRequestId,
    required bool approve,
    String? adminNotes,
  }) => _remoteDataSource.resolve(
    returnRequestId: returnRequestId,
    approve: approve,
    adminNotes: adminNotes,
  );
}
