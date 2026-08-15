class Court {
  const Court({
    required this.id,
    required this.name,
    required this.description,
    required this.isIndoor,
    required this.isActive,
    required this.hourlyRate,
    required this.maxPlayers,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final bool isIndoor;
  final bool isActive;
  final double hourlyRate;
  final int maxPlayers;
  final DateTime createdAt;
}
