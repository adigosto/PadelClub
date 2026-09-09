import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/orders/domain/entities/order.dart';
import 'package:padelclub_desktop/features/orders/presentation/providers/order_provider.dart';
import 'package:padelclub_desktop/features/returns/domain/entities/return_request_status.dart';
import 'package:padelclub_desktop/features/returns/presentation/providers/return_requests_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final _searchController = TextEditingController();
  _OrderWorkspace _workspace = _OrderWorkspace.orders;
  String _filter = 'All';
  String _returnFilter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrderProvider>().loadOrders();
      context.read<ReturnRequestsProvider>().loadAdmin();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: context.tr("Order Management"),
      section: AppSection.orders,
      child: Consumer2<OrderProvider, ReturnRequestsProvider>(
        builder: (context, orderProvider, returnProvider, _) {
          final orders = _filtered(orderProvider.orders);
          final isOrdersWorkspace = _workspace == _OrderWorkspace.orders;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: context.tr("Order Management"),
                subtitle: isOrdersWorkspace
                    ? context.tr(
                        "Manage product orders, fulfillment, and customer purchases.",
                      )
                    : context.tr(
                        "Review customer return requests using the server-authoritative work queue.",
                      ),
                action: isOrdersWorkspace
                    ? FilledButton.icon(
                        onPressed: () => _notice(
                          context.tr(
                            "Orders are created through the club shop checkout.",
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(context.tr("New Order")),
                      )
                    : FilledButton.icon(
                        onPressed:
                            returnProvider.isLoadingAdminReturns ||
                                returnProvider.resolvingReturnId != null
                            ? null
                            : () => _loadReturns(_returnFilter),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(context.tr("Refresh returns")),
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
                      children: [
                        AdminFilterChip(
                          label: context.tr("Orders"),
                          selected: isOrdersWorkspace,
                          onSelected: (_) => setState(
                            () => _workspace = _OrderWorkspace.orders,
                          ),
                        ),
                        AdminFilterChip(
                          label: context.tr("Return requests"),
                          selected: !isOrdersWorkspace,
                          onSelected: (_) {
                            setState(
                              () => _workspace = _OrderWorkspace.returns,
                            );
                            if (returnProvider.adminReturns.isEmpty &&
                                !returnProvider.isLoadingAdminReturns) {
                              _loadReturns(_returnFilter);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: PadelSpacing.md),
                    if (isOrdersWorkspace) ...[
                      Wrap(
                        spacing: PadelSpacing.xs,
                        runSpacing: PadelSpacing.xs,
                        children:
                            [
                                  "All",
                                  "Pending",
                                  "Processing",
                                  "Shipped",
                                  "Delivered",
                                  "Cancelled",
                                ]
                                .map(
                                  (filter) => AdminFilterChip(
                                    label: filter == 'All'
                                        ? context.tr("All Orders")
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
                            hintText: context.tr(
                              "Search by order number or customer...",
                            ),
                            width: 320,
                            onSubmitted: _setQuery,
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _setQuery(_searchController.text),
                            icon: const Icon(Icons.search_rounded, size: 17),
                            label: Text(context.tr("Search")),
                          ),
                          OutlinedButton.icon(
                            onPressed: orderProvider.loadOrders,
                            icon: const Icon(Icons.refresh_rounded, size: 17),
                            label: Text(context.tr("Refresh")),
                          ),
                        ],
                      ),
                    ] else ...[
                      Wrap(
                        spacing: PadelSpacing.xs,
                        runSpacing: PadelSpacing.xs,
                        children:
                            [
                                  "All",
                                  "Requested",
                                  "Approved",
                                  "Refunded",
                                  "Rejected",
                                ]
                                .map(
                                  (filter) => AdminFilterChip(
                                    label: filter == 'All'
                                        ? context.tr("All requests")
                                        : filter,
                                    selected: _returnFilter == filter,
                                    onSelected: (_) => _setReturnFilter(
                                      filter,
                                      returnProvider,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                      ),
                      const SizedBox(height: PadelSpacing.sm),
                      Text(
                        context.tr(
                          "Approving a requested return can restock the returned items and issue a Stripe refund when applicable. The server validates the current state before every resolution.",
                        ),
                        style: TextStyle(
                          color: PadelColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (returnProvider.adminErrorMessage != null) ...[
                        const SizedBox(height: PadelSpacing.sm),
                        _ReturnQueueError(
                          message: returnProvider.adminErrorMessage!,
                          onRetry:
                              returnProvider.isLoadingAdminReturns ||
                                  returnProvider.resolvingReturnId != null
                              ? null
                              : () => _loadReturns(_returnFilter),
                        ),
                      ],
                    ],
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
                    child: isOrdersWorkspace
                        ? _ordersContent(orderProvider, orders)
                        : _returnsContent(returnProvider),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ordersContent(OrderProvider provider, List<Order> orders) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return _OrderMessage(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Orders are unavailable"),
        message: provider.errorMessage!,
        onRetry: provider.loadOrders,
      );
    }
    if (orders.isEmpty) {
      return _OrderMessage(
        icon: Icons.receipt_long_outlined,
        title: context.tr("No orders found"),
        message: context.tr("Adjust the search or fulfillment filter."),
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
              columns: [
                DataColumn(label: Text(context.tr("ORDER DETAILS"))),
                DataColumn(label: Text(context.tr("TOTAL"))),
                DataColumn(label: Text(context.tr("DATE"))),
                DataColumn(label: Text(context.tr("STATUS"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: orders
                  .map((order) => _row(order, provider))
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _returnsContent(ReturnRequestsProvider provider) {
    final requests = provider.adminReturns;
    if (provider.isLoadingAdminReturns && requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (requests.isEmpty) {
      return _OrderMessage(
        icon: Icons.assignment_return_outlined,
        title: context.tr("No return requests found"),
        message: _returnFilter == 'All'
            ? context.tr(
                "There are no customer returns in the current work queue.",
              )
            : context.tr("There are no {p1} return requests.", {
                'p1': _returnFilter,
              }),
        onRetry: provider.isLoadingAdminReturns
            ? null
            : () => _loadReturns(_returnFilter),
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
              dataRowMinHeight: 92,
              dataRowMaxHeight: 128,
              columnSpacing: 28,
              columns: [
                DataColumn(label: Text(context.tr("RETURN"))),
                DataColumn(label: Text(context.tr("REASON / CLUB NOTE"))),
                DataColumn(label: Text(context.tr("REFUND"))),
                DataColumn(label: Text(context.tr("DATES"))),
                DataColumn(label: Text(context.tr("STATUS"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: requests
                  .map((request) => _returnRow(request, provider))
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(Order order, OrderProvider provider) {
    final tone = _orderTone(order.status);
    final allowedStatuses = OrderProvider.nextStatusesFor(order.status);
    final isStatusFinal = allowedStatuses.isEmpty;
    final isUpdating = provider.updatingOrderId != null;
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
                          ? context.tr("Order #{p1}", {'p1': order.id})
                          : order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr("Customer #{p1} · {p2}", {
                        'p1': order.userId,
                        'p2': order.shippingAddress.isEmpty
                            ? 'Address not provided'
                            : order.shippingAddress,
                      }),
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
            '${context.l10n.number(order.totalAmount, decimalDigits: 2)} KM',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(Text(_date(context, order.createdAt))),
        DataCell(AdminStatusBadge(label: order.status, tone: tone)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.visibility_outlined,
                tooltip: context.tr("View order"),
                onPressed: () => _showOrder(order),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: isUpdating && provider.isUpdating(order.id)
                    ? Icons.sync_rounded
                    : Icons.local_shipping_outlined,
                tooltip: isStatusFinal
                    ? context.tr("Order status is final")
                    : context.tr("Change fulfillment status"),
                onPressed: isStatusFinal || isUpdating
                    ? null
                    : () => _showStatusChange(order),
              ),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _returnRow(
    ReturnRequestStatus request,
    ReturnRequestsProvider provider,
  ) {
    final tone = _returnTone(request.status);
    final notes = request.adminNotes?.trim();
    final isResolving = provider.isResolving(request.id);
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 158,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("Return #{p1}", {'p1': request.id}),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr("Order #{p1} - Customer #{p2}", {
                    'p1': request.orderId,
                    'p2': request.userId ?? 'N/A',
                  }),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PadelColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.reason.trim().isEmpty
                      ? context.tr("No reason was provided.")
                      : request.reason.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    context.tr("Club note: {p1}", {'p1': notes}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PadelColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        DataCell(
          Text(
            '${context.l10n.number(request.refundAmount, decimalDigits: 2)} KM',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("Submitted {p1}", {
                    'p1': _dateTime(context, request.createdAt),
                  }),
                  style: const TextStyle(fontSize: 11),
                ),
                if (request.resolvedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.tr("Resolved {p1}", {
                      'p1': _dateTime(context, request.resolvedAt!),
                    }),
                    style: const TextStyle(
                      color: PadelColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        DataCell(AdminStatusBadge(label: request.status, tone: tone)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.visibility_outlined,
                tooltip: context.tr("View return details"),
                onPressed: () => _showReturnDetails(request),
              ),
              if (request.isRequested) ...[
                const SizedBox(width: PadelSpacing.xs),
                AdminActionButton(
                  icon: isResolving
                      ? Icons.more_horiz_rounded
                      : Icons.check_circle_outline_rounded,
                  tooltip: context.tr("Approve return"),
                  onPressed: isResolving || provider.resolvingReturnId != null
                      ? null
                      : () => _showReturnResolution(request, approve: true),
                ),
                const SizedBox(width: PadelSpacing.xs),
                AdminActionButton(
                  icon: Icons.cancel_outlined,
                  tooltip: context.tr("Reject return"),
                  destructive: true,
                  onPressed: isResolving || provider.resolvingReturnId != null
                      ? null
                      : () => _showReturnResolution(request, approve: false),
                ),
              ],
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

  void _setReturnFilter(String value, ReturnRequestsProvider provider) {
    if (_returnFilter != value) {
      setState(() => _returnFilter = value);
    }
    if (!provider.isLoadingAdminReturns && provider.resolvingReturnId == null) {
      _loadReturns(value);
    }
  }

  void _loadReturns(String filter) {
    context.read<ReturnRequestsProvider>().loadAdmin(
      status: filter == 'All' ? null : filter,
    );
  }

  void _showOrder(Order order) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          order.orderNumber.isEmpty
              ? context.tr("Order #{p1}", {'p1': order.id})
              : order.orderNumber,
        ),
        content: Text(
          context.tr(
            "Customer: #{p1}\nTotal: {p2} KM\nStatus: {p3}\nShipping: {p4}\nNotes: {p5}",
            {
              'p1': order.userId,
              'p2': context.l10n.number(order.totalAmount, decimalDigits: 2),
              'p3': context.tr(order.status),
              'p4': order.shippingAddress,
              'p5': order.notes?.trim().isNotEmpty == true
                  ? order.notes
                  : 'None',
            },
          ),
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

  Future<void> _showStatusChange(Order order) async {
    final result = await showDialog<_OrderStatusChangeResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OrderStatusDialog(order: order),
    );
    if (!mounted || result == null) return;

    final orderLabel = order.orderNumber.isEmpty
        ? '#${order.id}'
        : order.orderNumber;
    final success = context.tr("Order {p1} is now {p2}.", {
      'p1': orderLabel,
      'p2': context.tr(result.status),
    });
    _notice(
      result.refreshWarning == null
          ? success
          : '$success ${result.refreshWarning}',
    );
  }

  void _showReturnDetails(ReturnRequestStatus request) {
    final notes = request.adminNotes?.trim();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Return #{p1}", {'p1': request.id})),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReturnDetailRow(
                  label: context.tr("Order"),
                  value: '#${request.orderId}',
                ),
                _ReturnDetailRow(
                  label: context.tr("Customer"),
                  value: request.userId == null
                      ? 'Not returned by API'
                      : '#${request.userId}',
                ),
                _ReturnDetailRow(
                  label: context.tr("Refund amount"),
                  value:
                      '${context.l10n.number(request.refundAmount, decimalDigits: 2)} KM',
                ),
                _ReturnDetailRow(
                  label: context.tr("Status"),
                  value: request.status,
                ),
                _ReturnDetailRow(
                  label: context.tr("Submitted"),
                  value: _dateTime(context, request.createdAt),
                ),
                if (request.resolvedAt != null)
                  _ReturnDetailRow(
                    label: context.tr("Resolved"),
                    value: _dateTime(context, request.resolvedAt!),
                  ),
                const SizedBox(height: PadelSpacing.sm),
                Text(
                  context.tr("Customer reason"),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: PadelSpacing.xs),
                Text(
                  request.reason.trim().isEmpty
                      ? context.tr("No reason was provided.")
                      : request.reason.trim(),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: PadelSpacing.md),
                  Text(
                    context.tr("Club note"),
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: PadelSpacing.xs),
                  Text(notes),
                ],
              ],
            ),
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
  }

  Future<void> _showReturnResolution(
    ReturnRequestStatus request, {
    required bool approve,
  }) async {
    final resolved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ReturnResolutionDialog(request: request, approve: approve),
    );
    if (resolved != true || !mounted) return;
    final refreshError = context
        .read<ReturnRequestsProvider>()
        .adminErrorMessage;
    _notice(
      refreshError == null
          ? approve
                ? context.tr(
                    "Return #{p1} was approved and the work queue was refreshed.",
                    {'p1': request.id},
                  )
                : context.tr(
                    "Return #{p1} was rejected and the work queue was refreshed.",
                    {'p1': request.id},
                  )
          : context.tr(
              "Return #{p1} was resolved, but the refreshed queue could not be loaded.",
              {'p1': request.id},
            ),
    );
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

class _OrderStatusChangeResult {
  const _OrderStatusChangeResult({required this.status, this.refreshWarning});

  final String status;
  final String? refreshWarning;
}

class _OrderStatusDialog extends StatefulWidget {
  const _OrderStatusDialog({required this.order});

  final Order order;

  @override
  State<_OrderStatusDialog> createState() => _OrderStatusDialogState();
}

class _OrderStatusDialogState extends State<_OrderStatusDialog> {
  late String _selectedStatus;
  String? _submissionError;

  List<String> get _allowedStatuses =>
      OrderProvider.nextStatusesFor(widget.order.status);

  @override
  void initState() {
    super.initState();
    _selectedStatus = _allowedStatuses.first;
  }

  Future<void> _submit() async {
    final provider = context.read<OrderProvider>();
    final accepted = await provider.updateStatus(
      order: widget.order,
      nextStatus: _selectedStatus,
    );
    if (!mounted) return;
    if (accepted) {
      Navigator.of(context).pop(
        _OrderStatusChangeResult(
          status: _selectedStatus,
          refreshWarning: provider.errorMessage,
        ),
      );
      return;
    }
    setState(
      () => _submissionError =
          provider.errorMessage ??
          context.tr(
            "The server could not update this order. Refresh and try again.",
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final isSubmitting = provider.isUpdating(widget.order.id);
    final orderLabel = widget.order.orderNumber.isEmpty
        ? context.tr("Order #{p1}", {'p1': widget.order.id})
        : widget.order.orderNumber;
    final isCancellation = _selectedStatus == 'Cancelled';
    return AlertDialog(
      title: Text(
        context.tr("Change fulfillment status for {p1}?", {'p1': orderLabel}),
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr("Current status: {p1}", {
                'p1': context.tr(widget.order.status),
              }),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: PadelSpacing.sm),
            Text(
              context.tr(
                "Only the next fulfilment steps are offered here. PadelClub validates the current order state again on the server before saving.",
              ),
            ),
            const SizedBox(height: PadelSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr("New fulfillment status"),
              ),
              items: _allowedStatuses
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(context.tr(status)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: isSubmitting
                  ? null
                  : (status) {
                      if (status == null) return;
                      setState(() {
                        _selectedStatus = status;
                        _submissionError = null;
                      });
                    },
            ),
            if (_selectedStatus == 'Cancelled') ...[
              const SizedBox(height: PadelSpacing.sm),
              Text(
                context.tr(
                  "Cancelling restocks the order items only if the server still allows this transition.",
                ),
                style: TextStyle(color: PadelColors.textMuted, fontSize: 12),
              ),
            ],
            if (_submissionError != null) ...[
              const SizedBox(height: PadelSpacing.sm),
              _OrderStatusError(message: _submissionError!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr("Cancel")),
        ),
        FilledButton(
          onPressed: isSubmitting ? null : _submit,
          style: isCancellation
              ? FilledButton.styleFrom(backgroundColor: PadelColors.danger)
              : null,
          child: isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr("Confirm {p1}", {'p1': _selectedStatus})),
        ),
      ],
    );
  }
}

class _OrderStatusError extends StatelessWidget {
  const _OrderStatusError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PadelSpacing.sm),
      decoration: BoxDecoration(
        color: PadelColors.dangerSoft,
        border: Border.all(color: PadelColors.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(PadelRadii.medium),
      ),
      child: Text(message, style: const TextStyle(color: PadelColors.text)),
    );
  }
}

enum _OrderWorkspace { orders, returns }

class _ReturnQueueError extends StatelessWidget {
  const _ReturnQueueError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PadelSpacing.sm),
      decoration: BoxDecoration(
        color: PadelColors.dangerSoft,
        border: Border.all(color: PadelColors.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(PadelRadii.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: PadelColors.danger),
          const SizedBox(width: PadelSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: PadelColors.text),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: PadelSpacing.sm),
            TextButton(onPressed: onRetry, child: Text(context.tr("Retry"))),
          ],
        ],
      ),
    );
  }
}

class _ReturnDetailRow extends StatelessWidget {
  const _ReturnDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PadelSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(
                color: PadelColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ReturnResolutionDialog extends StatefulWidget {
  const _ReturnResolutionDialog({required this.request, required this.approve});

  final ReturnRequestStatus request;
  final bool approve;

  @override
  State<_ReturnResolutionDialog> createState() =>
      _ReturnResolutionDialogState();
}

class _ReturnResolutionDialogState extends State<_ReturnResolutionDialog> {
  final _notesController = TextEditingController();
  String? _resolutionError;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final provider = context.read<ReturnRequestsProvider>();
    final accepted = await provider.resolve(
      returnRequestId: widget.request.id,
      approve: widget.approve,
      adminNotes: _notesController.text,
    );
    if (!mounted) return;
    if (accepted) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(
      () => _resolutionError =
          provider.adminErrorMessage ??
          context.tr(
            "This return could not be resolved. Refresh and review its status.",
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReturnRequestsProvider>();
    final isResolving = provider.isResolving(widget.request.id);
    final action = widget.approve
        ? context.tr("Approve")
        : context.tr("Reject");
    final explanation = widget.approve
        ? context.tr(
            "Approving tells PadelClub to validate the request, restock returned inventory, and process a Stripe refund when the original payment permits it.",
          )
        : context.tr(
            "Rejecting marks this request as declined. PadelClub keeps the goods out of inventory and notifies the customer.",
          );
    return AlertDialog(
      title: Text(
        context.tr("{p1} return #{p2}?", {
          'p1': action,
          'p2': widget.request.id,
        }),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("Order #{p1} - {p2} KM server-calculated refund.", {
                  'p1': widget.request.orderId,
                  'p2': context.l10n.number(
                    widget.request.refundAmount,
                    decimalDigits: 2,
                  ),
                }),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: PadelSpacing.sm),
              Text(explanation),
              const SizedBox(height: PadelSpacing.sm),
              Text(
                context.tr(
                  "The action is only accepted if the server still considers this return requested.",
                ),
                style: TextStyle(color: PadelColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: PadelSpacing.md),
              TextField(
                controller: _notesController,
                enabled: !isResolving,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: context.tr("Optional club note"),
                  hintText: context.tr(
                    "Saved with the return record for staff and customer context.",
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              if (_resolutionError != null) ...[
                const SizedBox(height: PadelSpacing.xs),
                _ReturnQueueError(message: _resolutionError!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isResolving ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr("Cancel")),
        ),
        FilledButton(
          onPressed: isResolving ? null : _resolve,
          style: widget.approve
              ? null
              : FilledButton.styleFrom(backgroundColor: PadelColors.danger),
          child: isResolving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.approve
                      ? context.tr("Approve and restock")
                      : context.tr("Reject request"),
                ),
        ),
      ],
    );
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

AdminStatusTone _orderTone(String status) {
  return switch (status.toLowerCase()) {
    'delivered' || 'completed' => AdminStatusTone.success,
    'shipped' || 'processing' => AdminStatusTone.info,
    'pending' => AdminStatusTone.warning,
    'cancelled' || 'canceled' => AdminStatusTone.danger,
    _ => AdminStatusTone.neutral,
  };
}

AdminStatusTone _returnTone(String status) {
  return switch (status.trim().toLowerCase()) {
    'requested' => AdminStatusTone.warning,
    'approved' || 'refunded' => AdminStatusTone.success,
    'rejected' => AdminStatusTone.danger,
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

String _date(BuildContext context, DateTime value) => context.l10n.date(value);

String _dateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return context.tr("{p1} at {p2}:{p3}", {
    'p1': _date(context, local),
    'p2': hour,
    'p3': minute,
  });
}
