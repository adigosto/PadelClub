import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/product_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

import 'product_details_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();
  List<Product> _products = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _page = 1;
  static const _pageSize = 12;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProducts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = _searchController.text.trim();
      final result = await context.read<ProductProvider>().get(
        filter: {
          if (query.isNotEmpty) 'Name': query,
          'Page': _page,
          'PageSize': _pageSize,
        },
      );
      if (!mounted) return;
      setState(() {
        _products = result.items ?? const [];
        _totalCount = result.totalCount ?? _products.length;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _search() {
    _page = 1;
    _loadProducts();
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: 'Shop',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          return Padding(
            padding: EdgeInsets.all(isWide ? 28 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Club shop',
                  style: TextStyle(
                    color: Color(0xFF27423A),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Everything you need for your next match.',
                  style: TextStyle(color: Color(0xFF5C6B64), fontSize: 15),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Search rackets, balls, apparel…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildContent(isWide)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Products are unavailable',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onAction: _loadProducts,
      );
    }
    if (_products.isEmpty) {
      return _MessageState(
        icon: Icons.inventory_2_outlined,
        title: 'No products found',
        message: 'Try another search or clear the current one.',
        actionLabel: 'Clear search',
        onAction: () {
          _searchController.clear();
          _search();
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            itemCount: _products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 0.92 : 0.72,
            ),
            itemBuilder: (_, index) => _ProductCard(
              product: _products[index],
              onTap: () => _openProduct(_products[index]),
            ),
          ),
        ),
        if (_totalCount > _pageSize)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _page > 1
                      ? () {
                          _page--;
                          _loadProducts();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('Page $_page of ${(_totalCount / _pageSize).ceil()}'),
                IconButton(
                  onPressed: _page * _pageSize < _totalCount
                      ? () {
                          _page++;
                          _loadProducts();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available =
        product.stockQuantity > 0 &&
        !product.productState.toLowerCase().contains('deactivated');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFE8F4EF),
                child: _ProductImage(url: product.imageUrl, iconSize: 54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF27423A),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${product.price.toStringAsFixed(2)} KM',
                          style: const TextStyle(
                            color: Color(0xFF1F7A63),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: available
                              ? const Color(0xFFE8F4EF)
                              : const Color(0xFFFFECE8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          available ? 'In stock' : 'Unavailable',
                          style: TextStyle(
                            color: available
                                ? const Color(0xFF1F7A63)
                                : const Color(0xFFC95C4C),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, required this.iconSize});

  final String? url;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final source = url?.trim() ?? '';
    if (source.isEmpty) {
      return Icon(
        Icons.sports_tennis_rounded,
        size: iconSize,
        color: const Color(0xFF1F7A63),
      );
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Icon(
        Icons.sports_tennis_rounded,
        size: iconSize,
        color: const Color(0xFF1F7A63),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF1F7A63)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5C6B64)),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
