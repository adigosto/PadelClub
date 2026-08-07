import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';

abstract class OrderRepository {
  Future<List<Order>> getOrders({Map<String, dynamic>? filter});
}
