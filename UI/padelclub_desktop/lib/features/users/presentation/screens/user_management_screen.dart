import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/users/domain/entities/user.dart';
import 'package:padelclub_desktop/features/users/presentation/providers/user_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

enum _UserFilter { all, active, inactive }

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();
  _UserFilter _filter = _UserFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<UserProvider>().loadUsers(),
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
      title: 'User Management',
      section: AppSection.members,
      child: Consumer<UserProvider>(
        builder: (context, provider, _) {
          final users = _applyFilters(provider.users);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: 'User Management',
                subtitle: 'Manage club members, roles, and account access.',
                action: FilledButton.icon(
                  onPressed: _showAddUserNotice,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add User'),
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
                      children: _UserFilter.values
                          .map(
                            (filter) => AdminFilterChip(
                              label: switch (filter) {
                                _UserFilter.all => 'All Users',
                                _UserFilter.active => 'Active',
                                _UserFilter.inactive => 'Inactive',
                              },
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
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AdminSearchField(
                          controller: _searchController,
                          hintText: 'Search by name, username, or email...',
                          width: 320,
                          onSubmitted: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _query = _searchController.text
                                .trim()
                                .toLowerCase(),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: const Text('Search'),
                        ),
                        OutlinedButton.icon(
                          onPressed: provider.loadUsers,
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
                  child: AdminTableSurface(
                    child: _buildContent(provider, users),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(UserProvider provider, List<User> users) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return _UserMessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Users are unavailable',
        message: provider.errorMessage!,
        actionLabel: 'Try again',
        onAction: provider.loadUsers,
      );
    }
    if (users.isEmpty) {
      return const _UserMessageState(
        icon: Icons.people_outline_rounded,
        title: 'No users found',
        message: 'Adjust the search or status filter.',
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
              dataRowMinHeight: 66,
              dataRowMaxHeight: 74,
              columnSpacing: 34,
              columns: const [
                DataColumn(label: Text('USER')),
                DataColumn(label: Text('JOIN DATE')),
                DataColumn(label: Text('ROLE')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: users.map(_buildRow).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(User user) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: PadelColors.blue,
                foregroundColor: Colors.white,
                child: Text(
                  _initials(user.displayName),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: PadelSpacing.sm),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email.isEmpty ? '@${user.username}' : user.email,
                    style: const TextStyle(
                      color: PadelColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(Text(_date(user.createdAt))),
        DataCell(
          Text(user.roleNames.isEmpty ? 'Member' : user.roleNames.join(', ')),
        ),
        DataCell(
          AdminStatusBadge(
            label: user.isActive ? 'Active' : 'Inactive',
            tone: user.isActive
                ? AdminStatusTone.success
                : AdminStatusTone.danger,
            showDot: true,
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'View user details',
                onPressed: () => _showUser(user),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: user.isActive
                    ? Icons.person_off_outlined
                    : Icons.person_add_alt_rounded,
                tooltip: user.isActive ? 'Deactivate user' : 'Activate user',
                onPressed: () => _showStatusNotice(user),
                destructive: user.isActive,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<User> _applyFilters(List<User> users) {
    return users
        .where((user) {
          final matchesStatus = switch (_filter) {
            _UserFilter.all => true,
            _UserFilter.active => user.isActive,
            _UserFilter.inactive => !user.isActive,
          };
          final haystack = [
            user.displayName,
            user.username,
            user.email,
            ...user.roleNames,
          ].join(' ').toLowerCase();
          return matchesStatus && (_query.isEmpty || haystack.contains(_query));
        })
        .toList(growable: false);
  }

  void _showUser(User user) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.displayName),
        content: Text(
          'Username: ${user.username}\nEmail: ${user.email}\nRoles: '
          '${user.roleNames.isEmpty ? 'Member' : user.roleNames.join(', ')}',
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

  void _showAddUserNotice() => _showNotice(
    'User creation will be connected when the account form phase is added.',
  );

  void _showStatusNotice(User user) => _showNotice(
    '${user.isActive ? 'Deactivation' : 'Activation'} requires the account '
    'edit endpoint and will be connected with the user form.',
  );

  void _showNotice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UserMessageState extends StatelessWidget {
  const _UserMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PadelSpacing.xl),
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
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: PadelSpacing.md),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _date(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '—';
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
