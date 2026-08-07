import 'package:padelclub_desktop/features/order_items/data/datasources/order_item_remote_data_source.dart';
import 'package:padelclub_desktop/features/order_items/domain/entities/order_item.dart';
import 'package:padelclub_desktop/features/order_items/domain/repositories/order_item_repository.dart';

class OrderItemRepositoryImpl implements OrderItemRepository {
  final OrderItemRemoteDataSource remoteDataSource;

  OrderItemRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<OrderItem>> getOrderItems({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getOrderItems(filter: filter);
  }
}
