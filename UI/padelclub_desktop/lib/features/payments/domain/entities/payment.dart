class Payment {
  Payment({this.id, required this.orderId, required this.amount, required this.date});
  int? id;
  int orderId;
  double amount;
  DateTime date;
}

class Payable {
  const Payable(this.id, this.type, this.description, this.amount, this.currency);
  final int id;
  final String type, description, currency;
  final double amount;
}
class PaymentIntent {
  const PaymentIntent(this.id, this.clientSecret, this.publishableKey);
  final int id;
  final String clientSecret, publishableKey;
}
abstract class PaymentSheetPresenter {
  bool get available;
  Future<void> present(PaymentIntent intent);
}
class UnavailablePaymentSheet implements PaymentSheetPresenter {
  const UnavailablePaymentSheet();
  @override
  bool get available => false;
  @override
  Future<void> present(PaymentIntent intent) => throw StateError('Use the mobile app to pay.');
}
