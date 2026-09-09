import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/cart_provider.dart';

void main() {
  test('cart quantities respect stock and calculate totals', () {
    final cart = CartProvider();
    final product = Product(
      id: 7,
      name: 'Club balls',
      description: 'Three pack',
      price: 12.5,
      stockQuantity: 2,
      productState: 'ActiveProductState',
    );

    cart.add(product);
    cart.add(product);
    cart.add(product);

    expect(cart.itemCount, 2);
    expect(cart.quantityFor(product), 2);
    expect(cart.total, 25);

    cart.decrement(product);
    expect(cart.itemCount, 1);
    cart.remove(product);
    expect(cart.lines, isEmpty);
  });

  test(
    'checkout sends coupon and recommendation attribution to the live contract',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/Orders/checkout');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['couponCode'], 'WELCOME10');
        expect(body['items'], [
          {
            'productId': 7,
            'quantity': 1,
            'recommendationExposureId': '2a4558f7-35fa-4f10-96c6-4fbc0aaf7f99',
          },
        ]);
        return http.Response(jsonEncode({'orderNumber': 'ORD-42'}), 200);
      });
      final cart = CartProvider(client: client);
      cart.add(
        _product(),
        recommendationExposureId: '2a4558f7-35fa-4f10-96c6-4fbc0aaf7f99',
      );

      final orderNumber = await cart.checkout(
        recipientName: 'Amina Padel',
        phoneNumber: '+38761123456',
        shippingAddress: 'Court Street 1',
        city: 'Sarajevo',
        postalCode: '71000',
        couponCode: ' WELCOME10 ',
      );

      expect(orderNumber, 'ORD-42');
      expect(cart.lines, isEmpty);
      expect(cart.checkoutError, isNull);
    },
  );
}

Product _product() => Product(
  id: 7,
  name: 'Club balls',
  description: 'Three pack',
  price: 12.5,
  stockQuantity: 3,
  productState: 'active',
);
