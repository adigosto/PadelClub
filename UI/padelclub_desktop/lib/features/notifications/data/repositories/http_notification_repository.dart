import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/core/network/api_error.dart';
import 'package:padelclub_desktop/features/notifications/data/models/club_notification_model.dart';
import 'package:padelclub_desktop/features/notifications/domain/entities/club_notification.dart';
import 'package:padelclub_desktop/features/notifications/domain/repositories/notification_repository.dart';

class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository({required this.headers, http.Client? client}) : _client = client ?? http.Client();
  final Map<String, String> Function() headers;
  final http.Client _client;
  Future<http.Response> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'))..headers.addAll(headers());
    if (body != null) request.body = jsonEncode(body);
    final response = await _client.send(request).then(http.Response.fromStream).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(apiErrorMessage(response.body));
    }
    return response;
  }
  @override
  Future<List<ClubNotification>> load({required bool admin}) async {
    final response = await _send('GET', '${admin ? '/Notifications' : '/Notifications/mine'}?PageSize=100');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>).map((x) => ClubNotificationModel.fromJson(x as Map<String, dynamic>)).toList();
  }
  @override
  Future<void> create(String title, String message, String type, List<int> recipients) async {
    await _send('POST', '/Notifications', {'title': title, 'message': message, 'type': type, 'recipientUserIds': recipients});
  }
  @override
  Future<void> update(ClubNotification n) async {
    await _send('PUT', '/Notifications/${n.id}', {'title': n.title, 'message': n.message, 'type': n.type});
  }
  @override
  Future<void> delete(int id) async { await _send('DELETE', '/Notifications/$id'); }
  @override
  Future<void> markRead(int? id) async { await _send('PUT', id == null ? '/Notifications/read-all' : '/Notifications/$id/read'); }
  @override
  void dispose() => _client.close();
}
