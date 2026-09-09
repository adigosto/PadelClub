import 'package:padelclub_desktop/features/notifications/domain/entities/club_notification.dart';
import 'package:padelclub_desktop/features/notifications/domain/repositories/notification_repository.dart';

class LoadNotifications {
  const LoadNotifications(this.repository);
  final NotificationRepository repository;
  Future<List<ClubNotification>> call(bool admin) => repository.load(admin: admin);
}
class CreateNotification {
  const CreateNotification(this.repository);
  final NotificationRepository repository;
  Future<void> call(String title, String message, String type, List<int> recipients) => repository.create(title, message, type, recipients);
}
class UpdateNotification {
  const UpdateNotification(this.repository);
  final NotificationRepository repository;
  Future<void> call(ClubNotification notification) => repository.update(notification);
}
class DeleteNotification {
  const DeleteNotification(this.repository);
  final NotificationRepository repository;
  Future<void> call(int id) => repository.delete(id);
}
class MarkNotificationsRead {
  const MarkNotificationsRead(this.repository);
  final NotificationRepository repository;
  Future<void> call(int? id) => repository.markRead(id);
}
