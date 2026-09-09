import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/inventory_operations/data/datasources/inventory_operations_remote_data_source.dart';
import 'package:padelclub_desktop/features/inventory_operations/data/repositories/inventory_operations_repository_impl.dart';
import 'package:padelclub_desktop/features/inventory_operations/domain/usecases/adjust_inventory.dart';
import 'package:padelclub_desktop/features/inventory_operations/domain/usecases/get_inventory_history.dart';
import 'package:padelclub_desktop/features/inventory_operations/presentation/providers/inventory_operations_provider.dart';

void main() {
  test('adjusts stock through the admin contract then displays server audit history', () async {
    final requested = <String>[];
    final remote = InventoryOperationsRemoteDataSourceImpl(
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer administrator'},
      client: MockClient((request) async {
        requested.add('${request.method} ${request.url.path}');
        expect(request.headers['Authorization'], 'Bearer administrator');
        if (request.method == 'POST') {
          expect(request.url.path, '/Commerce/inventory/9/adjust');
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {
            'quantityChange': 4,
            'reason': 'Counted delivery received',
          });
          return http.Response('', 204);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/Commerce/inventory/9/history');
        return http.Response(jsonEncode([
          {
            'id': 41,
            'quantityChange': 4,
            'balanceAfter': 19,
            'reason': 'Counted delivery received',
            'referenceType': 'Adjustment',
            'referenceId': null,
            'actorUserId': 1,
            'createdAt': '2026-09-03T12:00:00Z',
          },
        ]), 200);
      }),
    );
    final repository = InventoryOperationsRepositoryImpl(remote);
    final provider = InventoryOperationsProvider(
      AdjustInventory(repository),
      GetInventoryHistory(repository),
    );

    final history = await provider.adjustAndRefresh(
      productId: 9,
      quantityChange: 4,
      reason: 'Counted delivery received',
    );

    expect(requested, [
      'POST /Commerce/inventory/9/adjust',
      'GET /Commerce/inventory/9/history',
    ]);
    expect(history.single.balanceAfter, 19);
    expect(provider.historyFor(9).single.signedQuantityChange, '+4');
    expect(provider.errorMessage, isNull);
  });
}
