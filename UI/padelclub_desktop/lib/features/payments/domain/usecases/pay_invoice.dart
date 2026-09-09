import 'package:padelclub_desktop/features/payments/domain/entities/payment.dart';
import 'package:padelclub_desktop/features/payments/domain/repositories/payment_repository.dart';
class PayInvoice {
  const PayInvoice(this.repository, this.presenter);
  final PaymentRepository repository;
  final PaymentSheetPresenter presenter;
  Future<String> call(Payable payable, {bool Function()? cancelled}) async {
    final intent = await repository.create(payable);
    if (cancelled?.call() == true) return 'Pending';
    final before = await repository.status(intent.id);
    if (before == 'Completed') return before;
    await presenter.present(intent);
    for (var attempt = 0; attempt < 15; attempt++) {
      if (cancelled?.call() == true) return 'Pending';
      final state = await repository.status(intent.id);
      if (state == 'Completed' || state == 'Cancelled' || state == 'Refunded' || state == 'PartiallyRefunded') return state;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return 'Pending';
  }
}
class LoadPayables {
  const LoadPayables(this.repository);
  final PaymentRepository repository;
  Future<List<Payable>> call(String type, int page) => repository.load(type, page);
}
