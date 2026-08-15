import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/reservations/data/models/reservation_model.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/court_availability.dart';
import 'package:padelclub_desktop/features/reservations/domain/entities/reservation.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class ReservationProvider extends ChangeNotifier {
  List<CourtAvailability> availability = const [];
  List<Reservation> reservations = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadAvailability(DateTime date) async {
    await _run(() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}/Reservations/availability')
          .replace(
            queryParameters: {
              'date':
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            },
          );
      final response = await http.get(
        uri,
        headers: AuthProvider.authenticatedHeaders(),
      );
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
      final path = management ? '/Reservations' : '/Reservations/mine';
      final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
        queryParameters: {'PageSize': '100', 'IncludeTotalCount': 'true'},
      );
      final response = await http.get(
        uri,
        headers: AuthProvider.authenticatedHeaders(),
      );
      _ensureSuccess(response);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      reservations =
          (body['items'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    ReservationModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false)
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  Future<bool> book({
    required int courtId,
    required AvailabilitySlot slot,
  }) async {
    return _runWithResult(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/Reservations'),
        headers: AuthProvider.authenticatedHeaders(),
        body: jsonEncode({
          'courtId': courtId,
          'userId': 0,
          'startTime': slot.startTime.toUtc().toIso8601String(),
          'endTime': slot.endTime.toUtc().toIso8601String(),
          'totalPrice': 0,
          'status': 'Confirmed',
        }),
      );
      _ensureSuccess(response);
    });
  }

  Future<bool> cancel(int reservationId) async {
    return _runWithResult(() async {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/Reservations/$reservationId/cancel'),
        headers: AuthProvider.authenticatedHeaders(),
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
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/Reservations/recurring'),
        headers: AuthProvider.authenticatedHeaders(),
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
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/Reservations/waitlist'),
        headers: AuthProvider.authenticatedHeaders(),
        body: jsonEncode({
          'courtId': courtId,
          'startTime': slot.startTime.toUtc().toIso8601String(),
          'endTime': slot.endTime.toUtc().toIso8601String(),
        }),
      );
      _ensureSuccess(response);
    });
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
