import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/coupons/data/coupon_management_remote_data_source.dart';
import 'package:padelclub_desktop/features/coupons/domain/entities/admin_coupon.dart';

/// Owns the administrator's coupon list and serializes writes.
///
/// It always asks the server for the post-save list. That preserves redemption
/// counts and validity fields as authoritative backend state.
class CouponManagementProvider extends ChangeNotifier {
  CouponManagementProvider(this._dataSource);

  factory CouponManagementProvider.live() =>
      CouponManagementProvider(CouponManagementRemoteDataSourceImpl());

  final CouponManagementRemoteDataSource _dataSource;

  List<AdminCoupon> _coupons = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _lastOperationMessage;

  List<AdminCoupon> get coupons => List.unmodifiable(_coupons);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get lastOperationMessage => _lastOperationMessage;

  Future<void> load() async {
    if (_isLoading || _isSaving) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _coupons = List.unmodifiable(await _dataSource.getCoupons());
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(CouponDraft draft) => _save(
    action: () => _dataSource.createCoupon(draft),
    successLabel: 'Coupon created',
  );

  Future<bool> update({required int couponId, required CouponDraft draft}) =>
      _save(
        action: () =>
            _dataSource.updateCoupon(couponId: couponId, draft: draft),
        successLabel: 'Coupon updated',
      );

  Future<bool> _save({
    required Future<void> Function() action,
    required String successLabel,
  }) async {
    if (_isLoading || _isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    _lastOperationMessage = null;
    notifyListeners();
    try {
      await action();
      try {
        _coupons = List.unmodifiable(await _dataSource.getCoupons());
        _lastOperationMessage = '$successLabel and refreshed from the server.';
      } catch (error) {
        _lastOperationMessage =
            '$successLabel, but the latest list could not be refreshed: ${_message(error)}';
      }
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
}
