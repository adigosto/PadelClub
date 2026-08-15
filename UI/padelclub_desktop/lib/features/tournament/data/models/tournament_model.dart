import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';

class TournamentModel extends Tournament {
  const TournamentModel({
    super.id,
    required super.name,
    required super.description,
    required super.startDate,
    required super.endDate,
    required super.registrationDeadline,
    required super.maxParticipants,
    required super.entryFee,
    required super.status,
    super.prizeInfo,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      registrationDeadline: DateTime.parse(
        json['registrationDeadline'] as String,
      ),
      maxParticipants: json['maxParticipants'] as int? ?? 0,
      entryFee: (json['entryFee'] as num? ?? 0).toDouble(),
      status: json['status'] as String? ?? 'Upcoming',
      prizeInfo: json['prizeInfo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'registrationDeadline': registrationDeadline.toIso8601String(),
    'maxParticipants': maxParticipants,
    'entryFee': entryFee,
    'status': status,
    'prizeInfo': prizeInfo,
  };
}
