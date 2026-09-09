import 'package:padelclub_desktop/features/privacy/domain/entities/privacy_deletion_status.dart';

class PrivacyDeletionStatusModel extends PrivacyDeletionStatus {
  const PrivacyDeletionStatusModel({
    required super.id,
    required super.status,
    required super.requestedAt,
    super.scheduledFor,
    super.completedAt,
    super.cancelledAt,
  });

  factory PrivacyDeletionStatusModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];
    if (id is! num || status is! String || status.trim().isEmpty) {
      throw const FormatException(
        'Deletion status returned an invalid response.',
      );
    }

    return PrivacyDeletionStatusModel(
      id: id.toInt(),
      status: status,
      requestedAt: _requiredDate(json, 'requestedAt'),
      scheduledFor: _optionalDate(json, 'scheduledFor'),
      completedAt: _optionalDate(json, 'completedAt'),
      cancelledAt: _optionalDate(json, 'cancelledAt'),
    );
  }

  static DateTime _requiredDate(Map<String, dynamic> json, String key) {
    final value = _optionalDate(json, key);
    if (value == null) {
      throw FormatException('Deletion status is missing "$key".');
    }
    return value;
  }

  static DateTime? _optionalDate(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Deletion status contains an invalid "$key".');
    }
    return DateTime.tryParse(value) ??
        (throw FormatException('Deletion status contains an invalid "$key".'));
  }
}
