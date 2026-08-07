import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
import 'package:padelclub_desktop/features/orders/domain/repositories/order_repository.dart';

class GetOrders {
  final OrderRepository repository;

  const GetOrders(this.repository);

  Future<List<Order>> call({Map<String, dynamic>? filter}) {
    return repository.getOrders(filter: filter);
  }
}
