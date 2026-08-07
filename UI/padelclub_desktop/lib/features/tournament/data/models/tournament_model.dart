import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';

class TournamentModel extends Tournament {
  TournamentModel({super.id, required super.name});

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      id: json['id'] as int?,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}
