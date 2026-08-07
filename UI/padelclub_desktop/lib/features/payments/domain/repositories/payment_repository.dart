import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';

abstract class PaymentRepository {
  Future<List<Payment>> getPayments({Map<String, dynamic>? filter});
}
