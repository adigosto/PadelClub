import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/operations/data/audit_trail_remote_data_source.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/audit_log_entry.dart';
import 'package:padelclub_desktop/features/operations/domain/entities/audit_trail_filter.dart';

/// Holds the latest read-only audit snapshot for the current server filters.
class AuditTrailProvider extends ChangeNotifier {
  AuditTrailProvider(this._dataSource);

  factory AuditTrailProvider.live() =>
      AuditTrailProvider(AuditTrailRemoteDataSourceImpl());

  final AuditTrailRemoteDataSource _dataSource;

  List<AuditLogEntry> _entries = const [];
  AuditTrailFilter _activeFilter = const AuditTrailFilter();
  bool _isLoading = false;
  String? _errorMessage;

  List<AuditLogEntry> get entries => List.unmodifiable(_entries);
  AuditTrailFilter get activeFilter => _activeFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({
    AuditTrailFilter filter = const AuditTrailFilter(),
  }) async {
    if (_isLoading) return;

    _activeFilter = filter.normalized();
    _isLoading = true;
    _entries = const [];
    _errorMessage = null;
    notifyListeners();
    try {
      _entries = List.unmodifiable(
        await _dataSource.getAuditEntries(filter: _activeFilter),
      );
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
