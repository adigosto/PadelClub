class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.orderNumber,
    required this.totalAmount,
    required this.status,
    required this.recipientName,
    required this.phoneNumber,
    required this.shippingAddress,
    required this.city,
    required this.postalCode,
    required this.createdAt,
    this.notes,
  });

  final int id;
  final int userId;
  final String orderNumber;
  final double totalAmount;
  final String status;
  final String recipientName;
  final String phoneNumber;
  final String shippingAddress;
  final String city;
  final String postalCode;
  final DateTime createdAt;
  final String? notes;
}
