import 'package:flutter_test/flutter_test.dart';

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
}
