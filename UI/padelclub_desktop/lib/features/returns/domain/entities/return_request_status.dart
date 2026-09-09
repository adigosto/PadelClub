/// The current authoritative lifecycle record for a merchandise return.
class ReturnRequestStatus {
  const ReturnRequestStatus({
    required this.id,
    required this.orderId,
    required this.reason,
    required this.status,
    required this.refundAmount,
    required this.createdAt,
    this.userId,
    this.adminNotes,
    this.resolvedAt,
  });

  final int id;
  final int orderId;
  final int? userId;
  final String reason;
  final String status;
  final double refundAmount;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool get isRequested => status.trim().toLowerCase() == 'requested';
}

/// The minimal acknowledgement returned immediately after a request is made.
class ReturnRequestSubmission {
  const ReturnRequestSubmission({
    required this.id,
    required this.status,
    required this.refundAmount,
  });

  final int id;
  final String status;
  final double refundAmount;
}
