import 'package:padelclub_desktop/features/privacy/domain/entities/privacy_deletion_status.dart';

abstract interface class PrivacyRepository {
  Future<Map<String, dynamic>> exportMine();

  Future<PrivacyDeletionStatus?> getDeletionStatus();

  Future<PrivacyDeletionStatus> requestDeletion();

  Future<void> cancelDeletion();
}
