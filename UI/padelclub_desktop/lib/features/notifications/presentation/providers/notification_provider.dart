import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:padelclub_desktop/features/notifications/domain/entities/club_notification.dart';
import 'package:padelclub_desktop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:padelclub_desktop/features/notifications/domain/usecases/notification_usecases.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  NotificationProvider(this.repository, {this.pollInterval = const Duration(seconds: 15)}) {
    WidgetsBinding.instance.addObserver(this);
  }
  final NotificationRepository repository;
  final Duration pollInterval;
  List<ClubNotification> notifications = const [];
  bool isLoading = false;
  String? errorMessage;
  Timer? _timer;
  Future<void>? _inFlight;
  int? _userId;
  bool _admin = false;
  bool _active = true;
  bool _disposed = false;
  int _generation = 0;

  void setSession(int? userId, bool admin) {
    if (_userId == userId && _admin == admin) return;
    _generation++;
    _userId = userId;
    _admin = admin;
    _timer?.cancel();
    notifications = const [];
    errorMessage = null;
    isLoading = false;
    final generation = _generation;
    scheduleMicrotask(() {
      if (_disposed || generation != _generation) return;
      notifyListeners();
      if (_userId != null) unawaited(_refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _timer?.cancel();
    if (_active) unawaited(_refresh());
  }

  Future<void> loadAdminNotifications() => _loadMode(true);
  Future<void> loadMine() => _loadMode(false);
  Future<void> _loadMode(bool admin) {
    if (_admin != admin) { _admin = admin; _generation++; }
    return _refresh();
  }
  Future<void> _refresh() async {
    if (_disposed || !_active || _userId == null) return;
    if (_inFlight != null) {
      await _inFlight;
      return;
    }
    _timer?.cancel();
    final generation = _generation;
    final admin = _admin;
    final future = _fetch(generation, admin);
    _inFlight = future;
    try { await future; }
    finally {
      _inFlight = null;
      if (!_disposed && _active && _userId != null) {
        _timer = Timer(generation == _generation ? pollInterval : Duration.zero, () => unawaited(_refresh()));
      }
    }
  }
  Future<void> _fetch(int generation, bool admin) async {
    isLoading = notifications.isEmpty;
    notifyListeners();
    try {
      final values = await LoadNotifications(repository)(admin);
      if (_disposed || generation != _generation) return;
      notifications = values;
      errorMessage = null;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!_disposed && generation == _generation) { isLoading = false; notifyListeners(); }
    }
  }
  Future<bool> createNotification({required String title, required String message, required String type, List<int> recipientUserIds = const []}) =>
      _mutate(() => CreateNotification(repository)(title, message, type, recipientUserIds));
  Future<bool> updateNotification(ClubNotification n) => _mutate(() => UpdateNotification(repository)(n));
  Future<bool> deleteNotification(int id) => _mutate(() => DeleteNotification(repository)(id));
  Future<bool> markRead(int id) => _mutate(() => MarkNotificationsRead(repository)(id));
  Future<bool> markAllRead() => _mutate(() => MarkNotificationsRead(repository)(null));
  Future<bool> _mutate(Future<void> Function() action) async {
    final generation = _generation;
    try {
      await action();
      if (_disposed || generation != _generation) return false;
      if (_inFlight != null) await _inFlight;
      await _refresh();
      return true;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
        notifyListeners();
      }
      return false;
    }
  }
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    repository.dispose();
    super.dispose();
  }
}
