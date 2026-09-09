import 'package:padelclub_desktop/features/inventory_operations/domain/entities/inventory_movement.dart';

abstract interface class InventoryOperationsRepository {
  Future<void> adjustStock({
    required int productId,
    required int quantityChange,
    required String reason,
  });

  Future<List<InventoryMovement>> getHistory(int productId);
}
