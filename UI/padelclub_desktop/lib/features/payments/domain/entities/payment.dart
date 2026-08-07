class Payment {
  int? id;
  int orderId;
  double amount;
  DateTime date;

  Payment({this.id, required this.orderId, required this.amount, required this.date});
}
