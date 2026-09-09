import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/memberships/data/admin_membership_remote_data_source.dart';
import 'package:padelclub_desktop/features/memberships/presentation/providers/membership_management_provider.dart';

void main() {
  test(
    'lists paged admin memberships and refreshes after lifecycle actions',
    () async {
      final requests = <String>[];
      final membershipQueries = <Map<String, String>>[];
      final snapshots = <Map<String, Object?>>[
        {'items': [_membership(status: 'Active')], 'totalCount': 41},
        {'items': [_membership(status: 'Suspended')], 'totalCount': 41},
        {'items': [_membership(status: 'Active')], 'totalCount': 41},
      ];
      final dataSource = AdminMembershipRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer staff-token'},
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          expect(request.headers['Authorization'], 'Bearer staff-token');
          if (request.method == 'GET' && request.url.path == '/Memberships') {
            membershipQueries.add(request.url.queryParameters);
            return http.Response(jsonEncode(snapshots.removeAt(0)), 200);
          }
          if (request.method == 'PUT' &&
              request.url.path == '/Memberships/42/status') {
            expect(request.headers['Content-Type'], 'application/json');
            expect(jsonDecode(request.body), {
              'status': 'Suspended',
              'notes': 'Facility closure.',
            });
            return http.Response('', 204);
          }
          if (request.method == 'POST' &&
              request.url.path == '/Memberships/42/renew') {
            expect(request.headers['Content-Type'], 'application/json');
            expect(jsonDecode(request.body), {'months': 6});
            return http.Response('', 204);
          }
          if (request.method == 'GET' &&
              request.url.path == '/Memberships/42/history') {
            return http.Response(
              jsonEncode([
                {
                  'id': 8,
                  'eventType': 'Renewed',
                  'notes': 'Membership renewed for 6 month(s).',
                  'actorUserId': 1,
                  'createdAt': '2026-09-05T12:00:00Z',
                },
              ]),
              200,
            );
          }
          return http.Response('Unexpected request', 404);
        }),
      );
      final provider = MembershipManagementProvider(dataSource);
      addTearDown(provider.dispose);

      await provider.load(membershipType: 'Club', isActive: true);
      final changed = await provider.changeStatus(
        membershipId: 42,
        status: MembershipLifecycleStatus.suspended,
        notes: 'Facility closure.',
      );
      final renewed = await provider.renewMembership(
        membershipId: 42,
        months: 6,
      );
      final history = await provider.loadHistory(42);

      expect(changed, isTrue);
      expect(renewed, isTrue);
      expect(provider.memberships.single.status, 'Active');
      expect(provider.totalCount, 41);
      expect(provider.canGoNext, isTrue);
      expect(history, hasLength(1));
      expect(history?.single.eventType, 'Renewed');
      expect(
        provider.lastOperationMessage,
        'Membership record renewed for 6 months and refreshed from the server.',
      );
      expect(provider.errorMessage, isNull);
      expect(requests, [
        'GET /Memberships',
        'PUT /Memberships/42/status',
        'GET /Memberships',
        'POST /Memberships/42/renew',
        'GET /Memberships',
        'GET /Memberships/42/history',
      ]);
      expect(
        membershipQueries,
        everyElement({
          'Page': '1',
          'PageSize': '20',
          'IncludeTotalCount': 'true',
          'MembershipType': 'Club',
          'IsActive': 'true',
        }),
      );
    },
  );

  test('keeps local and server lifecycle errors readable for staff', () async {
    var requests = 0;
    final dataSource = AdminMembershipRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test',
      client: MockClient((request) async {
        requests++;
        expect(request.method, 'PUT');
        return http.Response(
          'Only staff with membership access can change this record.',
          403,
        );
      }),
    );
    final provider = MembershipManagementProvider(dataSource);
    addTearDown(provider.dispose);

    final outOfRange = await provider.renewMembership(
      membershipId: 42,
      months: 25,
    );
    expect(outOfRange, isFalse);
    expect(requests, 0);
    expect(
      provider.errorMessage,
      'Choose a renewal period between 1 and 24 months.',
    );

    final denied = await provider.changeStatus(
      membershipId: 42,
      status: MembershipLifecycleStatus.cancelled,
    );
    expect(denied, isFalse);
    expect(requests, 1);
    expect(
      provider.errorMessage,
      'Only staff with membership access can change this record.',
    );
  });
}

Map<String, Object?> _membership({required String status}) => {
  'id': 42,
  'userId': 7,
  'membershipType': 'Club Plus',
  'startDate': '2026-09-01T00:00:00Z',
  'endDate': '2026-10-01T00:00:00Z',
  'price': 49.5,
  'isActive': status == 'Active',
  'createdAt': '2026-09-01T00:00:00Z',
  'updatedAt': '2026-09-02T00:00:00Z',
  'status': status,
  'autoRenew': false,
  'cancelAtPeriodEnd': false,
  'suspendedAt': null,
  'cancelledAt': null,
};
