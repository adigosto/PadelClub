import 'package:padelclub_desktop/features/inventory_operations/domain/repositories/inventory_operations_repository.dart';

class AdjustInventory {
  const AdjustInventory(this._repository);

  final InventoryOperationsRepository _repository;

  Future<void> call({
    required int productId,
    required int quantityChange,
    required String reason,
  }) => _repository.adjustStock(
    productId: productId,
    quantityChange: quantityChange,
    reason: reason,
  );
}
