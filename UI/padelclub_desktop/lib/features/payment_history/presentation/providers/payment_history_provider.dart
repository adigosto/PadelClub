import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/payment_history/data/payment_history_remote_data_source.dart';
import 'package:padelclub_desktop/features/payment_history/domain/entities/payment_history_entry.dart';

/// Holds only the authenticated player's read-only payment history snapshot.
class PaymentHistoryProvider extends ChangeNotifier {
  PaymentHistoryProvider(this._dataSource);

  factory PaymentHistoryProvider.live() =>
      PaymentHistoryProvider(PaymentHistoryRemoteDataSourceImpl());

  final PaymentHistoryRemoteDataSource _dataSource;

  List<PaymentHistoryEntry> _payments = const [];
  int? _totalCount;
  bool _isLoading = false;
  String? _errorMessage;

  List<PaymentHistoryEntry> get payments => List.unmodifiable(_payments);
  int? get totalCount => _totalCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _payments = const [];
    _totalCount = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _dataSource.getMyPayments();
      _payments = List.unmodifiable(page.items);
      _totalCount = page.totalCount;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
