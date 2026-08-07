import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';
import 'package:padelclub_desktop/features/reservations/domain/repositories/reservation_repository.dart';

class GetReservations {
  final ReservationRepository repository;

  const GetReservations(this.repository);

  Future<List<Reservation>> call({Map<String, dynamic>? filter}) {
    return repository.getReservations(filter: filter);
  }
}
