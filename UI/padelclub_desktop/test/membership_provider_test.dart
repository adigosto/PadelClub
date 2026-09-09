import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/memberships/presentation/providers/membership_provider.dart';

void main() {
  test(
    'uses the owner-scoped paged membership contract and refreshes after lifecycle changes',
    () async {
      final requested = <String>[];
      final membershipQueries = <Map<String, String>>[];
      var cancellationScheduled = false;
      var autoRenew = false;
      final provider = MembershipProvider(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer player-token'},
        client: MockClient((request) async {
          requested.add('${request.method} ${request.url.path}');
          expect(request.headers['Authorization'], 'Bearer player-token');
          if (request.method == 'GET' &&
              request.url.path == '/Memberships/mine') {
            membershipQueries.add(request.url.queryParameters);
            return http.Response(
              jsonEncode({
                'items': [
                  _membership(
                    autoRenew: autoRenew,
                    cancelAtPeriodEnd: cancellationScheduled,
                  ),
                ],
                'totalCount': 1,
              }),
              200,
            );
          }
          if (request.method == 'PUT' &&
              request.url.path == '/Memberships/42/cancel-at-period-end') {
            cancellationScheduled = true;
            autoRenew = false;
            return http.Response('', 204);
          }
          if (request.method == 'PUT' &&
              request.url.path == '/Memberships/42/auto-renew') {
            expect(request.headers['Content-Type'], 'application/json');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body, {'enabled': true});
            autoRenew = true;
            cancellationScheduled = false;
            return http.Response('', 204);
          }
          if (request.method == 'GET' &&
              request.url.path == '/Memberships/42/history') {
            return http.Response(
              jsonEncode([
                {
                  'id': 18,
                  'eventType': 'AutoRenewChanged',
                  'notes': 'Automatic renewal enabled.',
                  'actorUserId': 7,
                  'createdAt': '2026-09-03T12:00:00Z',
                },
              ]),
              200,
            );
          }
          return http.Response('Unexpected request', 404);
        }),
      );

      await provider.load();
      expect(provider.totalCount, 1);
      expect(provider.hasMoreMemberships, isFalse);
      expect(provider.memberships, hasLength(1));
      expect(provider.memberships.single.status, 'Active');
      expect(provider.memberships.single.autoRenew, isFalse);
      expect(provider.memberships.single.cancelAtPeriodEnd, isFalse);
      expect(provider.memberships.single.suspendedAt, isNull);
      expect(provider.memberships.single.cancelledAt, isNull);

      final scheduled = await provider.scheduleCancellation(42);
      expect(scheduled, isTrue);
      expect(provider.memberships.single.cancelAtPeriodEnd, isTrue);
      expect(provider.memberships.single.autoRenew, isFalse);

      final renewed = await provider.updateAutoRenew(
        membershipId: 42,
        enabled: true,
      );
      expect(renewed, isTrue);
      expect(provider.memberships.single.cancelAtPeriodEnd, isFalse);
      expect(provider.memberships.single.autoRenew, isTrue);

      final history = await provider.loadHistory(42);
      expect(history?.single.eventType, 'AutoRenewChanged');
      expect(
        provider.historyFor(42).single.notes,
        'Automatic renewal enabled.',
      );
      expect(provider.errorMessage, isNull);
      expect(requested, [
        'GET /Memberships/mine',
        'PUT /Memberships/42/cancel-at-period-end',
        'GET /Memberships/mine',
        'PUT /Memberships/42/auto-renew',
        'GET /Memberships/mine',
        'GET /Memberships/42/history',
      ]);
      expect(
        membershipQueries,
        everyElement({
          'Page': '1',
          'PageSize': '20',
          'IncludeTotalCount': 'true',
        }),
      );
    },
  );

  test('keeps the server lifecycle error visible to the player', () async {
    final provider = MembershipProvider(
      baseUrl: 'https://padelclub.test',
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response(
            'Only active memberships can change automatic renewal.',
            409,
          );
        }
        return http.Response(jsonEncode({'items': [], 'totalCount': 0}), 200);
      }),
    );

    final changed = await provider.updateAutoRenew(
      membershipId: 42,
      enabled: true,
    );

    expect(changed, isFalse);
    expect(
      provider.errorMessage,
      'Only active memberships can change automatic renewal.',
    );
  });

  test('reports a malformed paged response instead of silently dropping it',
      () async {
    final provider = MembershipProvider(
      baseUrl: 'https://padelclub.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'items': [null],
            'totalCount': 1,
          }),
          200,
        ),
      ),
    );

    await provider.load();

    expect(provider.memberships, isEmpty);
    expect(
      provider.errorMessage,
      'Memberships response contained an invalid membership record.',
    );
  });
}

Map<String, dynamic> _membership({
  required bool autoRenew,
  required bool cancelAtPeriodEnd,
}) => {
  'id': 42,
  'userId': 7,
  'membershipType': 'Club Plus',
  'startDate': '2026-09-01T00:00:00Z',
  'endDate': '2026-10-01T00:00:00Z',
  'price': 49.5,
  'isActive': true,
  'createdAt': '2026-09-01T00:00:00Z',
  'updatedAt': '2026-09-02T00:00:00Z',
  'status': 'Active',
  'autoRenew': autoRenew,
  'cancelAtPeriodEnd': cancelAtPeriodEnd,
  'suspendedAt': null,
  'cancelledAt': null,
};
