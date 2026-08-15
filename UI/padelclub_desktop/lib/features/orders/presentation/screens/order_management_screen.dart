import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
import 'package:padelclub_desktop/features/orders/presentation/providers/order_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<OrderProvider>().loadOrders(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: 'Order Management',
      section: AppSection.orders,
      child: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          final orders = _filtered(provider.orders);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: 'Order Management',
                subtitle:
                    'Manage product orders, fulfillment, and customer purchases.',
                action: FilledButton.icon(
                  onPressed: () => _notice(
                    'Orders are created through the club shop checkout.',
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Order'),
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
                      children:
                          [
                                'All',
                                'Pending',
                                'Processing',
                                'Shipped',
                                'Delivered',
                                'Cancelled',
                              ]
                              .map(
                                (filter) => AdminFilterChip(
                                  label: filter == 'All'
                                      ? 'All Orders'
                                      : filter,
                                  selected: _filter == filter,
                                  onSelected: (_) =>
                                      setState(() => _filter = filter),
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
                          hintText: 'Search by order number or customer...',
                          width: 320,
                          onSubmitted: _setQuery,
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _setQuery(_searchController.text),
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: const Text('Search'),
                        ),
                        OutlinedButton.icon(
                          onPressed: provider.loadOrders,
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
                  child: AdminTableSurface(child: _content(provider, orders)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(OrderProvider provider, List<Order> orders) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return _OrderMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Orders are unavailable',
        message: provider.errorMessage!,
        onRetry: provider.loadOrders,
      );
    }
    if (orders.isEmpty) {
      return const _OrderMessage(
        icon: Icons.receipt_long_outlined,
        title: 'No orders found',
        message: 'Adjust the search or fulfillment filter.',
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
              dataRowMinHeight: 72,
              dataRowMaxHeight: 82,
              columnSpacing: 34,
              columns: const [
                DataColumn(label: Text('ORDER DETAILS')),
                DataColumn(label: Text('TOTAL')),
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: orders.map(_row).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(Order order) {
    final tone = _orderTone(order.status);
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _toneColor(tone),
                  borderRadius: BorderRadius.circular(PadelRadii.medium),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: PadelSpacing.sm),
              SizedBox(
                width: 280,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber.isEmpty
                          ? 'Order #${order.id}'
                          : order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Customer #${order.userId} · ${order.shippingAddress.isEmpty ? 'Address not provided' : order.shippingAddress}',
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
          Text(
            '${order.totalAmount.toStringAsFixed(2)} KM',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(Text(_date(order.createdAt))),
        DataCell(AdminStatusBadge(label: order.status, tone: tone)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.visibility_outlined,
                tooltip: 'View order',
                onPressed: () => _showOrder(order),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Update order',
                onPressed: () => _notice(
                  'Order status editing will be connected with the fulfillment form.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Order> _filtered(List<Order> orders) {
    return orders
        .where((order) {
          final matchesStatus =
              _filter == 'All' ||
              order.status.toLowerCase() == _filter.toLowerCase();
          final haystack =
              '${order.id} ${order.orderNumber} ${order.userId} '
                      '${order.shippingAddress} ${order.status}'
                  .toLowerCase();
          return matchesStatus && (_query.isEmpty || haystack.contains(_query));
        })
        .toList(growable: false);
  }

  void _setQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  void _showOrder(Order order) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          order.orderNumber.isEmpty ? 'Order #${order.id}' : order.orderNumber,
        ),
        content: Text(
          'Customer: #${order.userId}\nTotal: ${order.totalAmount.toStringAsFixed(2)} KM\n'
          'Status: ${order.status}\nShipping: ${order.shippingAddress}\n'
          'Notes: ${order.notes?.trim().isNotEmpty == true ? order.notes : 'None'}',
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

class _OrderMessage extends StatelessWidget {
  const _OrderMessage({
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

AdminStatusTone _orderTone(String status) {
  return switch (status.toLowerCase()) {
    'delivered' || 'completed' => AdminStatusTone.success,
    'shipped' || 'processing' => AdminStatusTone.info,
    'pending' => AdminStatusTone.warning,
    'cancelled' || 'canceled' => AdminStatusTone.danger,
    _ => AdminStatusTone.neutral,
  };
}

Color _toneColor(AdminStatusTone tone) {
  return switch (tone) {
    AdminStatusTone.success => PadelColors.green,
    AdminStatusTone.info => PadelColors.blue,
    AdminStatusTone.warning => PadelColors.warning,
    AdminStatusTone.danger => PadelColors.danger,
    AdminStatusTone.neutral => PadelColors.textMuted,
  };
}

String _date(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
