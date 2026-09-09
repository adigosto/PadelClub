import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/network/api_error.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/validation/form_validators.dart';
import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/cart_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/widgets/checkout_sheet.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

void main() {
  test('names and addresses accept Bosnian letters in both cases', () {
    for (final value in [
      'Šaćir Čengić',
      'Đačka ulica 12',
      'Čapljina',
      'č ć š ž đ Č Ć Š Ž Đ',
    ]) {
      expect(
        FormValidators.text(value, label: 'text', minLength: 2, maxLength: 150),
        isNull,
      );
    }
    expect(
      FormValidators.text('A', label: 'City', minLength: 2, maxLength: 100),
      'City must contain at least 2 characters.',
    );
    expect(
      FormValidators.text('12345', label: 'Postal code', maxLength: 4),
      'Postal code must contain no more than 4 characters.',
    );
    expect(FormValidators.phone('+387 61 123 456'), isNull);
    expect(FormValidators.phone('abcdef'), isNotNull);
    expect(FormValidators.email('not-an-email'), isNotNull);
    expect(FormValidators.decimal('25,50', label: 'price'), isNull);
    expect(FormValidators.decimal('NaN', label: 'price'), isNotNull);
    expect(FormValidators.decimal('-10', label: 'price'), isNotNull);
  });

  test('server field errors are readable without JSON or generic titles', () {
    expect(
      apiErrorMessage(
        jsonEncode({
          'title': 'One or more validation errors occurred.',
          'errors': {
            'City': ['Enter the city.'],
            'PostalCode': ['Enter the postal code.'],
          },
          'traceId': 'internal-id',
        }),
      ),
      'Enter the city.\nEnter the postal code.',
    );
    expect(apiErrorMessage('"Coupon has expired."'), 'Coupon has expired.');
    expect(
      apiErrorMessage('<html>server failure</html>'),
      'Could not save changes. Please try again.',
    );
  });

  testWidgets(
    'checkout marks every missing field and clears corrected errors',
    (tester) async {
      var requests = 0;
      final cart = CartProvider(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
      await _pumpCheckout(tester, cart);
      await tester.enterText(_field('Recipient name *'), '');
      await tester.ensureVisible(find.text('Place order'));
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      for (final message in [
        'Enter recipient name.',
        'Enter a phone number.',
        'Enter street address.',
        'Enter city.',
        'Enter postal code.',
      ]) {
        expect(find.text(message), findsOneWidget);
      }
      expect(requests, 0);
      await tester.ensureVisible(_field('Recipient name *'));
      await tester.enterText(_field('Recipient name *'), 'Šaćir Čengić');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bosnian-character-š')));
      expect(
        tester
            .widget<TextFormField>(_field('Recipient name *'))
            .controller!
            .text,
        'Šaćir Čengićš',
      );
      expect(find.text('Enter recipient name.'), findsNothing);
      expect(find.text('Enter a phone number.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Bosnian delivery details survive UTF-8 checkout and server errors stay visible',
    (tester) async {
      Map<String, dynamic>? sent;
      final cart = CartProvider(
        client: MockClient((request) async {
          sent =
              jsonDecode(utf8.decode(request.bodyBytes))
                  as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'errors': {
                'CouponCode': ['Coupon has expired.'],
              },
            }),
            400,
          );
        }),
      );
      await _pumpCheckout(tester, cart);
      final values = {
        'Recipient name *': 'Šaćir Čengić',
        'Phone number *': '+387 61 123 456',
        'Street address *': 'Ulica Žrtava fašizma 12, Đačka zgrada',
        'City *': 'Čapljina',
        'Postal code *': '88300',
        'Delivery notes (optional)': 'Sačuvajte račun: č ć š ž đ Č Ć Š Ž Đ.',
      };
      for (final entry in values.entries) {
        await tester.ensureVisible(_field(entry.key));
        await tester.enterText(_field(entry.key), entry.value);
      }
      await tester.ensureVisible(find.text('Place order'));
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(sent?['recipientName'], values['Recipient name *']);
      expect(sent?['shippingAddress'], values['Street address *']);
      expect(sent?['city'], values['City *']);
      expect(sent?['notes'], values['Delivery notes (optional)']);
      expect(find.text('Coupon has expired.'), findsOneWidget);
      expect(cart.lines, hasLength(1));
      expect(
        tester
            .widget<TextFormField>(_field('Recipient name *'))
            .controller!
            .text,
        'Šaćir Čengić',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _pumpCheckout(WidgetTester tester, CartProvider cart) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  cart.add(
    Product(
      id: 7,
      name: 'Club balls',
      description: 'Three pack',
      price: 12.5,
      stockQuantity: 3,
      productState: 'active',
    ),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: cart),
      ],
      child: MaterialApp(
        theme: PadelTheme.light,
        home: const Scaffold(body: CheckoutSheet()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
