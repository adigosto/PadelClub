import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/inventory_operations/data/datasources/inventory_operations_remote_data_source.dart';
import 'package:padelclub_desktop/features/inventory_operations/data/repositories/inventory_operations_repository_impl.dart';
import 'package:padelclub_desktop/features/inventory_operations/domain/entities/inventory_movement.dart';
import 'package:padelclub_desktop/features/inventory_operations/domain/usecases/adjust_inventory.dart';
import 'package:padelclub_desktop/features/inventory_operations/domain/usecases/get_inventory_history.dart';

/// Keeps inventory mutations serialized in the UI and returns the authoritative
/// server audit rows after every successful adjustment.
class InventoryOperationsProvider extends ChangeNotifier {
  InventoryOperationsProvider(this._adjustInventory, this._getHistory);

  factory InventoryOperationsProvider.live() {
    final remoteDataSource = InventoryOperationsRemoteDataSourceImpl();
    final repository = InventoryOperationsRepositoryImpl(remoteDataSource);
    return InventoryOperationsProvider(
      AdjustInventory(repository),
      GetInventoryHistory(repository),
    );
  }

  final AdjustInventory _adjustInventory;
  final GetInventoryHistory _getHistory;
  final Map<int, List<InventoryMovement>> _historyByProduct = {};

  int? _adjustingProductId;
  int? _loadingHistoryProductId;
  String? _errorMessage;

  int? get adjustingProductId => _adjustingProductId;
  int? get loadingHistoryProductId => _loadingHistoryProductId;
  String? get errorMessage => _errorMessage;

  bool isAdjusting(int productId) => _adjustingProductId == productId;
  bool isLoadingHistory(int productId) => _loadingHistoryProductId == productId;

  List<InventoryMovement> historyFor(int productId) =>
      List.unmodifiable(_historyByProduct[productId] ?? const []);

  Future<List<InventoryMovement>> loadHistory(int productId) async {
    if (_adjustingProductId != null || _loadingHistoryProductId != null) {
      throw StateError('Wait for the current inventory operation to finish.');
    }

    _loadingHistoryProductId = productId;
    _errorMessage = null;
    notifyListeners();
    try {
      final history = await _getHistory(productId);
      _historyByProduct[productId] = List.unmodifiable(history);
      return history;
    } catch (error) {
      _errorMessage = _message(error);
      rethrow;
    } finally {
      _loadingHistoryProductId = null;
      notifyListeners();
    }
  }

  Future<List<InventoryMovement>> adjustAndRefresh({
    required int productId,
    required int quantityChange,
    required String reason,
  }) async {
    if (_adjustingProductId != null || _loadingHistoryProductId != null) {
      throw StateError('Wait for the current inventory operation to finish.');
    }

    _adjustingProductId = productId;
    _errorMessage = null;
    notifyListeners();
    try {
      await _adjustInventory(
        productId: productId,
        quantityChange: quantityChange,
        reason: reason,
      );
      final history = await _getHistory(productId);
      _historyByProduct[productId] = List.unmodifiable(history);
      return history;
    } catch (error) {
      _errorMessage = _message(error);
      rethrow;
    } finally {
      _adjustingProductId = null;
      notifyListeners();
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
}
