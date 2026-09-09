import 'package:padelclub_desktop/features/inventory_operations/domain/entities/inventory_movement.dart';

class InventoryMovementModel extends InventoryMovement {
  const InventoryMovementModel({
    required super.id,
    required super.quantityChange,
    required super.balanceAfter,
    required super.reason,
    required super.referenceType,
    required super.referenceId,
    required super.actorUserId,
    required super.createdAt,
  });

  factory InventoryMovementModel.fromJson(Map<String, dynamic> json) {
    int requiredInt(String key) {
      final value = json[key];
      if (value is num) return value.toInt();
      throw FormatException('Inventory history contains an invalid $key.');
    }

    int? optionalInt(String key) {
      final value = json[key];
      return value is num ? value.toInt() : null;
    }

    final createdAt = json['createdAt'];
    if (createdAt is! String) {
      throw const FormatException(
        'Inventory history contains an invalid date.',
      );
    }

    return InventoryMovementModel(
      id: requiredInt('id'),
      quantityChange: requiredInt('quantityChange'),
      balanceAfter: requiredInt('balanceAfter'),
      reason: json['reason'] as String? ?? '',
      referenceType: json['referenceType'] as String? ?? 'Unknown',
      referenceId: optionalInt('referenceId'),
      actorUserId: optionalInt('actorUserId'),
      createdAt: DateTime.parse(createdAt),
    );
  }
}
