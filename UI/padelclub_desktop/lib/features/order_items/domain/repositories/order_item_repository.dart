import 'package:padelclub_desktop/features/order_items/domain/entities/order_item.dart';

abstract class OrderItemRepository {
  Future<List<OrderItem>> getOrderItems({Map<String, dynamic>? filter});
}
