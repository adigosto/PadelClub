import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';

class AuthProvider extends ChangeNotifier {
  static const savedSessionPlaceholder = '••••••••••••';
  static const _storage = FlutterSecureStorage();
  static const _usernameKey = 'padelclub_username';
  static const _refreshTokenKey = 'padelclub_refresh_token';
  static String? username;
  static String? accessToken;
  static String? refreshToken;
  static List<String> currentRoles = const [];
  static bool get currentUserIsAdministrator => currentRoles.any(
    (role) =>
        role.toLowerCase() == 'administrator' || role.toLowerCase() == 'admin',
  );

  int? userId;
  String? firstName;
  String? lastName;
  String? email;
  String? phoneNumber;
  bool isEmailVerified = false;
  List<String> roles = const [];
  bool isLoading = false;
  String? errorMessage;
  Timer? _refreshTimer;

  bool get isAuthenticated => userId != null;
  bool get isAdministrator => roles.any(
    (role) =>
        role.toLowerCase() == 'administrator' || role.toLowerCase() == 'admin',
  );
  String get displayName =>
      [firstName, lastName].where((x) => x?.isNotEmpty == true).join(' ');

  Future<bool> login(
    String enteredUsername,
    String enteredPassword, {
    bool rememberMe = false,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/Users/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': enteredUsername,
              'password': enteredPassword,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        errorMessage = response.statusCode == 401
            ? 'Invalid username or password.'
            : 'Sign in is currently unavailable.';
        return false;
      }

      final session = jsonDecode(response.body) as Map<String, dynamic>;
      final data = session['user'] as Map<String, dynamic>;
      username = enteredUsername;
      accessToken = session['accessToken'] as String;
      refreshToken = session['refreshToken'] as String;
      userId = data['id'] as int?;
      firstName = data['firstName'] as String?;
      lastName = data['lastName'] as String?;
      email = data['email'] as String?;
      phoneNumber = data['phoneNumber'] as String?;
      isEmailVerified = data['isEmailVerified'] as bool? ?? false;
      roles = (data['roles'] as List<dynamic>? ?? const [])
          .map((role) => (role as Map<String, dynamic>)['name'] as String)
          .toList(growable: false);
      currentRoles = roles;
      _scheduleRefresh();
      try {
        if (rememberMe) {
          await _storage.write(key: _usernameKey, value: enteredUsername);
          await _storage.write(key: _refreshTokenKey, value: refreshToken);
        } else {
          await clearRememberedLogin();
        }
      } catch (error) {
        debugPrint('Could not update saved login information: $error');
      }
      return true;
    } catch (error) {
      debugPrint('Login request to ${ApiConfig.baseUrl} failed: $error');
      errorMessage =
          'Could not connect to PadelClub at ${ApiConfig.baseUrl}. Check the selected device and API address.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreRememberedLogin() async {
    final savedUsername = await _storage.read(key: _usernameKey);
    final savedRefreshToken = await _storage.read(key: _refreshTokenKey);
    if (savedUsername == null || savedRefreshToken == null) return false;
    return _restoreSession(savedUsername, savedRefreshToken);
  }

  Future<({String username, String password})?> rememberedLogin() async {
    try {
      final savedUsername = await _storage.read(key: _usernameKey);
      final savedRefreshToken = await _storage.read(key: _refreshTokenKey);
      if (savedUsername == null || savedRefreshToken == null) return null;
      return (username: savedUsername, password: savedSessionPlaceholder);
    } catch (error) {
      debugPrint('Could not read saved login information: $error');
      return null;
    }
  }

  Future<void> clearRememberedLogin() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> updateProfile({
    required String newUsername,
    required String newEmail,
    required String newFirstName,
    required String newLastName,
    String? newPhoneNumber,
    String? newPassword,
  }) async {
    errorMessage = null;
    isLoading = true;
    notifyListeners();
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/Users/me'),
        headers: authenticatedHeaders(),
        body: jsonEncode({
          'username': newUsername,
          'email': newEmail,
          'firstName': newFirstName,
          'lastName': newLastName,
          'phoneNumber': newPhoneNumber,
          'newPassword': newPassword,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          response.body.trim().isEmpty
              ? 'Profile could not be updated.'
              : response.body.replaceAll('"', ''),
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      username = newUsername;
      firstName = data['firstName'] as String?;
      lastName = data['lastName'] as String?;
      email = data['email'] as String?;
      phoneNumber = data['phoneNumber'] as String?;
      isEmailVerified = data['isEmailVerified'] as bool? ?? false;
      final remembered = await _storage.read(key: _usernameKey);
      if (remembered != null) {
        await _storage.write(key: _usernameKey, value: username);
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      }
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  static Map<String, String> authenticatedHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Future<bool> requestEmailVerification() async {
    errorMessage = null;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/Users/request-email-verification'),
        headers: authenticatedHeaders(),
      );
      if (response.statusCode == 200 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        return true;
      }
      errorMessage = 'The verification email could not be sent.';
      return false;
    } catch (error) {
      errorMessage = 'Could not connect to PadelClub.';
      return false;
    }
  }

  Future<bool> verifyEmail(String token) async {
    errorMessage = null;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/Users/verify-email'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token.trim()}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        errorMessage = 'The verification code is invalid or expired.';
        return false;
      }
      final savedUsername = username;
      final savedRefreshToken = refreshToken;
      if (savedUsername != null && savedRefreshToken != null) {
        return _restoreSession(savedUsername, savedRefreshToken);
      }
      isEmailVerified = true;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = 'Email verification could not be completed.';
      return false;
    }
  }

  Future<void> logout() async {
    final token = refreshToken;
    if (token != null && accessToken != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/Users/logout'),
          headers: authenticatedHeaders(),
          body: jsonEncode({'refreshToken': token}),
        );
      } catch (_) {}
    }
    await clearRememberedLogin();
    username = null;
    accessToken = null;
    refreshToken = null;
    _refreshTimer?.cancel();
    userId = null;
    firstName = null;
    lastName = null;
    email = null;
    phoneNumber = null;
    isEmailVerified = false;
    roles = const [];
    currentRoles = const [];
    notifyListeners();
  }

  Future<bool> _restoreSession(
    String savedUsername,
    String savedRefreshToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/Users/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': savedRefreshToken}),
      );
      if (response.statusCode != 200) {
        await clearRememberedLogin();
        return false;
      }
      final session = jsonDecode(response.body) as Map<String, dynamic>;
      final data = session['user'] as Map<String, dynamic>;
      username = savedUsername;
      accessToken = session['accessToken'] as String;
      refreshToken = session['refreshToken'] as String;
      userId = data['id'] as int?;
      firstName = data['firstName'] as String?;
      lastName = data['lastName'] as String?;
      email = data['email'] as String?;
      phoneNumber = data['phoneNumber'] as String?;
      isEmailVerified = data['isEmailVerified'] as bool? ?? false;
      roles = (data['roles'] as List<dynamic>? ?? const [])
          .map((role) => (role as Map<String, dynamic>)['name'] as String)
          .toList(growable: false);
      currentRoles = roles;
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      _scheduleRefresh();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(minutes: 12), () async {
      final currentUsername = username;
      final currentRefreshToken = refreshToken;
      if (currentUsername == null || currentRefreshToken == null) return;
      final restored = await _restoreSession(
        currentUsername,
        currentRefreshToken,
      );
      if (!restored) await logout();
    });
  }
}
