/// A persisted inventory audit entry returned by the commerce operations API.
///
/// The balance comes from the server-side transaction, so callers can use it
/// as the authoritative stock value after an adjustment.
class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.quantityChange,
    required this.balanceAfter,
    required this.reason,
    required this.referenceType,
    required this.referenceId,
    required this.actorUserId,
    required this.createdAt,
  });

  final int id;
  final int quantityChange;
  final int balanceAfter;
  final String reason;
  final String referenceType;
  final int? referenceId;
  final int? actorUserId;
  final DateTime createdAt;

  String get signedQuantityChange =>
      quantityChange > 0 ? '+$quantityChange' : '$quantityChange';
}
