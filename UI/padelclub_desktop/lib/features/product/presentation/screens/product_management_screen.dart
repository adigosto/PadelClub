import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/product_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final _searchController = TextEditingController();
  List<Product> _products = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await context.read<ProductProvider>().get(
        filter: {'Page': 1, 'PageSize': 200, 'IncludeTotalCount': true},
      );
      if (!mounted) return;
      setState(() {
        _products = result.items ?? const [];
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

  @override
  Widget build(BuildContext context) {
    final products = _filtered();
    return MasterScreen(
      title: 'Product Management',
      section: AppSection.products,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Product Management',
            subtitle:
                'Manage club products, inventory, pricing, and availability.',
            action: FilledButton.icon(
              onPressed: () =>
                  _notice('Product creation will use the inventory form.'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Product'),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(PadelSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: PadelSpacing.xs,
                  runSpacing: PadelSpacing.xs,
                  children: ['All', 'In Stock', 'Low Stock', 'Unavailable']
                      .map(
                        (filter) => AdminFilterChip(
                          label: filter == 'All' ? 'All Products' : filter,
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: PadelSpacing.md),
                Wrap(
                  spacing: PadelSpacing.sm,
                  runSpacing: PadelSpacing.sm,
                  children: [
                    AdminSearchField(
                      controller: _searchController,
                      hintText: 'Search products...',
                      width: 320,
                      onSubmitted: _setQuery,
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _setQuery(_searchController.text),
                      icon: const Icon(Icons.search_rounded, size: 17),
                      label: const Text('Search'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PadelSpacing.lg,
                0,
                PadelSpacing.lg,
                PadelSpacing.lg,
              ),
              child: AdminTableSurface(child: _content(products)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<Product> products) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return _ProductMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Products are unavailable',
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    if (products.isEmpty) {
      return const _ProductMessage(
        icon: Icons.inventory_2_outlined,
        title: 'No products found',
        message: 'Adjust the search or inventory filter.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(PadelColors.canvas),
              dataRowMinHeight: 70,
              dataRowMaxHeight: 80,
              columnSpacing: 34,
              columns: const [
                DataColumn(label: Text('PRODUCT')),
                DataColumn(label: Text('CATEGORY')),
                DataColumn(label: Text('PRICE')),
                DataColumn(label: Text('STOCK')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: products.map(_row).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(Product product) {
    final unavailable = _unavailable(product);
    final lowStock = !unavailable && product.stockQuantity <= 10;
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(PadelRadii.small),
                child: Container(
                  width: 42,
                  height: 42,
                  color: PadelColors.blueSoft,
                  child: _ProductThumbnail(url: product.imageUrl),
                ),
              ),
              const SizedBox(width: PadelSpacing.sm),
              SizedBox(
                width: 300,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PadelColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          AdminStatusBadge(
            label: _category(product.name),
            tone: AdminStatusTone.info,
          ),
        ),
        DataCell(
          Text(
            '${product.price.toStringAsFixed(2)} KM',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(
          AdminStatusBadge(
            label: unavailable
                ? 'Unavailable'
                : lowStock
                ? '${product.stockQuantity} units'
                : '${product.stockQuantity} units',
            tone: unavailable
                ? AdminStatusTone.danger
                : lowStock
                ? AdminStatusTone.warning
                : AdminStatusTone.success,
            showDot: true,
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit product',
                onPressed: () => _showProduct(product),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete product',
                onPressed: () => _notice(
                  'Product deletion will be connected after inventory confirmation is added.',
                ),
                destructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Product> _filtered() {
    return _products
        .where((product) {
          final unavailable = _unavailable(product);
          final matchesFilter = switch (_filter) {
            'In Stock' => !unavailable && product.stockQuantity > 10,
            'Low Stock' => !unavailable && product.stockQuantity <= 10,
            'Unavailable' => unavailable,
            _ => true,
          };
          final haystack =
              '${product.name} ${product.description} '
                      '${product.productState} ${_category(product.name)}'
                  .toLowerCase();
          return matchesFilter && (_query.isEmpty || haystack.contains(_query));
        })
        .toList(growable: false);
  }

  bool _unavailable(Product product) {
    return product.stockQuantity <= 0 ||
        product.productState.toLowerCase().contains('deactiv');
  }

  void _setQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  void _showProduct(Product product) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Text(
          '${product.description}\n\nPrice: ${product.price.toStringAsFixed(2)} KM\n'
          'Stock: ${product.stockQuantity}\nState: ${product.productState}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final source = url?.trim() ?? '';
    if (source.isEmpty) {
      return const Icon(Icons.sports_tennis_rounded, color: PadelColors.blue);
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.sports_tennis_rounded, color: PadelColors.blue),
    );
  }
}

class _ProductMessage extends StatelessWidget {
  const _ProductMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: PadelColors.blue),
          const SizedBox(height: PadelSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: PadelSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          if (onRetry != null) ...[
            const SizedBox(height: PadelSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

String _category(String productName) {
  final name = productName.toLowerCase();
  if (name.contains('ball')) return 'Accessories';
  if (name.contains('shoe')) return 'Footwear';
  if (name.contains('bag')) return 'Bags';
  if (name.contains('drink') || name.contains('water')) return 'Beverages';
  return 'Equipment';
}
