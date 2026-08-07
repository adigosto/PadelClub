import 'package:padelclub_desktop/features/orders/data/datasources/order_remote_data_source.dart';
import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
import 'package:padelclub_desktop/features/orders/domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remoteDataSource;

  OrderRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Order>> getOrders({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getOrders(filter: filter);
  }
}
