import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';

class ReservationModel extends Reservation {
  ReservationModel({super.id, required super.courtId, required super.userId, required super.start, required super.end});

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'] as int?,
      courtId: json['courtId'] as int,
      userId: json['userId'] as int,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courtId': courtId,
        'userId': userId,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };
}
