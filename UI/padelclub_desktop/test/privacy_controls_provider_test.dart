import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/privacy/data/datasources/privacy_remote_data_source.dart';
import 'package:padelclub_desktop/features/privacy/data/repositories/privacy_repository_impl.dart';
import 'package:padelclub_desktop/features/privacy/domain/usecases/cancel_account_deletion.dart';
import 'package:padelclub_desktop/features/privacy/domain/usecases/get_account_deletion_status.dart';
import 'package:padelclub_desktop/features/privacy/domain/usecases/get_privacy_export.dart';
import 'package:padelclub_desktop/features/privacy/domain/usecases/request_account_deletion.dart';
import 'package:padelclub_desktop/features/privacy/presentation/providers/privacy_controls_provider.dart';

void main() {
  test('keeps the privacy export transient and follows deletion lifecycle endpoints', () async {
    final requested = <String>[];
    final remote = PrivacyRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer player-token'},
      client: MockClient((request) async {
        requested.add('${request.method} ${request.url.path}');
        expect(request.headers['Authorization'], 'Bearer player-token');
        if (request.method == 'GET' && request.url.path == '/Privacy/deletion') {
          return http.Response('', 204);
        }
        if (request.method == 'GET' && request.url.path == '/Privacy/export') {
          return http.Response(jsonEncode({
            'exportedAt': '2026-09-03T12:00:00Z',
            'user': {'id': 7, 'email': 'player@example.test'},
            'orders': [],
          }), 200);
        }
        if (request.method == 'POST' && request.url.path == '/Privacy/deletion') {
          return http.Response(jsonEncode({
            'id': 12,
            'status': 'Scheduled',
            'requestedAt': '2026-09-03T12:00:00Z',
            'scheduledFor': '2026-10-03T12:00:00Z',
          }), 200);
        }
        if (request.method == 'DELETE' && request.url.path == '/Privacy/deletion') {
          return http.Response('', 204);
        }
        return http.Response('Unexpected request', 404);
      }),
    );
    final repository = PrivacyRepositoryImpl(remote);
    final provider = PrivacyControlsProvider(
      GetAccountDeletionStatus(repository),
      RequestAccountDeletion(repository),
      CancelAccountDeletion(repository),
      GetPrivacyExport(repository),
    );

    await provider.loadDeletionStatus();
    final export = await provider.viewExport();
    final scheduled = await provider.requestDeletion();
    final cancelled = await provider.cancelDeletion();

    expect(provider.deletionStatus?.isCancelled, isTrue);
    expect(export?['user'], isA<Map<String, dynamic>>());
    expect(scheduled, isTrue);
    expect(cancelled, isTrue);
    expect(requested, [
      'GET /Privacy/deletion',
      'GET /Privacy/export',
      'POST /Privacy/deletion',
      'DELETE /Privacy/deletion',
    ]);
  });
}
