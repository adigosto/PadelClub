import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/core/widgets/admin_components.dart';
import 'package:padelclub_desktop/features/courts/domain/entities/court.dart';
import 'package:padelclub_desktop/features/courts/presentation/providers/court_provider.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class CourtManagementScreen extends StatefulWidget {
  const CourtManagementScreen({super.key});

  @override
  State<CourtManagementScreen> createState() => _CourtManagementScreenState();
}

class _CourtManagementScreenState extends State<CourtManagementScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CourtProvider>().loadCourts(),
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
      title: 'Court Management',
      section: AppSection.courts,
      child: Consumer<CourtProvider>(
        builder: (context, provider, _) {
          final courts = _filtered(provider.courts);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: 'Court Management',
                subtitle:
                    'Manage padel courts, availability, pricing, and maintenance.',
                action: FilledButton.icon(
                  onPressed: () => _showCourtForm(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Court'),
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
                                'Available',
                                'Indoor',
                                'Outdoor',
                                'Maintenance',
                              ]
                              .map(
                                (filter) => AdminFilterChip(
                                  label: filter == 'All'
                                      ? 'All Courts'
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
                          hintText: 'Search courts...',
                          width: 320,
                          onSubmitted: _setQuery,
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _setQuery(_searchController.text),
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: const Text('Search'),
                        ),
                        OutlinedButton.icon(
                          onPressed: provider.loadCourts,
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
                  child: AdminTableSurface(child: _content(provider, courts)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(CourtProvider provider, List<Court> courts) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return _CourtMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Courts are unavailable',
        message: provider.errorMessage!,
        onRetry: provider.loadCourts,
      );
    }
    if (courts.isEmpty) {
      return const _CourtMessage(
        icon: Icons.stadium_outlined,
        title: 'No courts found',
        message: 'Adjust the search or court filter.',
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
              columnSpacing: 36,
              columns: const [
                DataColumn(label: Text('COURT')),
                DataColumn(label: Text('TYPE')),
                DataColumn(label: Text('RATE')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: courts.map(_row).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(Court court) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: court.isIndoor
                      ? PadelColors.blueSoft
                      : PadelColors.greenSoft,
                  borderRadius: BorderRadius.circular(PadelRadii.medium),
                ),
                child: Icon(
                  court.isIndoor
                      ? Icons.stadium_rounded
                      : Icons.wb_sunny_outlined,
                  color: court.isIndoor
                      ? PadelColors.blue
                      : PadelColors.greenDark,
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
                      court.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${court.description} · Up to ${court.maxPlayers} players',
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
            label: court.isIndoor ? 'Indoor' : 'Outdoor',
            tone: court.isIndoor
                ? AdminStatusTone.info
                : AdminStatusTone.success,
          ),
        ),
        DataCell(
          Text(
            '${court.hourlyRate.toStringAsFixed(2)} KM/h',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(
          AdminStatusBadge(
            label: court.isActive ? 'Available' : 'Maintenance',
            tone: court.isActive
                ? AdminStatusTone.success
                : AdminStatusTone.warning,
            showDot: true,
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit court',
                onPressed: () => _showCourtForm(court),
              ),
              const SizedBox(width: PadelSpacing.xs),
              AdminActionButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete court',
                onPressed: () => _confirmDelete(court),
                destructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Court> _filtered(List<Court> courts) {
    return courts
        .where((court) {
          final matchesFilter = switch (_filter) {
            'Available' => court.isActive,
            'Indoor' => court.isIndoor,
            'Outdoor' => !court.isIndoor,
            'Maintenance' => !court.isActive,
            _ => true,
          };
          final haystack =
              '${court.name} ${court.description} '
                      '${court.isIndoor ? 'indoor' : 'outdoor'}'
                  .toLowerCase();
          return matchesFilter && (_query.isEmpty || haystack.contains(_query));
        })
        .toList(growable: false);
  }

  void _setQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  Future<void> _showCourtForm([Court? court]) async {
    final result = await showDialog<_CourtDraft>(
      context: context,
      builder: (_) => _CourtFormDialog(court: court),
    );
    if (result == null || !mounted) return;
    final provider = context.read<CourtProvider>();
    final saved = await provider.saveCourt(
      id: court?.id,
      name: result.name,
      description: result.description,
      isIndoor: result.isIndoor,
      isActive: result.isActive,
      hourlyRate: result.hourlyRate,
      maxPlayers: result.maxPlayers,
    );
    if (!mounted) return;
    _notice(
      saved
          ? 'Court saved.'
          : provider.errorMessage ?? 'Court could not be saved.',
    );
  }

  Future<void> _confirmDelete(Court court) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete court?'),
        content: Text(
          'Delete ${court.name}? Existing reservation history may prevent this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep court'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<CourtProvider>();
    final deleted = await provider.deleteCourt(court.id);
    if (!mounted) return;
    _notice(
      deleted
          ? 'Court deleted.'
          : provider.errorMessage ?? 'Court could not be deleted.',
    );
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CourtDraft {
  const _CourtDraft({
    required this.name,
    required this.description,
    required this.isIndoor,
    required this.isActive,
    required this.hourlyRate,
    required this.maxPlayers,
  });

  final String name;
  final String description;
  final bool isIndoor;
  final bool isActive;
  final double hourlyRate;
  final int maxPlayers;
}

class _CourtFormDialog extends StatefulWidget {
  const _CourtFormDialog({this.court});

  final Court? court;

  @override
  State<_CourtFormDialog> createState() => _CourtFormDialogState();
}

class _CourtFormDialogState extends State<_CourtFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _rate;
  late final TextEditingController _players;
  late bool _isIndoor;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final court = widget.court;
    _name = TextEditingController(text: court?.name ?? '');
    _description = TextEditingController(text: court?.description ?? '');
    _rate = TextEditingController(
      text: court?.hourlyRate.toStringAsFixed(2) ?? '',
    );
    _players = TextEditingController(text: '${court?.maxPlayers ?? 4}');
    _isIndoor = court?.isIndoor ?? true;
    _isActive = court?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rate.dispose();
    _players.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.court == null ? 'Add court' : 'Edit court'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Court name'),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Enter a court name'
                      : null,
                ),
                const SizedBox(height: PadelSpacing.sm),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: PadelSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rate,
                        decoration: const InputDecoration(
                          labelText: 'Hourly rate (KM)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            double.tryParse(value ?? '') == null
                            ? 'Enter a valid rate'
                            : null,
                      ),
                    ),
                    const SizedBox(width: PadelSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _players,
                        decoration: const InputDecoration(
                          labelText: 'Max players',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => int.tryParse(value ?? '') == null
                            ? 'Enter a number'
                            : null,
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Indoor court'),
                  value: _isIndoor,
                  onChanged: (value) => setState(() => _isIndoor = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for booking'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save court')),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _CourtDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
        isIndoor: _isIndoor,
        isActive: _isActive,
        hourlyRate: double.parse(_rate.text),
        maxPlayers: int.parse(_players.text),
      ),
    );
  }
}

class _CourtMessage extends StatelessWidget {
  const _CourtMessage({
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
