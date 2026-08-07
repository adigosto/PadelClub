import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
import 'package:padelclub_desktop/features/payments/domain/repositories/payment_repository.dart';

class GetPayments {
  final PaymentRepository repository;

  const GetPayments(this.repository);

  Future<List<Payment>> call({Map<String, dynamic>? filter}) {
    return repository.getPayments(filter: filter);
  }
}
