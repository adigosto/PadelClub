import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';

class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.userId,
    required super.orderNumber,
    required super.totalAmount,
    required super.status,
    required super.recipientName,
    required super.phoneNumber,
    required super.shippingAddress,
    required super.city,
    required super.postalCode,
    required super.createdAt,
    super.notes,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      orderNumber: json['orderNumber'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      status: json['status'] as String? ?? 'Pending',
      recipientName: json['recipientName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      shippingAddress: json['shippingAddress'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'orderNumber': orderNumber,
    'totalAmount': totalAmount,
    'status': status,
    'recipientName': recipientName,
    'phoneNumber': phoneNumber,
    'shippingAddress': shippingAddress,
    'city': city,
    'postalCode': postalCode,
    'createdAt': createdAt.toIso8601String(),
    'notes': notes,
  };
}
