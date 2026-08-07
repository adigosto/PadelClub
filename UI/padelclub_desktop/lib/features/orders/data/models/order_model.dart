import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';

class OrderModel extends Order {
  OrderModel({super.id, required super.userId, required super.total, required super.date});

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as int?,
      userId: json['userId'] as int,
      total: (json['total'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'total': total,
        'date': date.toIso8601String(),
      };
}
