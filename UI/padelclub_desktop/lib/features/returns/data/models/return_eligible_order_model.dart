import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';

class ReturnEligibleOrderModel extends ReturnEligibleOrder {
  const ReturnEligibleOrderModel({
    required super.orderId,
    required super.orderNumber,
    required super.deliveredAt,
    required super.returnWindowEndsAt,
    required super.items,
  });

  factory ReturnEligibleOrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Return eligibility contains invalid items.');
    }
    return ReturnEligibleOrderModel(
      orderId: _requiredInt(json, 'orderId'),
      orderNumber: json['orderNumber'] as String? ?? '',
      deliveredAt: _requiredDate(json, 'deliveredAt'),
      returnWindowEndsAt: _requiredDate(json, 'returnWindowEndsAt'),
      items: rawItems
          .map((item) {
            if (item is! Map) {
              throw const FormatException(
                'Return eligibility contains an invalid order item.',
              );
            }
            return ReturnEligibleOrderItemModel.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .toList(growable: false),
    );
  }
}

class ReturnEligibleOrderItemModel extends ReturnEligibleOrderItem {
  const ReturnEligibleOrderItemModel({
    required super.orderItemId,
    required super.productName,
    required super.quantity,
    required super.remainingReturnableQuantity,
    required super.unitPrice,
    required super.lineTotal,
  });

  factory ReturnEligibleOrderItemModel.fromJson(Map<String, dynamic> json) {
    return ReturnEligibleOrderItemModel(
      orderItemId: _requiredInt(json, 'orderItemId'),
      productName: json['productName'] as String? ?? 'Product',
      quantity: _requiredInt(json, 'quantity'),
      remainingReturnableQuantity: _requiredInt(
        json,
        'remainingReturnableQuantity',
      ),
      unitPrice: _requiredDouble(json, 'unitPrice'),
      lineTotal: _requiredDouble(json, 'lineTotal'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('Return eligibility contains an invalid $key.');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Return eligibility contains an invalid $key.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Return eligibility contains an invalid $key.');
  }
  return DateTime.parse(value);
}
