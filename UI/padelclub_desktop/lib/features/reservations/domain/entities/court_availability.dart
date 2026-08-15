class AvailabilitySlot {
  const AvailabilitySlot({
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.isAvailable,
  });

  final DateTime startTime;
  final DateTime endTime;
  final double price;
  final bool isAvailable;
}

class CourtAvailability {
  const CourtAvailability({
    required this.courtId,
    required this.courtName,
    required this.isIndoor,
    required this.maxPlayers,
    required this.hourlyRate,
    required this.slots,
  });

  final int courtId;
  final String courtName;
  final bool isIndoor;
  final int maxPlayers;
  final double hourlyRate;
  final List<AvailabilitySlot> slots;
}
