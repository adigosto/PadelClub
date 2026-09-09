import 'package:padelclub_desktop/features/notifications/domain/entities/club_notification.dart';

abstract class NotificationRepository {
  Future<List<ClubNotification>> load({required bool admin});
  Future<void> create(String title, String message, String type, List<int> recipients);
  Future<void> update(ClubNotification notification);
  Future<void> delete(int id);
  Future<void> markRead(int? id);
  void dispose();
}
