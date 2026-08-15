import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';

class ReservationModel extends Reservation {
  const ReservationModel({
    required super.id,
    required super.courtId,
    required super.userId,
    required super.startTime,
    required super.endTime,
    required super.totalPrice,
    required super.status,
    super.notes,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'] as int,
      courtId: json['courtId'] as int,
      userId: json['userId'] as int,
      startTime: DateTime.parse(json['startTime'] as String).toLocal(),
      endTime: DateTime.parse(json['endTime'] as String).toLocal(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'courtId': courtId,
    'userId': userId,
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
    'totalPrice': totalPrice,
    'status': status,
    'notes': notes,
  };
}
