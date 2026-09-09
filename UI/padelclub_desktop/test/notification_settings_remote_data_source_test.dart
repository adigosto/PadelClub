import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/notification_settings/data/datasources/notification_settings_remote_data_source.dart';
import 'package:padelclub_desktop/features/notification_settings/data/models/notification_preferences_model.dart';

void main() {
  test('uses the authenticated notification preference API contract', () async {
    var requestCount = 0;
    final source = NotificationSettingsRemoteDataSourceImpl(
      client: MockClient((request) async {
        requestCount++;
        expect(request.url.path, '/NotificationSettings/mine');
        expect(request.headers['authorization'], 'Bearer test');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'inAppEnabled': true,
              'emailEnabled': true,
              'pushEnabled': false,
            }),
            200,
          );
        }

        expect(request.method, 'PUT');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'inAppEnabled': true,
          'emailEnabled': false,
          'pushEnabled': true,
        });
        return http.Response(
          jsonEncode({
            'inAppEnabled': true,
            'emailEnabled': false,
            'pushEnabled': true,
          }),
          200,
        );
      }),
      baseUrl: 'http://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer test'},
    );

    final loaded = await source.getMine();
    final saved = await source.saveMine(
      const NotificationPreferencesModel(
        inAppEnabled: true,
        emailEnabled: false,
        pushEnabled: true,
      ),
    );

    expect(loaded.pushEnabled, isFalse);
    expect(saved.emailEnabled, isFalse);
    expect(saved.pushEnabled, isTrue);
    expect(requestCount, 2);
  });
}
