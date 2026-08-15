import 'package:padelclub_desktop/features/reservations/data/datasources/reservation_remote_data_source.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';
import 'package:padelclub_desktop/features/reservations/domain/repositories/reservation_repository.dart';

class ReservationRepositoryImpl implements ReservationRepository {
  final ReservationRemoteDataSource remoteDataSource;

  ReservationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Reservation>> getReservations({
    Map<String, dynamic>? filter,
  }) async {
    return await remoteDataSource.getReservations(filter: filter);
  }
}
