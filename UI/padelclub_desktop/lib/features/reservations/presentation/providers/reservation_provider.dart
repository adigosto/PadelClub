import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/reservations/data/models/reservation_model.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/account_credit.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/court_availability.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/waitlist_entry.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

typedef ReservationHeadersProvider = Map<String, String> Function();

class ReservationProvider extends ChangeNotifier {
  ReservationProvider({
    http.Client? client,
    String? baseUrl,
    ReservationHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final http.Client _client;
  final String _baseUrl;
  final ReservationHeadersProvider _headersProvider;

  List<CourtAvailability> availability = const [];
  List<Reservation> reservations = const [];
  List<WaitlistEntry> waitlistEntries = const [];
  List<AccountCredit> accountCredits = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadAvailability(DateTime date) async {
    await _run(() async {
      final uri = Uri.parse('$_baseUrl/Reservations/availability').replace(
        queryParameters: {
          'date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        },
      );
      final response = await _client.get(uri, headers: _headersProvider());
      _ensureSuccess(response);
      final data = jsonDecode(response.body) as List<dynamic>;
      availability = data
          .map((item) {
            final json = item as Map<String, dynamic>;
            return CourtAvailability(
              courtId: json['courtId'] as int,
              courtName: json['courtName'] as String,
              isIndoor: json['isIndoor'] as bool,
              maxPlayers: json['maxPlayers'] as int,
              hourlyRate: (json['hourlyRate'] as num).toDouble(),
              slots: (json['slots'] as List<dynamic>)
                  .map((slotItem) {
                    final slot = slotItem as Map<String, dynamic>;
                    return AvailabilitySlot(
                      startTime: DateTime.parse(
                        slot['startTime'] as String,
                      ).toLocal(),
                      endTime: DateTime.parse(
                        slot['endTime'] as String,
                      ).toLocal(),
                      price: (slot['price'] as num).toDouble(),
                      isAvailable: slot['isAvailable'] as bool,
                      isWaitlistEligible:
                          slot['isWaitlistEligible'] as bool? ?? false,
                    );
                  })
                  .toList(growable: false),
            );
          })
          .toList(growable: false);
    });
  }

  Future<void> loadReservations({required bool management}) async {
    await _run(() async {
      reservations = await _fetchReservations(management: management);
    });
  }

  /// Refreshes the complete player-facing booking lifecycle in one request group.
  Future<void> loadMyBookingActivity() async {
    await _run(() async {
      final reservationsFuture = _fetchReservations(management: false);
      final waitlistFuture = _fetchWaitlist();
      final creditsFuture = _fetchCredits();
      reservations = await reservationsFuture;
      waitlistEntries = await waitlistFuture;
      accountCredits = await creditsFuture;
    });
  }

  Future<bool> book({
    required int courtId,
    required AvailabilitySlot slot,
  }) async {
    return _runWithResult(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/Reservations'),
        headers: _headersProvider(),
        body: jsonEncode({
          'courtId': courtId,
          'startTime': slot.startTime.toUtc().toIso8601String(),
          'endTime': slot.endTime.toUtc().toIso8601String(),
        }),
      );
      _ensureSuccess(response);
    });
  }

  Future<bool> cancel(int reservationId, {required String reason}) async {
    return _runWithResult(() async {
      final response = await _client.put(
        Uri.parse('$_baseUrl/Reservations/$reservationId/cancel'),
        headers: _headersProvider(),
        body: jsonEncode({'reason': reason.trim()}),
      );
      _ensureSuccess(response);
    });
  }

  /// Creates an administrator maintenance block. A null [courtId] blocks every
  /// active court for the selected interval, matching the API contract.
  Future<bool> addMaintenanceBlock({
    int? courtId,
    required DateTime startTime,
    required DateTime endTime,
    required String reason,
  }) async {
    return _runWithResult(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/Reservations/maintenance'),
        headers: _headersProvider(),
        body: jsonEncode({
          'courtId': courtId,
          'startTimeUtc': startTime.toUtc().toIso8601String(),
          'endTimeUtc': endTime.toUtc().toIso8601String(),
          'reason': reason.trim(),
        }),
      );
      _ensureSuccess(response);
    });
  }

  /// Records that a completed reservation was not attended by its player.
  Future<bool> markNoShow(int reservationId) async {
    return _runWithResult(() async {
      final response = await _client.put(
        Uri.parse('$_baseUrl/Reservations/$reservationId/no-show'),
        headers: _headersProvider(),
      );
      _ensureSuccess(response);
    });
  }

  Future<bool> bookRecurring({
    required int courtId,
    required AvailabilitySlot slot,
    required int weeks,
  }) async {
    return _runWithResult(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/Reservations/recurring'),
        headers: _headersProvider(),
        body: jsonEncode({
          'courtId': courtId,
          'startTime': slot.startTime.toUtc().toIso8601String(),
          'endTime': slot.endTime.toUtc().toIso8601String(),
          'weeks': weeks,
        }),
      );
      _ensureSuccess(response);
    });
  }

  Future<bool> joinWaitlist({
    required int courtId,
    required AvailabilitySlot slot,
  }) async {
    return _runWithResult(() async {
      final response = await _client.post(
        Uri.parse('$_baseUrl/Reservations/waitlist'),
        headers: _headersProvider(),
        body: jsonEncode({
          'courtId': courtId,
          'startTime': slot.startTime.toUtc().toIso8601String(),
          'endTime': slot.endTime.toUtc().toIso8601String(),
        }),
      );
      _ensureSuccess(response);
    });
  }

  Future<List<Reservation>> _fetchReservations({
    required bool management,
  }) async {
    final path = management ? '/Reservations' : '/Reservations/mine';
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: {'PageSize': '100', 'IncludeTotalCount': 'true'},
    );
    final response = await _client.get(uri, headers: _headersProvider());
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? const [])
        .map((item) => ReservationModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<List<WaitlistEntry>> _fetchWaitlist() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/Reservations/waitlist/mine'),
      headers: _headersProvider(),
    );
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) {
          final json = item as Map<String, dynamic>;
          return WaitlistEntry(
            id: json['id'] as int,
            courtId: json['courtId'] as int,
            courtName: json['courtName'] as String? ?? '',
            startTime: DateTime.parse(json['startTimeUtc'] as String).toLocal(),
            endTime: DateTime.parse(json['endTimeUtc'] as String).toLocal(),
            status: json['status'] as String,
            createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
          );
        })
        .toList(growable: false);
  }

  Future<List<AccountCredit>> _fetchCredits() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/Reservations/credits/mine'),
      headers: _headersProvider(),
    );
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) {
          final json = item as Map<String, dynamic>;
          final usedAt = json['usedAt'] as String?;
          return AccountCredit(
            id: json['id'] as int,
            reservationId: json['reservationId'] as int?,
            amount: (json['amount'] as num).toDouble(),
            reason: json['reason'] as String,
            createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
            usedAt: usedAt == null ? null : DateTime.parse(usedAt).toLocal(),
          );
        })
        .toList(growable: false);
  }

  Future<void> _run(Future<void> Function() operation) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _runWithResult(Future<void> Function() operation) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('You are not authorized to perform this action.');
    }
    final message = response.body.trim();
    throw Exception(
      message.isEmpty
          ? 'The request could not be completed.'
          : message.replaceAll('"', ''),
    );
  }
}
