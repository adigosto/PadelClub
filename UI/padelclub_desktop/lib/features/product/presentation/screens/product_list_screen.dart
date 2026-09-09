import 'dart:async';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
import 'package:padelclub_desktop/features/orders/presentation/providers/order_provider.dart';
import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/cart_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/product_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/widgets/checkout_sheet.dart';
import 'package:padelclub_desktop/features/recommendations/domain/entities/product_recommendation.dart';
import 'package:padelclub_desktop/features/recommendations/presentation/providers/product_recommendation_provider.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_eligible_order.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';
import 'package:padelclub_desktop/features/returns/presentation/providers/return_requests_provider.dart';
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
  String _category = 'All';
  int _selectedTab = 0;

  static const _categories = {
    'All': '',
    'Rackets': 'Racket',
    'Balls': 'Balls',
    'Footwear': 'Shoes',
    'Apparel': 'Shirt',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProducts();
      context.read<ProductRecommendationProvider>().load();
    });
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
      final typedQuery = _searchController.text.trim();
      final query = typedQuery.isNotEmpty
          ? typedQuery
          : _categories[_category] ?? '';
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

  void _openProduct(Product product, {String? recommendationExposureId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          product: product,
          recommendationExposureId: recommendationExposureId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: context.tr("Shop"),
      section: AppSection.products,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          return Scrollbar(
            thumbVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isWide ? 28 : 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr("Club shop"),
                          style: TextStyle(
                            color: Color(0xFF27423A),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _CartButton(onPressed: () => _showCart(context)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr("Everything you need for your next match."),
                    style: TextStyle(color: Color(0xFF5C6B64), fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.storefront_outlined),
                          label: Text(context.tr("Products")),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.receipt_long_outlined),
                          label: Text(context.tr("My orders")),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (selection) {
                        final value = selection.first;
                        setState(() => _selectedTab = value);
                        if (value == 1) {
                          context.read<OrderProvider>().loadMine();
                          context
                              .read<ReturnRequestsProvider>()
                              .loadCustomerData();
                        }
                      },
                    ),
                  ),
                  if (_selectedTab == 0) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        hintText: context.tr("Search rackets, balls, apparel…"),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: context.tr("Search"),
                          onPressed: _search,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _categories.keys
                            .map(
                              (category) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(context.tr(category)),
                                  selected: _category == category,
                                  onSelected: (_) {
                                    _searchController.clear();
                                    setState(() {
                                      _category = category;
                                      _page = 1;
                                    });
                                    _loadProducts();
                                  },
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _PromoBanner(),
                    const SizedBox(height: 16),
                    _RecommendationStrip(
                      onOpen: _openRecommendedProduct,
                      onAdd: _addRecommendedToCart,
                    ),
                    const SizedBox(height: 16),
                    _buildContent(isWide),
                  ] else ...[
                    const SizedBox(height: 18),
                    const _MyOrdersView(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Products are unavailable"),
        message: _errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: _loadProducts,
      );
    }
    if (_products.isEmpty) {
      return _MessageState(
        icon: Icons.inventory_2_outlined,
        title: context.tr("No products found"),
        message: context.tr("Try another search or clear the current one."),
        actionLabel: context.tr("Clear search"),
        onAction: () {
          _searchController.clear();
          _search();
        },
      );
    }

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
            onAdd: () => _addToCart(_products[index]),
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
                Text(
                  context.tr("Page {p1} of {p2}", {
                    'p1': _page,
                    'p2': (_totalCount / _pageSize).ceil(),
                  }),
                ),
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

  void _addToCart(Product product, {String? recommendationExposureId}) {
    context.read<CartProvider>().add(
      product,
      recommendationExposureId: recommendationExposureId,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr("{p1} added to cart.", {'p1': product.name})),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openRecommendedProduct(
    ProductRecommendation recommendation,
  ) async {
    await context.read<ProductRecommendationProvider>().recordClick(
      recommendation.exposureId,
    );
    if (!mounted) return;
    _openProduct(
      recommendation.product,
      recommendationExposureId: recommendation.exposureId,
    );
  }

  void _addRecommendedToCart(ProductRecommendation recommendation) {
    unawaited(
      context.read<ProductRecommendationProvider>().recordClick(
        recommendation.exposureId,
      ),
    );
    _addToCart(
      recommendation.product,
      recommendationExposureId: recommendation.exposureId,
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _CartSheet(),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().itemCount;
    return Semantics(
      button: true,
      label: count == 0
          ? context.tr("Open cart, empty")
          : context.tr("Open cart, {p1} items", {'p1': count}),
      child: ExcludeSemantics(
        child: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: IconButton.filledTonal(
            tooltip: context.tr("Open cart"),
            onPressed: onPressed,
            icon: const Icon(Icons.shopping_cart_rounded),
          ),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1F7A63), Color(0xFF2E6BD7)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("Match-day essentials"),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                context.tr("Club gear ready for your next court."),
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(Icons.sports_tennis_rounded, color: Colors.white, size: 35),
      ],
    ),
  );
}

class _RecommendationStrip extends StatelessWidget {
  const _RecommendationStrip({required this.onOpen, required this.onAdd});

  final ValueChanged<ProductRecommendation> onOpen;
  final ValueChanged<ProductRecommendation> onAdd;

  @override
  Widget build(BuildContext context) {
    final recommendations = context.watch<ProductRecommendationProvider>();
    if (recommendations.isLoading && recommendations.items.isEmpty) {
      return const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(99)),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }
    if (recommendations.items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF1F7A63)),
            SizedBox(width: 8),
            Text(
              context.tr("Recommended for you"),
              style: TextStyle(
                color: Color(0xFF27423A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.tr("Personalized from completed shop purchases."),
          style: TextStyle(color: Color(0xFF5C6B64), fontSize: 13),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final recommendation = recommendations.items[index];
              return _RecommendationCard(
                recommendation: recommendation,
                onOpen: () => onOpen(recommendation),
                onAdd: () => onAdd(recommendation),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.onOpen,
    required this.onAdd,
  });

  final ProductRecommendation recommendation;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final product = recommendation.product;
    final available =
        product.stockQuantity > 0 &&
        !product.productState.toLowerCase().contains('deactivated');
    final label = switch (recommendation.strategy) {
      'new-arrivals-fallback' => context.tr("New in the club shop"),
      'popular-fallback' => context.tr("Popular in the club shop"),
      _ when recommendation.isFallback => context.tr(
        "Popular in the club shop",
      ),
      _ => context.tr("Based on similar purchases"),
    };

    return SizedBox(
      width: 226,
      child: Semantics(
        button: true,
        label: '${product.name}. $label. ${recommendation.reason}',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4EF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _ProductImage(
                          url: product.imageUrl,
                          iconSize: 25,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF27423A),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: recommendation.isFallback
                          ? const Color(0xFFFFF3D6)
                          : const Color(0xFFE8F4EF),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF27423A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      recommendation.reason,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5C6B64),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${context.l10n.number(product.price, decimalDigits: 2)} KM',
                          style: const TextStyle(
                            color: Color(0xFF1F7A63),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: available
                            ? context.tr("Add to cart")
                            : context.tr("Unavailable"),
                        onPressed: available ? onAdd : null,
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartSheet extends StatelessWidget {
  const _CartSheet();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr("Your cart"),
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (cart.lines.isNotEmpty)
                    TextButton(
                      onPressed: cart.clear,
                      child: Text(context.tr("Clear")),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (cart.lines.isEmpty)
                Expanded(
                  child: Center(child: Text(context.tr("Your cart is empty."))),
                )
              else
                Flexible(
                  child: ListView.separated(
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final line = cart.lines[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          line.product.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${context.l10n.number(line.total, decimalDigits: 2)} KM',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: context.tr("Remove one {p1}", {
                                'p1': line.product.name,
                              }),
                              onPressed: () => cart.decrement(line.product),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                              ),
                            ),
                            Semantics(
                              label: context.tr("Quantity {p1}", {
                                'p1': line.quantity,
                              }),
                              child: Text(
                                '${line.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: context.tr("Add one {p1}", {
                                'p1': line.product.name,
                              }),
                              onPressed:
                                  line.quantity < line.product.stockQuantity
                                  ? () => cart.add(line.product)
                                  : null,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (cart.lines.isNotEmpty) ...[
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr("Total"),
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${context.l10n.number(cart.total, decimalDigits: 2)} KM',
                      style: const TextStyle(
                        color: Color(0xFF1F7A63),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showCheckout(context),
                    icon: const Icon(Icons.lock_outline_rounded),
                    label: Text(context.tr("Proceed to checkout")),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCheckout(BuildContext context) async {
  final orderNumber = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => const CheckoutSheet(),
  );
  if (orderNumber != null && context.mounted) {
    Navigator.pop(context);
    context.read<OrderProvider>().loadMine();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF1F7A63)),
        title: Text(context.tr("Order placed")),
        content: Text(
          context.tr("Order {p1} was submitted successfully.", {
            'p1': orderNumber,
          }),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr("Done")),
          ),
        ],
      ),
    );
  }
}

class _MyOrdersView extends StatelessWidget {
  const _MyOrdersView();

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MyReturnsWorkspace(),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr("Order history"),
                style: TextStyle(
                  color: Color(0xFF27423A),
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ),
            IconButton(
              tooltip: context.tr("Refresh orders"),
              onPressed: orders.isLoading ? null : orders.loadMine,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (orders.isLoading && orders.orders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (orders.errorMessage != null && orders.orders.isEmpty)
          _MessageState(
            icon: Icons.cloud_off_rounded,
            title: context.tr("Orders are unavailable"),
            message: orders.errorMessage!,
            actionLabel: context.tr("Try again"),
            onAction: orders.loadMine,
          )
        else if (orders.orders.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: Color(0xFF1F7A63),
                ),
                SizedBox(height: 14),
                Text(
                  context.tr("No orders yet"),
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(context.tr("Completed checkouts will appear here.")),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _OrderCard(order: orders.orders[index]),
          ),
      ],
    );
  }
}

class _MyReturnsWorkspace extends StatelessWidget {
  const _MyReturnsWorkspace();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReturnRequestsProvider>();
    final isLoading =
        provider.isLoadingCustomerData &&
        provider.eligibleOrders.isEmpty &&
        provider.myReturns.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E8DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_return_outlined,
                color: Color(0xFF1F7A63),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr("Returns"),
                  style: TextStyle(
                    color: Color(0xFF27423A),
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr("Refresh returns"),
                onPressed: provider.isLoadingCustomerData
                    ? null
                    : provider.loadCustomerData,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              "Select eligible delivered items and track the status of each request.",
            ),
            style: TextStyle(color: Color(0xFF5C6B64)),
          ),
          if (isLoading) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ] else ...[
            if (provider.customerErrorMessage != null) ...[
              const SizedBox(height: 14),
              _ReturnNotice(
                icon: Icons.info_outline_rounded,
                message: provider.customerErrorMessage!,
                actionLabel: context.tr("Retry"),
                onAction: provider.loadCustomerData,
              ),
            ],
            const SizedBox(height: 18),
            Text(
              context.tr("Eligible items"),
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (provider.eligibleOrders.isEmpty)
              _ReturnNotice(
                icon: Icons.inventory_2_outlined,
                message: context.tr(
                  "There are no returnable delivered items right now. Eligibility is checked by PadelClub.",
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.eligibleOrders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _ReturnEligibleOrderCard(
                  order: provider.eligibleOrders[index],
                ),
              ),
            const SizedBox(height: 18),
            Text(
              context.tr("My return requests"),
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (provider.myReturns.isEmpty)
              _ReturnNotice(
                icon: Icons.hourglass_empty_rounded,
                message: context.tr("You have not submitted a return request."),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.myReturns.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) =>
                    _ReturnStatusCard(request: provider.myReturns[index]),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReturnEligibleOrderCard extends StatelessWidget {
  const _ReturnEligibleOrderCard({required this.order});

  final ReturnEligibleOrder order;

  @override
  Widget build(BuildContext context) {
    final returnableItems = order.items
        .where((item) => item.remainingReturnableQuantity > 0)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber.isEmpty
                      ? context.tr("Order #{p1}", {'p1': order.orderId})
                      : order.orderNumber,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                context.tr("Window ends {p1}", {
                  'p1': _orderDate(context, order.returnWindowEndsAt),
                }),
                style: const TextStyle(color: Color(0xFF5C6B64), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.tr("{p1} eligible line{p2} · delivered {p3}", {
              'p1': returnableItems.length,
              'p2': returnableItems.length == 1 ? '' : 's',
              'p3': _orderDate(context, order.deliveredAt),
            }),
            style: const TextStyle(color: Color(0xFF5C6B64), fontSize: 13),
          ),
          const SizedBox(height: 11),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: returnableItems.isEmpty
                  ? null
                  : () => _showReturnRequestDialog(context, order),
              icon: const Icon(Icons.assignment_return_outlined, size: 18),
              label: Text(context.tr("Request return")),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnStatusCard extends StatelessWidget {
  const _ReturnStatusCard({required this.request});

  final ReturnRequestStatus request;

  @override
  Widget build(BuildContext context) {
    final statusColor = _returnStatusColor(request.status);
    final hasNotes = request.adminNotes?.trim().isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr("Return #{p1} · order #{p2}", {
                    'p1': request.id,
                    'p2': request.orderId,
                  }),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _ReturnStatusBadge(label: request.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.reason,
            style: const TextStyle(color: Color(0xFF5C6B64)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(
                context.tr("Submitted {p1}", {
                  'p1': _orderDate(context, request.createdAt),
                }),
                style: const TextStyle(color: Color(0xFF5C6B64), fontSize: 12),
              ),
              Text(
                context.tr("Server-calculated amount: {p1} KM", {
                  'p1': context.l10n.number(
                    request.refundAmount,
                    decimalDigits: 2,
                  ),
                }),
                style: const TextStyle(color: Color(0xFF5C6B64), fontSize: 12),
              ),
            ],
          ),
          if (request.resolvedAt != null) ...[
            const SizedBox(height: 5),
            Text(
              context.tr("Resolved {p1}", {
                'p1': _orderDate(context, request.resolvedAt!),
              }),
              style: const TextStyle(color: Color(0xFF5C6B64), fontSize: 12),
            ),
          ],
          if (hasNotes) ...[
            const SizedBox(height: 8),
            Text(
              context.tr("Club note: {p1}", {'p1': request.adminNotes!.trim()}),
              style: const TextStyle(
                color: Color(0xFF27423A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReturnStatusBadge extends StatelessWidget {
  const _ReturnStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _ReturnNotice extends StatelessWidget {
  const _ReturnNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFDDE5DC)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF1F7A63)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF5C6B64)),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

Future<void> _showReturnRequestDialog(
  BuildContext context,
  ReturnEligibleOrder order,
) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (_) => _ReturnRequestDialog(order: order),
  );
  if (submitted != true || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        context.tr(
          "Return request submitted. Its current status is shown in My return requests.",
        ),
      ),
    ),
  );
}

class _ReturnRequestDialog extends StatefulWidget {
  const _ReturnRequestDialog({required this.order});

  final ReturnEligibleOrder order;

  @override
  State<_ReturnRequestDialog> createState() => _ReturnRequestDialogState();
}

class _ReturnRequestDialogState extends State<_ReturnRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  late final Map<int, int> _selectedQuantities;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    _selectedQuantities = {
      for (final item in widget.order.items) item.orderItemId: 0,
    };
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final selectedItems = _selectedQuantities.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) =>
              ReturnRequestLine(orderItemId: entry.key, quantity: entry.value),
        )
        .toList(growable: false);
    if (selectedItems.isEmpty) {
      setState(
        () =>
            _selectionError = context.tr("Select at least one item to return."),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<ReturnRequestsProvider>();
    final submission = await provider.submit(
      orderId: widget.order.orderId,
      reason: _reasonController.text,
      items: selectedItems,
    );
    if (!mounted) return;
    if (submission == null) {
      setState(
        () => _selectionError =
            provider.customerErrorMessage ??
            context.tr("Could not submit this return."),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReturnRequestsProvider>();
    final items = widget.order.items
        .where((item) => item.remainingReturnableQuantity > 0)
        .toList(growable: false);
    return AlertDialog(
      title: Text(
        widget.order.orderNumber.isEmpty
            ? context.tr("Request a return")
            : context.tr("Return {p1}", {'p1': widget.order.orderNumber}),
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    "Choose the quantities to return and explain the issue. PadelClub rechecks the items, return window, and amounts when you submit.",
                  ),
                  style: TextStyle(color: Color(0xFF5C6B64)),
                ),
                const SizedBox(height: 16),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedQuantities[item.orderItemId],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr("{p1} ({p2} available)", {
                          'p1': item.productName,
                          'p2': item.remainingReturnableQuantity,
                        }),
                        helperText: context
                            .tr("{p1} KM each · {p2} originally ordered", {
                              'p1': context.l10n.number(
                                item.unitPrice,
                                decimalDigits: 2,
                              ),
                              'p2': item.quantity,
                            }),
                      ),
                      items: List.generate(
                        item.remainingReturnableQuantity + 1,
                        (index) => DropdownMenuItem<int>(
                          value: index,
                          child: Text(
                            index == 0
                                ? context.tr("Do not return this item")
                                : context.tr("Return {p1}", {'p1': index}),
                          ),
                        ),
                      ),
                      onChanged: provider.isSubmitting
                          ? null
                          : (value) => setState(() {
                              _selectedQuantities[item.orderItemId] =
                                  value ?? 0;
                              _selectionError = null;
                            }),
                    ),
                  ),
                ),
                TextFormField(
                  controller: _reasonController,
                  enabled: !provider.isSubmitting,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: context.tr("Reason for return"),
                    hintText: context.tr(
                      "Describe the issue with the selected items.",
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length < 5) {
                      return context.tr("Use at least 5 characters.");
                    }
                    return null;
                  },
                ),
                if (_selectionError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _selectionError!,
                    style: const TextStyle(
                      color: Color(0xFFC95C4C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: provider.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(context.tr("Cancel")),
        ),
        FilledButton.icon(
          onPressed: provider.isSubmitting ? null : _submit,
          icon: provider.isSubmitting
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: Text(
            provider.isSubmitting
                ? context.tr("Submitting...")
                : context.tr("Submit return request"),
          ),
        ),
      ],
    );
  }
}

Color _returnStatusColor(String status) {
  return switch (status.trim().toLowerCase()) {
    'requested' => const Color(0xFF2E6BD7),
    'approved' || 'refunded' => const Color(0xFF1F7A63),
    'rejected' => const Color(0xFFC95C4C),
    _ => const Color(0xFF5C6B64),
  };
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final status = order.status.toLowerCase();
    final statusColor = status == 'delivered'
        ? const Color(0xFF1F7A63)
        : status == 'cancelled'
        ? const Color(0xFFC95C4C)
        : const Color(0xFF2E6BD7);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _orderDetail(
            Icons.calendar_today_outlined,
            _orderDate(context, order.createdAt),
          ),
          _orderDetail(
            Icons.location_on_outlined,
            [
              order.shippingAddress,
              order.postalCode,
              order.city,
            ].where((part) => part.trim().isNotEmpty).join(', '),
          ),
          if (order.recipientName.isNotEmpty)
            _orderDetail(Icons.person_outline_rounded, order.recipientName),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr("Total"),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${context.l10n.number(order.totalAmount, decimalDigits: 2)} KM',
                style: const TextStyle(
                  color: Color(0xFF1F7A63),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderDetail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF5C6B64)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(color: Color(0xFF5C6B64))),
        ),
      ],
    ),
  );
}

String _orderDate(BuildContext context, DateTime value) =>
    context.l10n.date(value);

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final available =
        product.stockQuantity > 0 &&
        !product.productState.toLowerCase().contains('deactivated');
    return Semantics(
      button: true,
      label:
          '${product.name}, ${context.l10n.number(product.price, decimalDigits: 2)} KM, ${available ? 'in stock' : 'unavailable'}',
      child: Material(
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
                            '${context.l10n.number(product.price, decimalDigits: 2)} KM',
                            style: const TextStyle(
                              color: Color(0xFF1F7A63),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          tooltip: available
                              ? context.tr("Add to cart")
                              : context.tr("Unavailable"),
                          onPressed: available ? onAdd : null,
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          iconSize: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
