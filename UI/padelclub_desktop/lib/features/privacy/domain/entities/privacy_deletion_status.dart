class PrivacyDeletionStatus {
  const PrivacyDeletionStatus({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.scheduledFor,
    this.completedAt,
    this.cancelledAt,
  });

  final int id;
  final String status;
  final DateTime requestedAt;
  final DateTime? scheduledFor;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  bool get isScheduled => status.trim().toLowerCase() == 'scheduled';

  bool get isCancelled => status.trim().toLowerCase() == 'cancelled';

  bool get isCompleted => status.trim().toLowerCase() == 'completed';

  PrivacyDeletionStatus copyWith({
    String? status,
    DateTime? requestedAt,
    DateTime? scheduledFor,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) {
    return PrivacyDeletionStatus(
      id: id,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}
