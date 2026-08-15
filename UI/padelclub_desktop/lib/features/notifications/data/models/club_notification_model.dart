import 'package:padelclub_desktop/features/notifications/domain/entities/club_notification.dart';

class ClubNotificationModel extends ClubNotification {
  const ClubNotificationModel({
    required super.id,
    required super.title,
    required super.message,
    required super.type,
    required super.createdAt,
    required super.recipientCount,
    required super.readCount,
    super.updatedAt,
    super.isRead,
    super.readAt,
  });

  factory ClubNotificationModel.fromJson(Map<String, dynamic> json) {
    return ClubNotificationModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'System',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.tryParse(
        json['updatedAt'] as String? ?? '',
      )?.toLocal(),
      recipientCount: (json['recipientCount'] as num? ?? 0).toInt(),
      readCount: (json['readCount'] as num? ?? 0).toInt(),
      isRead: json['isRead'] as bool?,
      readAt: DateTime.tryParse(json['readAt'] as String? ?? '')?.toLocal(),
    );
  }
}
