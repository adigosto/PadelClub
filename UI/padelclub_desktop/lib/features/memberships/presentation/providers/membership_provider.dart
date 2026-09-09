import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/features/memberships/data/datasources/membership_remote_data_source.dart';
import 'package:padelclub_desktop/features/memberships/data/repositories/membership_repository_impl.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';
import 'package:padelclub_desktop/features/memberships/domain/repositories/membership_repository.dart';

/// State for the signed-in player's membership lifecycle.
///
/// Every read and mutation is owner-scoped by the API. The provider refreshes
/// after mutations instead of guessing a final status from the UI action.
class MembershipProvider extends ChangeNotifier {
  static const _defaultPageSize = 20;
  static const _pagingKeys = {'page', 'pagesize', 'includetotalcount'};

  MembershipProvider({
    MembershipRepository? repository,
    http.Client? client,
    String? baseUrl,
    MembershipHeadersProvider? headersProvider,
  }) : _repository =
           repository ??
           MembershipRepositoryImpl(
             remoteDataSource: MembershipRemoteDataSourceImpl(
               client: client,
               baseUrl: baseUrl,
               headersProvider: headersProvider,
             ),
           );

  final MembershipRepository _repository;
  final Map<int, List<MembershipEvent>> _historyByMembership = {};

  List<Membership> _memberships = const [];
  int? _totalCount;
  bool _isLoading = false;
  bool _isActionInProgress = false;
  int? _loadingHistoryMembershipId;
  String? _errorMessage;
  Map<String, dynamic> _activeFilter = const {
    'Page': 1,
    'PageSize': _defaultPageSize,
    'IncludeTotalCount': true,
  };

  List<Membership> get memberships => List.unmodifiable(_memberships);
  int? get totalCount => _totalCount;
  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;
  bool get hasMoreMemberships =>
      _totalCount != null && _memberships.length < _totalCount!;

  bool isLoadingHistory(int membershipId) =>
      _loadingHistoryMembershipId == membershipId;

  List<MembershipEvent> historyFor(int membershipId) =>
      List.unmodifiable(_historyByMembership[membershipId] ?? const []);

  Future<void> load({Map<String, dynamic>? filter}) async {
    if (_isLoading || _isActionInProgress) return;
    _activeFilter = _firstPageFilter(filter);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _reload();
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> scheduleCancellation(int membershipId) => _runAction(() async {
    await _repository.cancelAtPeriodEnd(membershipId);
    await _reload();
  });

  Future<bool> updateAutoRenew({
    required int membershipId,
    required bool enabled,
  }) => _runAction(() async {
    await _repository.setAutoRenew(membershipId, enabled);
    await _reload();
  });

  Future<List<MembershipEvent>?> loadHistory(int membershipId) async {
    if (_loadingHistoryMembershipId != null || _isActionInProgress) return null;
    _loadingHistoryMembershipId = membershipId;
    _errorMessage = null;
    notifyListeners();
    try {
      final events = await _repository.getHistory(membershipId);
      _historyByMembership[membershipId] = List.unmodifiable(events);
      return events;
    } catch (error) {
      _errorMessage = _message(error);
      return null;
    } finally {
      _loadingHistoryMembershipId = null;
      notifyListeners();
    }
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    if (_isLoading || _isActionInProgress) return false;
    _isActionInProgress = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    final page = await _repository.getMyMemberships(filter: _activeFilter);
    _memberships = List.unmodifiable(page.items);
    _totalCount = page.totalCount;
  }

  Map<String, dynamic> _firstPageFilter(Map<String, dynamic>? filter) {
    final criteria = <String, dynamic>{};
    filter?.forEach((key, value) {
      if (!_pagingKeys.contains(key.toLowerCase())) criteria[key] = value;
    });
    return Map.unmodifiable({
      ...criteria,
      // The screen is intentionally a bounded first page for now. Always ask
      // for a total so it can say so clearly rather than silently hiding
      // older membership records.
      'Page': 1,
      'PageSize': _defaultPageSize,
      'IncludeTotalCount': true,
    });
  }

  String _message(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
}
