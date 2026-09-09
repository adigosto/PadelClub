import 'package:padelclub_desktop/features/inventory_operations/data/datasources/inventory_operations_remote_data_source.dart';
import 'package:padelclub_desktop/features/inventory_operations/domain/entities/inventory_movement.dart';
import 'package:padelclub_desktop/features/inventory_operations/domain/repositories/inventory_operations_repository.dart';

class InventoryOperationsRepositoryImpl
    implements InventoryOperationsRepository {
  const InventoryOperationsRepositoryImpl(this._remoteDataSource);

  final InventoryOperationsRemoteDataSource _remoteDataSource;

  @override
  Future<void> adjustStock({
    required int productId,
    required int quantityChange,
    required String reason,
  }) => _remoteDataSource.adjustStock(
    productId: productId,
    quantityChange: quantityChange,
    reason: reason,
  );

  @override
  Future<List<InventoryMovement>> getHistory(int productId) =>
      _remoteDataSource.getHistory(productId);
}
