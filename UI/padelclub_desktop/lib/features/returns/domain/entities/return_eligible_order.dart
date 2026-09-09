/// A delivered order line the server has determined is still eligible for a
/// customer return. Quantities and dates are supplied by the server so the UI
/// never infers eligibility from a stale local order snapshot.
class ReturnEligibleOrder {
  const ReturnEligibleOrder({
    required this.orderId,
    required this.orderNumber,
    required this.deliveredAt,
    required this.returnWindowEndsAt,
    required this.items,
  });

  final int orderId;
  final String orderNumber;
  final DateTime deliveredAt;
  final DateTime returnWindowEndsAt;
  final List<ReturnEligibleOrderItem> items;

  bool get hasReturnableItems =>
      items.any((item) => item.remainingReturnableQuantity > 0);
}

class ReturnEligibleOrderItem {
  const ReturnEligibleOrderItem({
    required this.orderItemId,
    required this.productName,
    required this.quantity,
    required this.remainingReturnableQuantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final int orderItemId;
  final String productName;
  final int quantity;
  final int remainingReturnableQuantity;
  final double unitPrice;
  final double lineTotal;
}

/// A selected order-line quantity sent to the server when creating a return.
class ReturnRequestLine {
  const ReturnRequestLine({required this.orderItemId, required this.quantity});

  final int orderItemId;
  final int quantity;
}
