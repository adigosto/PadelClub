import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';

/// Editable fields supported by the administrator Tournament CRUD contract.
class TournamentDraft {
  const TournamentDraft({
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.registrationDeadline,
    required this.maxParticipants,
    required this.entryFee,
    this.prizeInfo,
  });

  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registrationDeadline;
  final int maxParticipants;
  final double entryFee;
  final String? prizeInfo;

  factory TournamentDraft.fromTournament(Tournament tournament) =>
      TournamentDraft(
        name: tournament.name,
        description: tournament.description,
        startDate: tournament.startDate,
        endDate: tournament.endDate,
        registrationDeadline: tournament.registrationDeadline,
        maxParticipants: tournament.maxParticipants,
        entryFee: tournament.entryFee,
        prizeInfo: tournament.prizeInfo,
      );

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'description': description.trim(),
    'startDate': startDate.toUtc().toIso8601String(),
    'endDate': endDate.toUtc().toIso8601String(),
    'registrationDeadline': registrationDeadline.toUtc().toIso8601String(),
    'maxParticipants': maxParticipants,
    'entryFee': entryFee,
    'prizeInfo': prizeInfo?.trim().isEmpty == true ? null : prizeInfo?.trim(),
  };
}
