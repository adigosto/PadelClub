import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/notifications/domain/entities/club_notification.dart';
import 'package:padelclub_desktop/features/notifications/presentation/providers/notification_provider.dart';
import 'package:padelclub_desktop/features/users/domain/entities/user.dart';
import 'package:padelclub_desktop/features/users/presentation/providers/user_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  State<NotificationManagementScreen> createState() =>
      _NotificationManagementScreenState();
}

class _NotificationManagementScreenState
    extends State<NotificationManagementScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<NotificationProvider>().loadAdminNotifications(),
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
      title: 'Notifications',
      section: AppSection.notifications,
      child: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          final items = _filtered(provider.notifications);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: 'Notifications',
                subtitle:
                    'Create and manage notifications delivered to club members.',
                action: FilledButton.icon(
                  onPressed: provider.isLoading ? null : _sendNotification,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Send Notification'),
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
                                'Unread',
                                'Bookings',
                                'Orders',
                                'Users',
                                'System',
                              ]
                              .map(
                                (filter) => AdminFilterChip(
                                  label: filter == 'All'
                                      ? 'All Notifications'
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
                          hintText: 'Search notifications...',
                          width: 320,
                          onSubmitted: _setQuery,
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _setQuery(_searchController.text),
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: const Text('Search'),
                        ),
                        OutlinedButton.icon(
                          onPressed: provider.loadAdminNotifications,
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
                  child: AdminTableSurface(child: _content(provider, items)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(NotificationProvider provider, List<ClubNotification> items) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return _NotificationState(
        icon: Icons.cloud_off_rounded,
        title: 'Notifications are unavailable',
        message: provider.errorMessage!,
        onRetry: provider.loadAdminNotifications,
      );
    }
    if (items.isEmpty) {
      return const _NotificationState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications found',
        message: 'Send a notification or adjust the current filters.',
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
              columnSpacing: 38,
              columns: const [
                DataColumn(label: Text('NOTIFICATION')),
                DataColumn(label: Text('TYPE')),
                DataColumn(label: Text('DELIVERY')),
                DataColumn(label: Text('TIME')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: items.map(_row).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(ClubNotification item) {
    final tone = _typeTone(item.type);
    return DataRow(
      color: WidgetStateProperty.resolveWith(
        (_) => item.hasUnreadRecipients
            ? PadelColors.blueSoft.withValues(alpha: 0.42)
            : null,
      ),
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _toneSurface(tone),
                  borderRadius: BorderRadius.circular(PadelRadii.medium),
                ),
                child: Icon(
                  _typeIcon(item.type),
                  color: _toneColor(tone),
                  size: 20,
                ),
              ),
              const SizedBox(width: PadelSpacing.sm),
              SizedBox(
                width: 380,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.message,
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
        DataCell(AdminStatusBadge(label: item.type, tone: tone)),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.readCount} of ${item.recipientCount} read',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: item.recipientCount == 0
                      ? 0
                      : item.readCount / item.recipientCount,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(_relativeTime(item.createdAt))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.visibility_outlined,
                tooltip: 'View notification',
                onPressed: () => _showDetails(item),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit notification',
                onPressed: () => _editNotification(item),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete notification',
                onPressed: () => _deleteNotification(item),
                destructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<ClubNotification> _filtered(List<ClubNotification> items) {
    return items
        .where((item) {
          final matchesFilter = switch (_filter) {
            'Unread' => item.hasUnreadRecipients,
            'Bookings' ||
            'Orders' ||
            'Users' ||
            'System' => item.type.toLowerCase() == _filter.toLowerCase(),
            _ => true,
          };
          final haystack = '${item.title} ${item.message} ${item.type}'
              .toLowerCase();
          return matchesFilter && (_query.isEmpty || haystack.contains(_query));
        })
        .toList(growable: false);
  }

  Future<void> _sendNotification() async {
    final users = context.read<UserProvider>();
    if (users.users.isEmpty) await users.loadUsers();
    if (!mounted) return;
    final draft = await showDialog<_NotificationDraft>(
      context: context,
      builder: (_) => _NotificationDialog(users: users.users),
    );
    if (draft == null || !mounted) return;
    final provider = context.read<NotificationProvider>();
    final sent = await provider.createNotification(
      title: draft.title,
      message: draft.message,
      type: draft.type,
      recipientUserIds: draft.recipientUserId == null
          ? const []
          : [draft.recipientUserId!],
    );
    if (!mounted) return;
    _notice(
      sent ? 'Notification sent.' : provider.errorMessage ?? 'Send failed.',
    );
  }

  Future<void> _editNotification(ClubNotification item) async {
    final draft = await showDialog<_NotificationDraft>(
      context: context,
      builder: (_) => _NotificationDialog(notification: item),
    );
    if (draft == null || !mounted) return;
    final provider = context.read<NotificationProvider>();
    final updated = await provider.updateNotification(
      ClubNotification(
        id: item.id,
        title: draft.title,
        message: draft.message,
        type: draft.type,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        recipientCount: item.recipientCount,
        readCount: item.readCount,
      ),
    );
    if (!mounted) return;
    _notice(
      updated
          ? 'Notification updated.'
          : provider.errorMessage ?? 'Update failed.',
    );
  }

  Future<void> _deleteNotification(ClubNotification item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete notification?'),
        content: Text('Delete “${item.title}” for all recipients?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<NotificationProvider>();
    final deleted = await provider.deleteNotification(item.id);
    if (!mounted) return;
    _notice(
      deleted
          ? 'Notification deleted.'
          : provider.errorMessage ?? 'Delete failed.',
    );
  }

  void _showDetails(ClubNotification item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: Text(
          '${item.message}\n\nType: ${item.type}\n'
          'Delivered to: ${item.recipientCount} users\n'
          'Read by: ${item.readCount} users\nCreated: ${_dateTime(item.createdAt)}',
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

  void _setQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationDraft {
  const _NotificationDraft({
    required this.title,
    required this.message,
    required this.type,
    this.recipientUserId,
  });

  final String title;
  final String message;
  final String type;
  final int? recipientUserId;
}

class _NotificationDialog extends StatefulWidget {
  const _NotificationDialog({this.notification, this.users = const []});

  final ClubNotification? notification;
  final List<User> users;

  @override
  State<_NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<_NotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _message;
  late String _type;
  int _recipientSelection = 0;

  bool get _isEditing => widget.notification != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.notification?.title ?? '');
    _message = TextEditingController(text: widget.notification?.message ?? '');
    _type = widget.notification?.type ?? 'System';
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const types = ['System', 'Bookings', 'Orders', 'Users', 'Payments'];
    return AlertDialog(
      title: Text(_isEditing ? 'Edit notification' : 'Send notification'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                maxLength: 200,
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Enter a title' : null,
              ),
              const SizedBox(height: PadelSpacing.sm),
              TextFormField(
                controller: _message,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLength: 2000,
                maxLines: 4,
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Enter a message' : null,
              ),
              const SizedBox(height: PadelSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: types.contains(_type) ? _type : 'System',
                decoration: const InputDecoration(labelText: 'Type'),
                items: types
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(growable: false),
                onChanged: (value) => _type = value ?? 'System',
              ),
              if (!_isEditing) ...[
                const SizedBox(height: PadelSpacing.sm),
                DropdownButtonFormField<int>(
                  initialValue: _recipientSelection,
                  decoration: const InputDecoration(labelText: 'Recipients'),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('All active users'),
                    ),
                    ...widget.users.map(
                      (user) => DropdownMenuItem<int>(
                        value: user.id,
                        child: Text('${user.displayName} (${user.email})'),
                      ),
                    ),
                  ],
                  onChanged: (value) => _recipientSelection = value ?? 0,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Send'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _NotificationDraft(
        title: _title.text.trim(),
        message: _message.text.trim(),
        type: _type,
        recipientUserId: _recipientSelection == 0 ? null : _recipientSelection,
      ),
    );
  }
}

class _NotificationState extends StatelessWidget {
  const _NotificationState({
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: PadelSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

AdminStatusTone _typeTone(String type) => switch (type.toLowerCase()) {
  'bookings' => AdminStatusTone.info,
  'orders' || 'payments' => AdminStatusTone.success,
  'users' => AdminStatusTone.warning,
  _ => AdminStatusTone.neutral,
};

IconData _typeIcon(String type) => switch (type.toLowerCase()) {
  'bookings' => Icons.calendar_month_outlined,
  'orders' => Icons.shopping_bag_outlined,
  'payments' => Icons.payments_outlined,
  'users' => Icons.person_outline_rounded,
  _ => Icons.notifications_none_rounded,
};

Color _toneColor(AdminStatusTone tone) => switch (tone) {
  AdminStatusTone.success => PadelColors.greenDark,
  AdminStatusTone.info => PadelColors.blue,
  AdminStatusTone.warning => PadelColors.warning,
  AdminStatusTone.danger => PadelColors.danger,
  AdminStatusTone.neutral => PadelColors.textMuted,
};

Color _toneSurface(AdminStatusTone tone) => switch (tone) {
  AdminStatusTone.success => PadelColors.greenSoft,
  AdminStatusTone.info => PadelColors.blueSoft,
  AdminStatusTone.warning => PadelColors.warningSoft,
  AdminStatusTone.danger => PadelColors.dangerSoft,
  AdminStatusTone.neutral => PadelColors.canvas,
};

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays < 1) return '${difference.inHours} hr ago';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  return _dateTime(value);
}

String _dateTime(DateTime value) {
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
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return '${months[value.month - 1]} ${value.day}, ${value.year} · $time';
}
