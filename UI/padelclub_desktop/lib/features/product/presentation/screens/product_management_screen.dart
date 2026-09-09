import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/coupons/presentation/screens/coupon_management_screen.dart';
import 'package:padelclub_desktop/features/inventory_operations/presentation/providers/inventory_operations_provider.dart';
import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/product_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class ProductManagementScreen extends StatelessWidget {
  const ProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InventoryOperationsProvider>(
      create: (_) => InventoryOperationsProvider.live(),
      child: const _ProductManagementContent(),
    );
  }
}

class _ProductManagementContent extends StatefulWidget {
  const _ProductManagementContent();

  @override
  State<_ProductManagementContent> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<_ProductManagementContent> {
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
    final inventoryOperations = context.watch<InventoryOperationsProvider>();
    return MasterScreen(
      title: context.tr("Product Management"),
      section: AppSection.products,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: context.tr("Product Management"),
            subtitle: context.tr(
              "Manage club products, inventory, pricing, and availability.",
            ),
            action: Wrap(
              spacing: PadelSpacing.sm,
              runSpacing: PadelSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CouponManagementScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.local_offer_outlined, size: 18),
                  label: Text(context.tr("Manage coupons")),
                ),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.tr("Add Product")),
                ),
              ],
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
                  children: ["All", "In Stock", "Low Stock", "Unavailable"]
                      .map(
                        (filter) => AdminFilterChip(
                          label: filter == 'All'
                              ? context.tr("All Products")
                              : filter,
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
                      hintText: context.tr("Search products..."),
                      width: 320,
                      onSubmitted: _setQuery,
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _setQuery(_searchController.text),
                      icon: const Icon(Icons.search_rounded, size: 17),
                      label: Text(context.tr("Search")),
                    ),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: Text(context.tr("Refresh")),
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
              child: AdminTableSurface(
                child: _content(products, inventoryOperations),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    List<Product> products,
    InventoryOperationsProvider inventoryOperations,
  ) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return _ProductMessage(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Products are unavailable"),
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    if (products.isEmpty) {
      return _ProductMessage(
        icon: Icons.inventory_2_outlined,
        title: context.tr("No products found"),
        message: context.tr("Adjust the search or inventory filter."),
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
              columns: [
                DataColumn(label: Text(context.tr("PRODUCT"))),
                DataColumn(label: Text(context.tr("CATEGORY"))),
                DataColumn(label: Text(context.tr("PRICE"))),
                DataColumn(label: Text(context.tr("STOCK"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: products
                  .map((product) => _row(product, inventoryOperations))
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(
    Product product,
    InventoryOperationsProvider inventoryOperations,
  ) {
    final unavailable = _unavailable(product);
    final lowStock = !unavailable && product.stockQuantity <= 10;
    final productId = product.id;
    final inventoryBusy =
        inventoryOperations.adjustingProductId != null ||
        inventoryOperations.loadingHistoryProductId != null;
    final isAdjusting =
        productId != null && inventoryOperations.isAdjusting(productId);
    final isLoadingHistory =
        productId != null && inventoryOperations.isLoadingHistory(productId);
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
            '${context.l10n.number(product.price, decimalDigits: 2)} KM',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(
          AdminStatusBadge(
            label: unavailable
                ? context.tr("Unavailable")
                : lowStock
                ? context.tr("{p1} units", {'p1': product.stockQuantity})
                : context.tr("{p1} units", {'p1': product.stockQuantity}),
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
              if (isAdjusting)
                _InventoryActionProgress(
                  label: context.tr("Saving stock adjustment"),
                )
              else
                AdminActionButton(
                  icon: Icons.tune_rounded,
                  tooltip: context.tr("Adjust stock for {p1}", {
                    'p1': product.name,
                  }),
                  onPressed: productId == null || inventoryBusy
                      ? null
                      : () => _adjustStock(product),
                ),
              const SizedBox(width: PadelSpacing.xs),
              if (isLoadingHistory)
                _InventoryActionProgress(
                  label: context.tr("Loading inventory history"),
                )
              else
                AdminActionButton(
                  icon: Icons.history_rounded,
                  tooltip: context.tr("View stock history for {p1}", {
                    'p1': product.name,
                  }),
                  onPressed: productId == null || inventoryBusy
                      ? null
                      : () => _showInventoryHistory(product),
                ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.edit_outlined,
                tooltip: context.tr("Edit product"),
                onPressed: inventoryBusy ? null : () => _showProduct(product),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.delete_outline_rounded,
                tooltip: context.tr("Delete product"),
                onPressed: null,
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
          context.tr("{p1}\n\nPrice: {p2} KM\nStock: {p3}\nState: {p4}", {
            'p1': product.description,
            'p2': context.l10n.number(product.price, decimalDigits: 2),
            'p3': product.stockQuantity,
            'p4': product.productState,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr("Close")),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustStock(Product product) async {
    final productId = product.id;
    if (productId == null) return;
    final quantity = TextEditingController();
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final adjustment = await showDialog<({int quantityChange, String reason})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Adjust stock · {p1}", {'p1': product.name})),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("Current recorded stock: {p1} units.", {
                  'p1': product.stockQuantity,
                }),
              ),
              const SizedBox(height: PadelSpacing.md),
              TextFormField(
                controller: quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'-|[0-9]')),
                ],
                decoration: InputDecoration(
                  labelText: context.tr("Quantity change"),
                  hintText: context.tr("Example: 12 or -3"),
                ),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed == 0) {
                    return context.tr(
                      "Enter a non-zero whole-number adjustment.",
                    );
                  }
                  if (parsed.abs() > 10000) {
                    return context.tr(
                      "Use an adjustment between -10,000 and 10,000.",
                    );
                  }
                  if (product.stockQuantity + parsed < 0) {
                    return context.tr("This would make stock negative.");
                  }
                  return null;
                },
              ),
              const SizedBox(height: PadelSpacing.md),
              TextFormField(
                controller: reason,
                maxLength: 200,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr("Audit reason"),
                  hintText: context.tr("Example: Counted delivery received"),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? context.tr(
                        "Give a reason with at least three characters.",
                      )
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr("Cancel")),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, (
                quantityChange: int.parse(quantity.text.trim()),
                reason: reason.text.trim(),
              ));
            },
            child: Text(context.tr("Save adjustment")),
          ),
        ],
      ),
    );
    quantity.dispose();
    reason.dispose();
    if (adjustment == null || !mounted) return;

    final inventory = context.read<InventoryOperationsProvider>();
    try {
      final history = await inventory.adjustAndRefresh(
        productId: productId,
        quantityChange: adjustment.quantityChange,
        reason: adjustment.reason,
      );
      if (!mounted) return;
      if (history.isNotEmpty) {
        setState(() => product.stockQuantity = history.first.balanceAfter);
      } else {
        await _load();
      }
      if (!mounted) return;
      _notice(
        context.tr(
          "Stock adjusted by {p1}{p2}. The server audit history is up to date.",
          {
            'p1': adjustment.quantityChange > 0 ? '+' : '',
            'p2': adjustment.quantityChange,
          },
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _notice(
        inventory.errorMessage ??
            context.tr("The stock adjustment could not be saved."),
        isError: true,
      );
    }
  }

  Future<void> _showInventoryHistory(Product product) async {
    final productId = product.id;
    if (productId == null) return;
    final inventory = context.read<InventoryOperationsProvider>();
    try {
      final history = await inventory.loadHistory(productId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr("Stock history · {p1}", {'p1': product.name})),
          content: SizedBox(
            width: 620,
            height: 360,
            child: history.isEmpty
                ? Center(
                    child: Text(
                      context.tr("No inventory movements are recorded yet."),
                    ),
                  )
                : ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final movement = history[index];
                      final timestamp = MaterialLocalizations.of(
                        dialogContext,
                      ).formatFullDate(movement.createdAt.toLocal());
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: movement.quantityChange < 0
                              ? PadelColors.dangerSoft
                              : PadelColors.greenSoft,
                          foregroundColor: movement.quantityChange < 0
                              ? PadelColors.danger
                              : PadelColors.greenDark,
                          child: Text(movement.signedQuantityChange),
                        ),
                        title: Text(movement.reason),
                        subtitle: Text(
                          '$timestamp · ${movement.referenceType}',
                        ),
                        trailing: Text(
                          context.tr("Balance\n{p1}", {
                            'p1': movement.balanceAfter,
                          }),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr("Close")),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _notice(
        inventory.errorMessage ??
            context.tr("The inventory history could not be loaded."),
        isError: true,
      );
    }
  }

  void _notice(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? PadelColors.danger : null,
      ),
    );
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
            FilledButton(
              onPressed: onRetry,
              child: Text(context.tr("Try again")),
            ),
          ],
        ],
      ),
    );
  }
}

class _InventoryActionProgress extends StatelessWidget {
  const _InventoryActionProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: const SizedBox(
      width: 44,
      height: 44,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

String _category(String productName) {
  final name = productName.toLowerCase();
  if (name.contains('ball')) return 'Accessories';
  if (name.contains('shoe')) return 'Footwear';
  if (name.contains('bag')) return 'Bags';
  if (name.contains('drink') || name.contains('water')) return 'Beverages';
  return 'Equipment';
}
