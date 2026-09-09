import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/audit_log_entry.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/audit_trail_filter.dart';
import 'package:padelclub_desktop/features/operations/presentation/providers/audit_trail_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

/// Administrator workspace for inspecting immutable API request evidence.
///
/// All filtering is sent to the server. This screen deliberately offers no
/// audit mutations, export, or client-side persistence controls.
class AuditTrailScreen extends StatelessWidget {
  const AuditTrailScreen({super.key, this.provider});

  /// A test-only override. Production construction uses [AuditTrailProvider.live].
  final AuditTrailProvider? provider;

  @override
  Widget build(BuildContext context) {
    final value = provider;
    if (value != null) {
      return ChangeNotifierProvider<AuditTrailProvider>.value(
        value: value,
        child: const _AuditTrailContent(),
      );
    }
    return ChangeNotifierProvider<AuditTrailProvider>(
      create: (_) => AuditTrailProvider.live(),
      child: const _AuditTrailContent(),
    );
  }
}

class _AuditTrailContent extends StatefulWidget {
  const _AuditTrailContent();

  @override
  State<_AuditTrailContent> createState() => _AuditTrailContentState();
}

class _AuditTrailContentState extends State<_AuditTrailContent> {
  static const _methods = <String>['', 'POST', 'PUT', 'PATCH', 'DELETE'];

  final _userNameController = TextEditingController();
  final _methodFieldKey = GlobalKey<FormFieldState<String>>();
  String _method = '';
  DateTime? _fromUtc;
  String? _filterError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuditTrailProvider>().load();
    });
  }

  @override
  void dispose() {
    _userNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditTrailProvider>();
    return MasterScreen(
      title: context.tr("Audit Trail"),
      section: AppSection.auditTrail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: context.tr("Audit Trail"),
            subtitle: context.tr(
              "Review the server-recorded write-request history. Filters are applied by the API and the snapshot contains at most 1,000 events.",
            ),
            action: Wrap(
              spacing: PadelSpacing.sm,
              runSpacing: PadelSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: const Key('open-provider-readiness-button'),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/operations/provider-readiness',
                  ),
                  icon: const Icon(Icons.cloud_done_outlined, size: 18),
                  label: Text(context.tr("Provider readiness")),
                ),
                OutlinedButton.icon(
                  key: const Key('audit-refresh-button'),
                  onPressed: provider.isLoading ? null : _loadCurrentFilter,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.tr("Refresh")),
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
                  spacing: PadelSpacing.sm,
                  runSpacing: PadelSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 176,
                      child: TextField(
                        key: const Key('audit-user-name-filter'),
                        controller: _userNameController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: context.tr("User name"),
                          hintText: context.tr("All users"),
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        onSubmitted: (_) => _loadCurrentFilter(),
                      ),
                    ),
                    SizedBox(
                      width: 224,
                      child: DropdownButtonFormField<String>(
                        key: _methodFieldKey,
                        initialValue: _method,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.tr("Method"),
                          prefixIcon: Icon(Icons.http_rounded),
                        ),
                        items: _methods
                            .map(
                              (method) => DropdownMenuItem(
                                value: method,
                                child: Text(
                                  method.isEmpty ? context.tr("Any") : method,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: provider.isLoading
                            ? null
                            : (value) => setState(() => _method = value ?? ''),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('audit-from-filter'),
                      onPressed: provider.isLoading ? null : _pickFromDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 17),
                      label: Text(
                        _fromUtc == null
                            ? context.tr("From date (UTC)")
                            : context.tr("From {p1} UTC", {
                                'p1': _dateOnly(_fromUtc!),
                              }),
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('audit-apply-filters-button'),
                      onPressed: provider.isLoading ? null : _loadCurrentFilter,
                      icon: const Icon(Icons.filter_alt_rounded, size: 17),
                      label: Text(context.tr("Apply filters")),
                    ),
                    TextButton(
                      key: const Key('audit-clear-filters-button'),
                      onPressed: provider.isLoading || _filtersAreClear
                          ? null
                          : _clearFilters,
                      child: Text(context.tr("Clear filters")),
                    ),
                  ],
                ),
                if (_filterError != null) ...[
                  const SizedBox(height: PadelSpacing.sm),
                  Text(
                    _filterError!,
                    style: const TextStyle(
                      color: PadelColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: PadelSpacing.sm),
                Text(
                  _filterSummary(provider.activeFilter),
                  style: const TextStyle(
                    color: PadelColors.textMuted,
                    fontSize: 12,
                  ),
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
              child: AdminTableSurface(child: _content(provider)),
            ),
          ),
        ],
      ),
    );
  }

  bool get _filtersAreClear =>
      _userNameController.text.trim().isEmpty &&
      _method.isEmpty &&
      _fromUtc == null;

  void _loadCurrentFilter() {
    final filter = _readFilter();
    if (filter == null) return;
    context.read<AuditTrailProvider>().load(filter: filter);
  }

  AuditTrailFilter? _readFilter() {
    return AuditTrailFilter(
      userName: _userNameController.text.trim(),
      method: _method,
      from: _fromUtc,
    );
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromUtc ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: context.tr("Choose the first audit date (UTC)"),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _fromUtc = DateTime.utc(selected.year, selected.month, selected.day);
      _filterError = null;
    });
  }

  void _clearFilters() {
    _userNameController.clear();
    setState(() {
      _method = '';
      _fromUtc = null;
      _filterError = null;
    });
    _methodFieldKey.currentState?.didChange('');
    context.read<AuditTrailProvider>().load();
  }

  Widget _content(AuditTrailProvider provider) {
    if (provider.isLoading) {
      return Center(
        child: Semantics(
          label: context.tr("Loading audit trail"),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (provider.errorMessage != null) {
      return _AuditTrailMessage(
        icon: Icons.cloud_off_rounded,
        title: context.tr("Audit trail is unavailable"),
        message: provider.errorMessage!,
        actionLabel: context.tr("Try again"),
        onAction: _loadCurrentFilter,
      );
    }
    if (provider.entries.isEmpty) {
      return _AuditTrailMessage(
        icon: Icons.manage_search_outlined,
        title: context.tr("No audit events found"),
        message: provider.activeFilter.isEmpty
            ? context.tr("There are no recorded write requests yet.")
            : context.tr(
                "No server-recorded events match the current filters.",
              ),
        actionLabel: provider.activeFilter.isEmpty
            ? null
            : context.tr("Clear filters"),
        onAction: provider.activeFilter.isEmpty ? null : _clearFilters,
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
              dataRowMinHeight: 76,
              dataRowMaxHeight: 88,
              columnSpacing: 30,
              columns: [
                DataColumn(label: Text(context.tr("RECORDED (UTC)"))),
                DataColumn(label: Text(context.tr("REQUEST"))),
                DataColumn(label: Text(context.tr("OUTCOME"))),
                DataColumn(label: Text(context.tr("ACTOR"))),
                DataColumn(label: Text(context.tr("ACTIONS"))),
              ],
              rows: provider.entries.map(_row).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(AuditLogEntry entry) => DataRow(
    onSelectChanged: (_) => _showDetails(entry),
    cells: [
      DataCell(
        SizedBox(
          width: 148,
          child: Text(
            _dateTime(entry.createdAt),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
      DataCell(
        SizedBox(
          width: 370,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.method.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                entry.path,
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
          width: 132,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminStatusBadge(
                label: 'HTTP ${entry.statusCode}',
                tone: _statusTone(entry.statusCode),
              ),
              const SizedBox(height: 5),
              Text(
                '${entry.durationMs} ms',
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
          width: 156,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.userId == null
                    ? context.tr("Anonymous request")
                    : (entry.userName ?? context.tr('Unavailable user')),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                entry.ipAddress.isEmpty
                    ? context.tr("IP unavailable")
                    : entry.ipAddress,
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
      ),
      DataCell(
        AdminActionButton(
          icon: Icons.visibility_outlined,
          tooltip: context.tr("View audit event"),
          onPressed: () => _showDetails(entry),
        ),
      ),
    ],
  );

  void _showDetails(AuditLogEntry entry) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr("Audit event #{p1}", {'p1': entry.id})),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  context.tr("Recorded (UTC)"),
                  _dateTime(entry.createdAt),
                ),
                _detailRow(
                  context.tr("User"),
                  entry.userId == null
                      ? context.tr("Anonymous")
                      : (entry.userName ?? context.tr('Unavailable user')),
                ),
                _detailRow(context.tr("Method"), entry.method.toUpperCase()),
                _detailRow(context.tr("Path"), entry.path),
                _detailRow(context.tr("Status"), 'HTTP ${entry.statusCode}'),
                _detailRow(context.tr("Duration"), '${entry.durationMs} ms'),
                _detailRow(
                  context.tr("IP address"),
                  entry.ipAddress.isEmpty
                      ? context.tr("Unavailable")
                      : entry.ipAddress,
                ),
                _detailRow(
                  context.tr("Correlation ID"),
                  entry.correlationId.isEmpty
                      ? context.tr("Unavailable")
                      : entry.correlationId,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr("Close")),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              color: PadelColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );

  String _filterSummary(AuditTrailFilter filter) {
    if (filter.isEmpty) {
      return context.tr("Server filters: all recorded write requests.");
    }
    final fragments = <String>[
      if (filter.userName?.isNotEmpty == true) filter.userName!,
      if (filter.method != null) filter.method!,
      if (filter.from != null) 'from ${_dateOnly(filter.from!)} UTC',
    ];
    return context.tr("Server filters: {p1}.", {'p1': fragments.join(' · ')});
  }

  AdminStatusTone _statusTone(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return AdminStatusTone.success;
    if (statusCode >= 400 && statusCode < 500) return AdminStatusTone.warning;
    if (statusCode >= 500) return AdminStatusTone.danger;
    return AdminStatusTone.neutral;
  }

  String _dateTime(DateTime value) {
    final utc = value.toUtc();
    return '${_dateOnly(utc)} ${_twoDigits(utc.hour)}:${_twoDigits(utc.minute)}:${_twoDigits(utc.second)}';
  }

  String _dateOnly(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year}-${_twoDigits(utc.month)}-${_twoDigits(utc.day)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _AuditTrailMessage extends StatelessWidget {
  const _AuditTrailMessage({
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
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(PadelSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: PadelColors.blue),
            const SizedBox(height: PadelSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: PadelSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PadelColors.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: PadelSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}
