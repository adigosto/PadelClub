import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/notifications/data/models/club_notification_model.dart';
import 'package:padelclub_desktop/features/notifications/domain/entities/club_notification.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class NotificationProvider extends ChangeNotifier {
  List<ClubNotification> notifications = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadAdminNotifications() async {
    await _load('/Notifications');
  }

  Future<void> loadMine() async {
    await _load('/Notifications/mine');
  }

  Future<bool> createNotification({
    required String title,
    required String message,
    required String type,
    List<int> recipientUserIds = const [],
  }) async {
    return _mutate(
      () => http.post(
        Uri.parse('${ApiConfig.baseUrl}/Notifications'),
        headers: AuthProvider.authenticatedHeaders(),
        body: jsonEncode({
          'title': title,
          'message': message,
          'type': type,
          'recipientUserIds': recipientUserIds,
        }),
      ),
      refreshAdmin: true,
    );
  }

  Future<bool> updateNotification(ClubNotification notification) async {
    return _mutate(
      () => http.put(
        Uri.parse('${ApiConfig.baseUrl}/Notifications/${notification.id}'),
        headers: AuthProvider.authenticatedHeaders(),
        body: jsonEncode({
          'title': notification.title,
          'message': notification.message,
          'type': notification.type,
        }),
      ),
      refreshAdmin: true,
    );
  }

  Future<bool> deleteNotification(int id) async {
    return _mutate(
      () => http.delete(
        Uri.parse('${ApiConfig.baseUrl}/Notifications/$id'),
        headers: AuthProvider.authenticatedHeaders(),
      ),
      refreshAdmin: true,
    );
  }

  Future<bool> markRead(int id) async {
    return _mutate(
      () => http.put(
        Uri.parse('${ApiConfig.baseUrl}/Notifications/$id/read'),
        headers: AuthProvider.authenticatedHeaders(),
      ),
      refreshMine: true,
    );
  }

  Future<bool> markAllRead() async {
    return _mutate(
      () => http.put(
        Uri.parse('${ApiConfig.baseUrl}/Notifications/read-all'),
        headers: AuthProvider.authenticatedHeaders(),
      ),
      refreshMine: true,
    );
  }

  Future<void> _load(String path) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
        queryParameters: {'PageSize': '200', 'IncludeTotalCount': 'true'},
      );
      final response = await http.get(
        uri,
        headers: AuthProvider.authenticatedHeaders(),
      );
      _ensureSuccess(response);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      notifications = (decoded['items'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                ClubNotificationModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _mutate(
    Future<http.Response> Function() request, {
    bool refreshAdmin = false,
    bool refreshMine = false,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await request();
      _ensureSuccess(response);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
    if (refreshAdmin) {
      await loadAdminNotifications();
    } else if (refreshMine) {
      await loadMine();
    } else {
      isLoading = false;
      notifyListeners();
    }
    return errorMessage == null;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'You are not authorized to perform this notification action.',
      );
    }
    throw Exception(
      response.body.trim().isEmpty
          ? 'The notification request could not be completed.'
          : response.body.replaceAll('"', ''),
    );
  }
}
