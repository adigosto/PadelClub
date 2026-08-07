import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';

abstract class ReservationRepository {
  Future<List<Reservation>> getReservations({Map<String, dynamic>? filter});
}
