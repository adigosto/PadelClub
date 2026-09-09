import 'package:padelclub_desktop/features/inventory_operations/domain/entities/inventory_movement.dart';
import 'package:padelclub_desktop/features/inventory_operations/domain/repositories/inventory_operations_repository.dart';

class GetInventoryHistory {
  const GetInventoryHistory(this._repository);

  final InventoryOperationsRepository _repository;

  Future<List<InventoryMovement>> call(int productId) =>
      _repository.getHistory(productId);
}
