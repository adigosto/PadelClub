import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/memberships/data/admin_membership_remote_data_source.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_type_reference.dart';

/// Server-backed state for the administrator's membership work queue.
///
/// Changes are followed by an explicit reload so the displayed lifecycle and
/// date are always the server's post-operation values.
class MembershipManagementProvider extends ChangeNotifier {
  MembershipManagementProvider(this._dataSource);

  factory MembershipManagementProvider.live() =>
      MembershipManagementProvider(AdminMembershipRemoteDataSourceImpl());

  static const pageSize = 20;

  final AdminMembershipRemoteDataSource _dataSource;

  List<Membership> _memberships = const [];
  int? _totalCount;
  int _page = 1;
  String _membershipType = '';
  List<MembershipTypeReference> _membershipTypes = const [];
  int? _membershipTypeReferenceId;
  bool? _isActive;
  bool _isLoading = false;
  int? _actionMembershipId;
  int? _historyMembershipId;
  String? _errorMessage;
  String? _lastOperationMessage;

  List<Membership> get memberships => List.unmodifiable(_memberships);
  int? get totalCount => _totalCount;
  int get page => _page;
  String get membershipType => _membershipType;
  List<MembershipTypeReference> get membershipTypes =>
      List.unmodifiable(_membershipTypes);
  int? get membershipTypeReferenceId => _membershipTypeReferenceId;
  bool? get isActive => _isActive;
  bool get isLoading => _isLoading;
  bool get isActionInProgress => _actionMembershipId != null;
  int? get actionMembershipId => _actionMembershipId;
  int? get historyMembershipId => _historyMembershipId;
  String? get errorMessage => _errorMessage;
  String? get lastOperationMessage => _lastOperationMessage;
  bool isActingOn(int membershipId) => _actionMembershipId == membershipId;
  bool isLoadingHistory(int membershipId) =>
      _historyMembershipId == membershipId;
  bool get canGoPrevious => _page > 1;
  bool get canGoNext => _totalCount != null
      ? _page * pageSize < _totalCount!
      : _memberships.length == pageSize;

  Future<void> load({
    int page = 1,
    String? membershipType,
    bool? isActive,
    int? membershipTypeReferenceId,
  }) async {
    if (_isLoading || isActionInProgress || _historyMembershipId != null) {
      return;
    }
    _page = page < 1 ? 1 : page;
    _membershipType = membershipType?.trim() ?? '';
    _membershipTypeReferenceId = membershipTypeReferenceId;
    _isActive = isActive;
    // A different server page/filter must never be represented by stale rows
    // from the previous criteria while the new request is in flight.
    _memberships = const [];
    _totalCount = null;
    await _loadCurrent();
  }

  Future<void> refresh() =>
      load(
        page: _page,
        membershipType: _membershipType,
        membershipTypeReferenceId: _membershipTypeReferenceId,
        isActive: _isActive,
      );

  Future<void> loadMembershipTypes() async {
    try {
      _membershipTypes = List.unmodifiable(
        await _dataSource.getMembershipTypes(),
      );
      notifyListeners();
    } catch (error) {
      _errorMessage = _message(error);
      notifyListeners();
    }
  }

  Future<void> nextPage() {
    if (!canGoNext) return Future.value();
    return load(
      page: _page + 1,
      membershipType: _membershipType,
      membershipTypeReferenceId: _membershipTypeReferenceId,
      isActive: _isActive,
    );
  }

  Future<void> previousPage() {
    if (!canGoPrevious) return Future.value();
    return load(
      page: _page - 1,
      membershipType: _membershipType,
      membershipTypeReferenceId: _membershipTypeReferenceId,
      isActive: _isActive,
    );
  }

  Future<bool> changeStatus({
    required int membershipId,
    required MembershipLifecycleStatus status,
    String? notes,
  }) => _runAction(
    membershipId: membershipId,
    successLabel: 'Membership status updated',
    action: () => _dataSource.changeStatus(
      membershipId: membershipId,
      status: status,
      notes: notes,
    ),
  );

  Future<bool> renewMembership({
    required int membershipId,
    required int months,
  }) {
    if (months < 1 || months > 24) {
      _errorMessage = 'Choose a renewal period between 1 and 24 months.';
      notifyListeners();
      return Future.value(false);
    }
    return _runAction(
      membershipId: membershipId,
      successLabel:
          'Membership record renewed for $months month${months == 1 ? '' : 's'}',
      action: () => _dataSource.renewMembership(
        membershipId: membershipId,
        months: months,
      ),
    );
  }

  Future<List<MembershipEvent>?> loadHistory(int membershipId) async {
    if (_isLoading || isActionInProgress || _historyMembershipId != null) {
      return null;
    }
    _historyMembershipId = membershipId;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _dataSource.getHistory(membershipId);
    } catch (error) {
      _errorMessage = _message(error);
      return null;
    } finally {
      _historyMembershipId = null;
      notifyListeners();
    }
  }

  Future<void> _loadCurrent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _dataSource.getMemberships(
        page: _page,
        pageSize: pageSize,
        membershipType: _membershipType,
        membershipTypeReferenceId: _membershipTypeReferenceId,
        isActive: _isActive,
      );
      _memberships = List.unmodifiable(page.items);
      _totalCount = page.totalCount;
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _runAction({
    required int membershipId,
    required String successLabel,
    required Future<void> Function() action,
  }) async {
    if (_isLoading || isActionInProgress || _historyMembershipId != null) {
      _errorMessage = 'Wait for the current membership operation to finish.';
      notifyListeners();
      return false;
    }
    _actionMembershipId = membershipId;
    _errorMessage = null;
    _lastOperationMessage = null;
    notifyListeners();
    try {
      await action();
      try {
        final page = await _dataSource.getMemberships(
          page: _page,
          pageSize: pageSize,
          membershipType: _membershipType,
          membershipTypeReferenceId: _membershipTypeReferenceId,
          isActive: _isActive,
        );
        _memberships = List.unmodifiable(page.items);
        _totalCount = page.totalCount;
        _lastOperationMessage = '$successLabel and refreshed from the server.';
      } catch (error) {
        _lastOperationMessage =
            '$successLabel, but the latest list could not be refreshed: ${_message(error)}';
      }
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _actionMembershipId = null;
      notifyListeners();
    }
  }

  String _message(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('ArgumentError: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
}
