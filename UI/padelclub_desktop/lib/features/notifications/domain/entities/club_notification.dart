class ClubNotification {
  const ClubNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.recipientCount,
    required this.readCount,
    this.updatedAt,
    this.isRead,
    this.readAt,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int recipientCount;
  final int readCount;
  final bool? isRead;
  final DateTime? readAt;

  bool get hasUnreadRecipients => readCount < recipientCount;
}
