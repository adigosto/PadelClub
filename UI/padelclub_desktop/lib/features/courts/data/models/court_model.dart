import 'package:padelclub_desktop/features/courts/domain/entities/court.dart';

class CourtModel extends Court {
  const CourtModel({
    required super.id,
    required super.name,
    required super.description,
    required super.isIndoor,
    required super.isActive,
    required super.hourlyRate,
    required super.maxPlayers,
    required super.createdAt,
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isIndoor: json['isIndoor'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      hourlyRate: (json['hourlyRate'] as num? ?? 0).toDouble(),
      maxPlayers: (json['maxPlayers'] as num? ?? 4).toInt(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
