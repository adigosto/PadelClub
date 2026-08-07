import 'package:padelclub_desktop/features/order_items/domain/entities/order_item.dart';

class OrderItemModel extends OrderItem {
  OrderItemModel({
    super.id,
    required super.orderId,
    required super.productId,
    required super.quantity,
    required super.unitPrice,
    required super.totalPrice,
    required super.createdAt,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as int?,
      orderId: json['orderId'] as int,
      productId: json['productId'] as int,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        'createdAt': createdAt.toIso8601String(),
      };
}
