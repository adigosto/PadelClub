import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/returns/data/datasources/return_requests_remote_data_source.dart';
import 'package:padelclub_desktop/features/returns/data/repositories/return_requests_repository_impl.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/create_return_request.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_eligible_return_orders.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_my_return_requests.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_return_requests.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/resolve_return_request.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

/// Separates customer return history from the staff work queue while keeping
/// server responses authoritative after every mutation.
class ReturnRequestsProvider extends ChangeNotifier {
  ReturnRequestsProvider(
    this._getEligibleOrders,
    this._createRequest,
    this._getMine,
    this._getAll,
    this._resolve,
  );

  factory ReturnRequestsProvider.live() {
    final dataSource = ReturnRequestsRemoteDataSourceImpl(
      headersProvider: AuthProvider.authenticatedHeaders,
    );
    final repository = ReturnRequestsRepositoryImpl(dataSource);
    return ReturnRequestsProvider(
      GetEligibleReturnOrders(repository),
      CreateReturnRequest(repository),
      GetMyReturnRequests(repository),
      GetReturnRequests(repository),
      ResolveReturnRequest(repository),
    );
  }

  final GetEligibleReturnOrders _getEligibleOrders;
  final CreateReturnRequest _createRequest;
  final GetMyReturnRequests _getMine;
  final GetReturnRequests _getAll;
  final ResolveReturnRequest _resolve;

  List<ReturnEligibleOrder> _eligibleOrders = const [];
  List<ReturnRequestStatus> _myReturns = const [];
  List<ReturnRequestStatus> _adminReturns = const [];
  bool _isLoadingEligibleOrders = false;
  bool _isLoadingMyReturns = false;
  bool _isLoadingAdminReturns = false;
  bool _isSubmitting = false;
  int? _resolvingReturnId;
  String? _customerErrorMessage;
  String? _adminErrorMessage;
  String? _lastAdminStatus;

  List<ReturnEligibleOrder> get eligibleOrders =>
      List.unmodifiable(_eligibleOrders);
  List<ReturnRequestStatus> get myReturns => List.unmodifiable(_myReturns);
  List<ReturnRequestStatus> get adminReturns =>
      List.unmodifiable(_adminReturns);
  bool get isLoadingEligibleOrders => _isLoadingEligibleOrders;
  bool get isLoadingMyReturns => _isLoadingMyReturns;
  bool get isLoadingCustomerData =>
      _isLoadingEligibleOrders || _isLoadingMyReturns;
  bool get isLoadingAdminReturns => _isLoadingAdminReturns;
  bool get isSubmitting => _isSubmitting;
  int? get resolvingReturnId => _resolvingReturnId;
  String? get customerErrorMessage => _customerErrorMessage;
  String? get adminErrorMessage => _adminErrorMessage;

  bool isResolving(int returnRequestId) =>
      _resolvingReturnId == returnRequestId;

  Future<void> loadCustomerData() =>
      Future.wait([loadEligibleOrders(), loadMyReturns()]);

  Future<void> loadEligibleOrders() async {
    if (_isLoadingEligibleOrders) return;
    _isLoadingEligibleOrders = true;
    _customerErrorMessage = null;
    notifyListeners();
    try {
      _eligibleOrders = List.unmodifiable(await _getEligibleOrders());
    } catch (error) {
      _customerErrorMessage = _message(error);
    } finally {
      _isLoadingEligibleOrders = false;
      notifyListeners();
    }
  }

  Future<void> loadMyReturns() async {
    if (_isLoadingMyReturns) return;
    _isLoadingMyReturns = true;
    _customerErrorMessage = null;
    notifyListeners();
    try {
      _myReturns = List.unmodifiable(await _getMine());
    } catch (error) {
      _customerErrorMessage = _message(error);
    } finally {
      _isLoadingMyReturns = false;
      notifyListeners();
    }
  }

  /// Returns the server acknowledgement or `null` if validation/network work
  /// failed. The eligibility and history endpoints are refetched afterwards,
  /// so a selected quantity is never treated as an authoritative local state.
  Future<ReturnRequestSubmission?> submit({
    required int orderId,
    required String reason,
    required List<ReturnRequestLine> items,
  }) async {
    if (_isSubmitting) return null;
    final trimmedReason = reason.trim();
    final selectedItems = items
        .where((item) => item.quantity > 0)
        .toList(growable: false);
    if (trimmedReason.length < 5 || trimmedReason.length > 1000) {
      _customerErrorMessage = 'Explain the return in 5 to 1000 characters.';
      notifyListeners();
      return null;
    }
    if (selectedItems.isEmpty) {
      _customerErrorMessage = 'Select at least one item to return.';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _customerErrorMessage = null;
    notifyListeners();
    try {
      final submission = await _createRequest(
        orderId: orderId,
        reason: trimmedReason,
        items: selectedItems,
      );
      await loadCustomerData();
      return submission;
    } catch (error) {
      _customerErrorMessage = _message(error);
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> loadAdmin({String? status}) async {
    if (_isLoadingAdminReturns || _resolvingReturnId != null) return;
    _lastAdminStatus = _normalizeStatus(status);
    _isLoadingAdminReturns = true;
    _adminErrorMessage = null;
    notifyListeners();
    try {
      _adminReturns = List.unmodifiable(
        await _getAll(status: _lastAdminStatus),
      );
    } catch (error) {
      _adminErrorMessage = _message(error);
    } finally {
      _isLoadingAdminReturns = false;
      notifyListeners();
    }
  }

  Future<bool> resolve({
    required int returnRequestId,
    required bool approve,
    String? adminNotes,
  }) async {
    if (_resolvingReturnId != null || _isLoadingAdminReturns) return false;
    _resolvingReturnId = returnRequestId;
    _adminErrorMessage = null;
    notifyListeners();
    try {
      await _resolve(
        returnRequestId: returnRequestId,
        approve: approve,
        adminNotes: adminNotes,
      );
      try {
        _adminReturns = List.unmodifiable(
          await _getAll(status: _lastAdminStatus),
        );
      } catch (error) {
        // The resolution was accepted, but preserve that fact if the follow-up
        // read fails. The next explicit refresh will obtain server state.
        _adminErrorMessage =
            'Resolution saved, but the refreshed queue could not be loaded: ${_message(error)}';
      }
      return true;
    } catch (error) {
      _adminErrorMessage = _message(error);
      return false;
    } finally {
      _resolvingReturnId = null;
      notifyListeners();
    }
  }

  String? _normalizeStatus(String? status) {
    final trimmed = status?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
}
