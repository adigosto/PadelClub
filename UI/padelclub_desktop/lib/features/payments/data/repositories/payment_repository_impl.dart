import 'package:padelclub_desktop/features/payments/data/datasources/payment_remote_data_source.dart';
import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
import 'package:padelclub_desktop/features/payments/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;

  PaymentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Payment>> getPayments({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getPayments(filter: filter);
  }
}
