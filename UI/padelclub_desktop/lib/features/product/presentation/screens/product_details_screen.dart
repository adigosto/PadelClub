import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/cart_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final available =
        product.stockQuantity > 0 &&
        !product.productState.toLowerCase().contains('deactivated');
    return MasterScreen(
      title: 'Product details',
      section: AppSection.products,
      showBackButton: true,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Scrollbar(
            thumbVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: constraints.maxWidth > 600 ? 2 : 1.15,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            color: const Color(0xFFE8F4EF),
                            child: _DetailImage(url: product.imageUrl),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: Color(0xFF27423A),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${product.price.toStringAsFixed(2)} KM',
                        style: const TextStyle(
                          color: Color(0xFF1F7A63),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        product.description,
                        style: const TextStyle(
                          color: Color(0xFF5C6B64),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDDE5DC)),
                        ),
                        child: Column(
                          children: [
                            _DetailRow(
                              label: 'Availability',
                              value: available ? 'In stock' : 'Unavailable',
                            ),
                            const Divider(height: 24),
                            _DetailRow(
                              label: 'Quantity',
                              value: '${product.stockQuantity}',
                            ),
                            const Divider(height: 24),
                            _DetailRow(
                              label: 'Status',
                              value: _friendlyState(product.productState),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: available
                            ? () {
                                context.read<CartProvider>().add(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${product.name} added to cart.',
                                    ),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: Text(available ? 'Add to cart' : 'Unavailable'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyState(String value) => value
      .replaceAll('ProductState', '')
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
      .trim();
}

class _DetailImage extends StatelessWidget {
  const _DetailImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final source = url?.trim() ?? '';
    if (source.isEmpty) {
      return const Icon(
        Icons.sports_tennis_rounded,
        size: 96,
        color: Color(0xFF1F7A63),
      );
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(
        Icons.sports_tennis_rounded,
        size: 96,
        color: Color(0xFF1F7A63),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF5C6B64))),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF27423A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
