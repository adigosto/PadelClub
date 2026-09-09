import 'package:flutter_test/flutter_test.dart';
import 'package:padelclub_desktop/features/operations/presentation/providers/operations_analytics_provider.dart';

void main() {
  test('maps live operations analytics values from the API response', () {
    final analytics = OperationsAnalytics.fromJson(const {
      'orders': 12,
      'orderRevenue': 684.5,
      'reservations': 18,
      'cancelledReservations': 2,
      'activeMemberships': 248,
      'lowStockProducts': 3,
    });

    expect(analytics.orders, 12);
    expect(analytics.orderRevenue, 684.5);
    expect(analytics.reservations, 18);
    expect(analytics.cancelledReservations, 2);
    expect(analytics.activeMemberships, 248);
    expect(analytics.lowStockProducts, 3);
  });
}
