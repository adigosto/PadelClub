import 'package:padelclub_desktop/features/order_items/domain/entities/order_item.dart';
import 'package:padelclub_desktop/features/order_items/domain/repositories/order_item_repository.dart';

class GetOrderItems {
  final OrderItemRepository repository;

  const GetOrderItems(this.repository);

  Future<List<OrderItem>> call({Map<String, dynamic>? filter}) {
    return repository.getOrderItems(filter: filter);
  }
}
