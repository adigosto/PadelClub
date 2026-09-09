import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/returns/data/datasources/return_requests_remote_data_source.dart';
import 'package:padelclub_desktop/features/returns/data/repositories/return_requests_repository_impl.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/create_return_request.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_eligible_return_orders.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_my_return_requests.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/get_return_requests.dart';
import 'package:padelclub_desktop/features/returns/domain/usecases/resolve_return_request.dart';
import 'package:padelclub_desktop/features/returns/presentation/providers/return_requests_provider.dart';

void main() {
  test(
    'uses the return eligibility, request, status, and staff resolution contracts',
    () async {
      var eligibleReads = 0;
      var myReturnReads = 0;
      var allReturnReads = 0;
      final remote = ReturnRequestsRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer test-token'},
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          if (request.method == 'GET' &&
              request.url.path ==
                  '/Commerce/returns/eligible-orders/mine') {
            eligibleReads++;
            return http.Response(jsonEncode(_eligibleOrders()), 200);
          }
          if (request.method == 'GET' &&
              request.url.path == '/Commerce/returns/mine') {
            myReturnReads++;
            return http.Response(jsonEncode(_myReturns()), 200);
          }
          if (request.method == 'POST' &&
              request.url.path == '/Commerce/returns') {
            expect(request.headers['Content-Type'], 'application/json');
            expect(jsonDecode(request.body), {
              'orderId': 41,
              'reason': 'The grip arrived damaged.',
              'items': [
                {'orderItemId': 93, 'quantity': 1},
              ],
            });
            return http.Response(
              jsonEncode({'id': 17, 'status': 'Requested', 'refundAmount': 54.5}),
              200,
            );
          }
          if (request.method == 'GET' &&
              request.url.path == '/Commerce/returns') {
            allReturnReads++;
            expect(request.url.queryParameters['status'], 'Requested');
            return http.Response(jsonEncode(_adminReturns()), 200);
          }
          if (request.method == 'PUT' &&
              request.url.path == '/Commerce/returns/17/resolve') {
            expect(request.headers['Content-Type'], 'application/json');
            expect(jsonDecode(request.body), {
              'approve': false,
              'adminNotes': 'The submitted photos do not show a defect.',
            });
            return http.Response('', 204);
          }
          return http.Response('Unexpected request', 404);
        }),
      );
      final repository = ReturnRequestsRepositoryImpl(remote);
      final provider = ReturnRequestsProvider(
        GetEligibleReturnOrders(repository),
        CreateReturnRequest(repository),
        GetMyReturnRequests(repository),
        GetReturnRequests(repository),
        ResolveReturnRequest(repository),
      );

      await provider.loadCustomerData();
      final submission = await provider.submit(
        orderId: 41,
        reason: 'The grip arrived damaged.',
        items: const [ReturnRequestLine(orderItemId: 93, quantity: 1)],
      );
      await provider.loadAdmin(status: 'Requested');
      final resolved = await provider.resolve(
        returnRequestId: 17,
        approve: false,
        adminNotes: 'The submitted photos do not show a defect.',
      );

      expect(submission?.id, 17);
      expect(submission?.refundAmount, 54.5);
      expect(provider.eligibleOrders.single.orderNumber, 'PC-0041');
      expect(provider.eligibleOrders.single.items.single.remainingReturnableQuantity, 1);
      expect(provider.myReturns.single.status, 'Requested');
      expect(provider.adminReturns.single.userId, 8);
      expect(resolved, isTrue);
      expect(eligibleReads, 2);
      expect(myReturnReads, 2);
      expect(allReturnReads, 2);
      expect(provider.customerErrorMessage, isNull);
      expect(provider.adminErrorMessage, isNull);
    },
  );
}

List<Map<String, Object?>> _eligibleOrders() => [
  {
    'orderId': 41,
    'orderNumber': 'PC-0041',
    'deliveredAt': '2026-08-10T10:00:00Z',
    'returnWindowEndsAt': '2026-09-09T10:00:00Z',
    'items': [
      {
        'orderItemId': 93,
        'productName': 'Padel racket grip',
        'quantity': 2,
        'remainingReturnableQuantity': 1,
        'unitPrice': 54.5,
        'lineTotal': 109.0,
      },
    ],
  },
];

List<Map<String, Object?>> _myReturns() => [
  {
    'id': 17,
    'orderId': 41,
    'reason': 'The grip arrived damaged.',
    'status': 'Requested',
    'refundAmount': 54.5,
    'adminNotes': null,
    'createdAt': '2026-09-03T12:00:00Z',
    'resolvedAt': null,
  },
];

List<Map<String, Object?>> _adminReturns() => [
  {
    'id': 17,
    'orderId': 41,
    'userId': 8,
    'reason': 'The grip arrived damaged.',
    'status': 'Requested',
    'refundAmount': 54.5,
    'adminNotes': null,
    'createdAt': '2026-09-03T12:00:00Z',
    'resolvedAt': null,
  },
];
