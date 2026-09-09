import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';

class ReturnRequestStatusModel extends ReturnRequestStatus {
  const ReturnRequestStatusModel({
    required super.id,
    required super.orderId,
    required super.reason,
    required super.status,
    required super.refundAmount,
    required super.createdAt,
    super.userId,
    super.adminNotes,
    super.resolvedAt,
  });

  factory ReturnRequestStatusModel.fromJson(Map<String, dynamic> json) {
    return ReturnRequestStatusModel(
      id: _requiredInt(json, 'id'),
      orderId: _requiredInt(json, 'orderId'),
      userId: _optionalInt(json, 'userId'),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'Unknown',
      refundAmount: _requiredDouble(json, 'refundAmount'),
      adminNotes: json['adminNotes'] as String?,
      createdAt: _requiredDate(json, 'createdAt'),
      resolvedAt: _optionalDate(json, 'resolvedAt'),
    );
  }
}

class ReturnRequestSubmissionModel extends ReturnRequestSubmission {
  const ReturnRequestSubmissionModel({
    required super.id,
    required super.status,
    required super.refundAmount,
  });

  factory ReturnRequestSubmissionModel.fromJson(Map<String, dynamic> json) {
    return ReturnRequestSubmissionModel(
      id: _requiredInt(json, 'id'),
      status: json['status'] as String? ?? 'Requested',
      refundAmount: _requiredDouble(json, 'refundAmount'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('Return request contains an invalid $key.');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num ? value.toInt() : null;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Return request contains an invalid $key.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Return request contains an invalid $key.');
  }
  return DateTime.parse(value);
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? DateTime.parse(value) : null;
}
