import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';

class PaymentModel extends Payment {
  PaymentModel({
    super.id,
    required super.orderId,
    required super.amount,
    required super.date,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as int?,
      orderId: json['orderId'] as int,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'amount': amount,
    'date': date.toIso8601String(),
  };
}
