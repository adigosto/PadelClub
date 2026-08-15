import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
import 'package:padelclub_desktop/features/orders/presentation/providers/order_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/cart_provider.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/product_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

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

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: 'Shop',
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
                      const Expanded(
                        child: Text(
                          'Club shop',
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
                  const Text(
                    'Everything you need for your next match.',
                    style: TextStyle(color: Color(0xFF5C6B64), fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.storefront_outlined),
                          label: Text('Products'),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.receipt_long_outlined),
                          label: Text('My orders'),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (selection) {
                        final value = selection.first;
                        setState(() => _selectedTab = value);
                        if (value == 1) {
                          context.read<OrderProvider>().loadMine();
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
                        hintText: 'Search rackets, balls, apparel…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Search',
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
                                  label: Text(category),
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

  void _addToCart(Product product) {
    context.read<CartProvider>().add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart.'),
        duration: const Duration(seconds: 1),
      ),
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
      label: count == 0 ? 'Open cart, empty' : 'Open cart, $count items',
      child: ExcludeSemantics(
        child: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: IconButton.filledTonal(
            tooltip: 'Open cart',
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
    child: const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match-day essentials',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Club gear ready for your next court.',
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
                  const Expanded(
                    child: Text(
                      'Your cart',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (cart.lines.isNotEmpty)
                    TextButton(
                      onPressed: cart.clear,
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (cart.lines.isEmpty)
                const Expanded(
                  child: Center(child: Text('Your cart is empty.')),
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
                        subtitle: Text('${line.total.toStringAsFixed(2)} KM'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Remove one ${line.product.name}',
                              onPressed: () => cart.decrement(line.product),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                              ),
                            ),
                            Semantics(
                              label: 'Quantity ${line.quantity}',
                              child: Text(
                                '${line.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add one ${line.product.name}',
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
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${cart.total.toStringAsFixed(2)} KM',
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
                    label: const Text('Proceed to checkout'),
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
    builder: (sheetContext) => const _CheckoutSheet(),
  );
  if (orderNumber != null && context.mounted) {
    Navigator.pop(context);
    context.read<OrderProvider>().loadMine();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF1F7A63)),
        title: const Text('Order placed'),
        content: Text('Order $orderNumber was submitted successfully.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
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
    final provider = context.watch<OrderProvider>();
    if (provider.isLoading && provider.orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.errorMessage != null && provider.orders.isEmpty) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Orders are unavailable',
        message: provider.errorMessage!,
        actionLabel: 'Try again',
        onAction: provider.loadMine,
      );
    }
    if (provider.orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Color(0xFF1F7A63),
            ),
            SizedBox(height: 14),
            Text(
              'No orders yet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text('Completed checkouts will appear here.'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.loadMine,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: provider.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _OrderCard(order: provider.orders[index]),
      ),
    );
  }
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
            _orderDate(order.createdAt),
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
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${order.totalAmount.toStringAsFixed(2)} KM',
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

String _orderDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet();

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _notesController = TextEditingController();
  String? _validationMessage;
  late final int _itemCount;
  late final double _total;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final cart = context.read<CartProvider>();
    _recipientController.text = auth.displayName;
    _phoneController.text = auth.phoneNumber ?? '';
    _itemCount = cart.itemCount;
    _total = cart.total;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openInMaps() async {
    final parts = [
      _addressController.text.trim(),
      _postalCodeController.text.trim(),
      _cityController.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    if (parts.length < 5) {
      setState(
        () => _validationMessage = 'Enter an address before opening Maps.',
      );
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': parts,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => _validationMessage = 'Google Maps could not be opened.');
    }
  }

  Future<void> _submit() async {
    final recipient = _recipientController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final postalCode = _postalCodeController.text.trim();
    if (recipient.length < 2 || phone.length < 6) {
      setState(
        () => _validationMessage = 'Enter the recipient name and phone number.',
      );
      return;
    }
    if (address.length < 5 || city.length < 2 || postalCode.length < 3) {
      setState(
        () =>
            _validationMessage = 'Complete the address, city, and postal code.',
      );
      return;
    }
    final cart = context.read<CartProvider>();
    final number = await cart.checkout(
      recipientName: recipient,
      phoneNumber: phone,
      shippingAddress: address,
      city: city,
      postalCode: postalCode,
      notes: _notesController.text,
    );
    if (!mounted) return;
    if (number != null) {
      Navigator.pop(context, number);
    } else {
      setState(() => _validationMessage = cart.checkoutError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checkout', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              '$_itemCount items · ${_total.toStringAsFixed(2)} KM',
              style: const TextStyle(color: Color(0xFF5C6B64)),
            ),
            const SizedBox(height: 20),
            _checkoutField(
              controller: _recipientController,
              label: 'Recipient name',
              icon: Icons.person_outline_rounded,
              enabled: !cart.isCheckingOut,
            ),
            const SizedBox(height: 12),
            _checkoutField(
              controller: _phoneController,
              label: 'Phone number',
              icon: Icons.phone_outlined,
              enabled: !cart.isCheckingOut,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _checkoutField(
              controller: _addressController,
              label: 'Street address',
              icon: Icons.location_on_outlined,
              enabled: !cart.isCheckingOut,
              keyboardType: TextInputType.streetAddress,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _checkoutField(
                    controller: _cityController,
                    label: 'City',
                    enabled: !cart.isCheckingOut,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _checkoutField(
                    controller: _postalCodeController,
                    label: 'Postal code',
                    enabled: !cart.isCheckingOut,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: cart.isCheckingOut ? null : _openInMaps,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Check address in Google Maps'),
              ),
            ),
            TextField(
              controller: _notesController,
              enabled: !cart.isCheckingOut,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Delivery notes (optional)',
              ),
            ),
            if (_validationMessage != null)
              Text(
                _validationMessage!,
                style: const TextStyle(color: Color(0xFFC95C4C)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: cart.isCheckingOut ? null : _submit,
                icon: cart.isCheckingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline_rounded),
                label: Text(cart.isCheckingOut ? 'Submitting…' : 'Place order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkoutField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => setState(() => _validationMessage = null),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }
}

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
          '${product.name}, ${product.price.toStringAsFixed(2)} KM, ${available ? 'in stock' : 'unavailable'}',
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
                            '${product.price.toStringAsFixed(2)} KM',
                            style: const TextStyle(
                              color: Color(0xFF1F7A63),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          tooltip: available ? 'Add to cart' : 'Unavailable',
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
