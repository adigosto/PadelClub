import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
abstract class PaymentRepository {
  Future<List<Payable>> load(String type, int page) => throw UnimplementedError();
  Future<PaymentIntent> create(Payable payable) => throw UnimplementedError();
  Future<String> status(int paymentId) => throw UnimplementedError();
  Future<List<Payment>> getPayments({Map<String, dynamic>? filter}) => throw UnimplementedError();
  void dispose() {}
}
