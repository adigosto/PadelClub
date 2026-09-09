import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/core/network/api_error.dart';
import 'package:padelclub_desktop/features/player_experience/domain/entities/player_city.dart';
import 'package:padelclub_desktop/features/player_experience/domain/usecases/get_cities.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

/// Owns the authenticated player journeys that need more than the public
/// discovery feed: profile onboarding, partners, invitations, personal
/// matches, and tournament participation.
///
/// The API remains the authorization boundary. This provider deliberately
/// never derives a player ID from a UI selection or submits a result for a
/// match the signed-in player does not own.
class PlayerExperienceProvider extends ChangeNotifier {
  PlayerExperienceProvider({
    GetCities? getCities,
    http.Client? client,
    String? baseUrl,
    Map<String, String> Function()? headersProvider,
    // ignore: prefer_initializing_formals
  }) : _getCities = getCities,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _headersProvider = headersProvider ?? AuthProvider.authenticatedHeaders;

  final GetCities? _getCities;
  Future<List<PlayerCity>> loadCities() async {
    final getCities = _getCities;
    if (getCities == null) throw StateError('City lookup is not configured.');
    return getCities();
  }

  final http.Client _client;
  final String _baseUrl;
  final Map<String, String> Function() _headersProvider;

  PlayerExperienceProfile? profile;
  List<PartnerCandidate> partners = const [];
  List<PartnerInvitation> invitations = const [];
  List<PlayerMatch> matches = const [];
  List<TournamentRegistration> registrations = const [];
  List<TournamentBracketMatch> bracket = const [];

  bool isLoading = false;
  bool isActionInProgress = false;
  bool isBracketLoading = false;
  String? errorMessage;
  String? actionErrorMessage;

  Future<void> load({String partnerQuery = ''}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final values = await Future.wait<dynamic>([
        _loadProfile(),
        _loadPartners(partnerQuery),
        _loadInvitations(),
        _loadMatches(),
        _loadRegistrations(),
      ]);
      profile = values[0] as PlayerExperienceProfile?;
      partners = values[1] as List<PartnerCandidate>;
      invitations = values[2] as List<PartnerInvitation>;
      matches = values[3] as List<PlayerMatch>;
      registrations = values[4] as List<TournamentRegistration>;
    } catch (error) {
      errorMessage = _displayError(
        error,
        'Player activity could not be loaded.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    required String skillLevel,
    required String preferredSide,
    required int cityId,
    required String bio,
    required String availability,
    required bool isDiscoverable,
  }) => _runAction(() async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/PlayerExperience/profile/mine'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'skillLevel': skillLevel,
        'preferredSide': preferredSide,
        'cityId': cityId,
        'bio': bio,
        'availability': availability,
        'isDiscoverable': isDiscoverable,
      }),
    );
    _requireSuccess(response, 'Player profile could not be saved.');
    profile = PlayerExperienceProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  });

  Future<bool> invitePartner(int recipientUserId, String message) =>
      _runAction(() async {
        final response = await _client.post(
          Uri.parse(
            '$_baseUrl/PlayerExperience/partners/$recipientUserId/invite',
          ),
          headers: _jsonHeaders(),
          body: jsonEncode({'message': message.trim()}),
        );
        _requireSuccess(response, 'The partner invitation could not be sent.');
        invitations = await _loadInvitations();
      });

  Future<bool> respondToPartnerInvitation(
    int invitationId,
    bool accept,
  ) => _runAction(() async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/PlayerExperience/invitations/$invitationId/respond'),
      headers: _jsonHeaders(),
      body: jsonEncode({'accept': accept}),
    );
    _requireSuccess(response, 'The invitation response could not be saved.');
    invitations = await _loadInvitations();
  });

  Future<bool> reportMatchResult({
    required int matchId,
    required String score,
    required int winnerTeamId,
  }) => _runAction(() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/PlayerExperience/matches/$matchId/result'),
      headers: _jsonHeaders(),
      body: jsonEncode({'score': score.trim(), 'winnerTeamId': winnerTeamId}),
    );
    _requireSuccess(response, 'The result could not be submitted.');
    matches = await _loadMatches();
  });

  Future<bool> confirmMatchResult(int matchId) => _runAction(() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/PlayerExperience/matches/$matchId/confirm'),
      headers: _jsonHeaders(),
    );
    _requireSuccess(response, 'The result could not be confirmed.');
    matches = await _loadMatches();
  });

  Future<bool> registerTournament({
    required int tournamentId,
    required int partnerUserId,
  }) => _runAction(() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/Tournaments/$tournamentId/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({'partnerUserId': partnerUserId}),
    );
    _requireSuccess(
      response,
      'Tournament registration could not be completed.',
    );
    registrations = await _loadRegistrations();
  });

  Future<bool> respondToTournamentInvitation({
    required int tournamentId,
    required bool accept,
  }) => _runAction(() async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/Tournaments/$tournamentId/registration/respond'),
      headers: _jsonHeaders(),
      body: jsonEncode({'accept': accept}),
    );
    _requireSuccess(
      response,
      'Tournament invitation response could not be saved.',
    );
    registrations = await _loadRegistrations();
  });

  Future<bool> withdrawTournament(int tournamentId) => _runAction(() async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/Tournaments/$tournamentId/registration/mine'),
      headers: _headersProvider(),
    );
    _requireSuccess(response, 'Tournament withdrawal could not be completed.');
    registrations = await _loadRegistrations();
  });

  Future<void> loadBracket(int tournamentId) async {
    isBracketLoading = true;
    actionErrorMessage = null;
    notifyListeners();
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/Tournaments/$tournamentId/bracket'),
        headers: _headersProvider(),
      );
      _requireSuccess(response, 'The tournament bracket could not be loaded.');
      bracket = _asList(
        response.body,
      ).map(TournamentBracketMatch.fromJson).toList(growable: false);
    } catch (error) {
      actionErrorMessage = _displayError(
        error,
        'The tournament bracket could not be loaded.',
      );
    } finally {
      isBracketLoading = false;
      notifyListeners();
    }
  }

  Future<PlayerExperienceProfile?> _loadProfile() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/PlayerExperience/profile/mine'),
      headers: _headersProvider(),
    );
    if (response.statusCode == 404) return null;
    _requireSuccess(response, 'Player profile could not be loaded.');
    return PlayerExperienceProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<PartnerCandidate>> _loadPartners(String query) async {
    final uri = Uri.parse('$_baseUrl/PlayerExperience/partners').replace(
      queryParameters: query.trim().isEmpty ? null : {'query': query.trim()},
    );
    final response = await _client.get(uri, headers: _headersProvider());
    _requireSuccess(response, 'Partners could not be loaded.');
    return _asList(
      response.body,
    ).map(PartnerCandidate.fromJson).toList(growable: false);
  }

  Future<List<PartnerInvitation>> _loadInvitations() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/PlayerExperience/invitations/mine'),
      headers: _headersProvider(),
    );
    _requireSuccess(response, 'Partner invitations could not be loaded.');
    return _asList(
      response.body,
    ).map(PartnerInvitation.fromJson).toList(growable: false);
  }

  Future<List<PlayerMatch>> _loadMatches() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/PlayerExperience/matches/mine'),
      headers: _headersProvider(),
    );
    _requireSuccess(response, 'Your matches could not be loaded.');
    return _asList(
      response.body,
    ).map(PlayerMatch.fromJson).toList(growable: false);
  }

  Future<List<TournamentRegistration>> _loadRegistrations() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/Tournaments/mine'),
      headers: _headersProvider(),
    );
    _requireSuccess(
      response,
      'Your tournament registrations could not be loaded.',
    );
    return _asList(
      response.body,
    ).map(TournamentRegistration.fromJson).toList(growable: false);
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    if (isActionInProgress) return false;
    isActionInProgress = true;
    actionErrorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      actionErrorMessage = _displayError(
        error,
        'The player action could not be completed.',
      );
      return false;
    } finally {
      isActionInProgress = false;
      notifyListeners();
    }
  }

  Map<String, String> _jsonHeaders() => {
    ..._headersProvider(),
    'Content-Type': 'application/json',
  };

  static List<Map<String, dynamic>> _asList(String body) {
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  static void _requireSuccess(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(_responseMessage(response, fallback));
  }

  static String _responseMessage(http.Response response, String fallback) {
    return apiErrorMessage(response.body, fallback: fallback);
  }

  static String _displayError(Object error, String fallback) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? fallback : message;
  }
}

class PlayerExperienceProfile {
  const PlayerExperienceProfile({
    required this.userId,
    required this.playerName,
    required this.skillLevel,
    required this.preferredSide,
    required this.city,
    this.cityId,
    required this.bio,
    required this.availability,
    required this.isDiscoverable,
    required this.rating,
  });

  final int userId;
  final String playerName;
  final String skillLevel;
  final String preferredSide;
  final String city;
  final int? cityId;
  final String bio;
  final String availability;
  final bool isDiscoverable;
  final int rating;

  factory PlayerExperienceProfile.fromJson(Map<String, dynamic> json) =>
      PlayerExperienceProfile(
        userId: json['userId'] as int? ?? 0,
        playerName: json['playerName'] as String? ?? '',
        skillLevel: json['skillLevel'] as String? ?? 'Beginner',
        preferredSide: json['preferredSide'] as String? ?? 'Either',
        cityId: json['cityId'] as int?,
        city: json['city'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        availability: json['availability'] as String? ?? '',
        isDiscoverable: json['isDiscoverable'] as bool? ?? false,
        rating: json['rating'] as int? ?? 1000,
      );
}

class PartnerCandidate {
  const PartnerCandidate({
    required this.userId,
    required this.playerName,
    required this.skillLevel,
    required this.preferredSide,
    required this.city,
    required this.bio,
    required this.availability,
    required this.rating,
  });

  final int userId;
  final String playerName;
  final String skillLevel;
  final String preferredSide;
  final String city;
  final String bio;
  final String availability;
  final int rating;

  factory PartnerCandidate.fromJson(Map<String, dynamic> json) =>
      PartnerCandidate(
        userId: json['userId'] as int? ?? 0,
        playerName: json['playerName'] as String? ?? '',
        skillLevel: json['skillLevel'] as String? ?? '',
        preferredSide: json['preferredSide'] as String? ?? '',
        city: json['city'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        availability: json['availability'] as String? ?? '',
        rating: json['rating'] as int? ?? 1000,
      );
}

class PartnerInvitation {
  const PartnerInvitation({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.recipientUserId,
    required this.recipientName,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int senderUserId;
  final String senderName;
  final int recipientUserId;
  final String recipientName;
  final String message;
  final String status;
  final DateTime createdAt;

  factory PartnerInvitation.fromJson(Map<String, dynamic> json) =>
      PartnerInvitation(
        id: json['id'] as int? ?? 0,
        senderUserId: json['senderUserId'] as int? ?? 0,
        senderName: json['senderName'] as String? ?? '',
        recipientUserId: json['recipientUserId'] as int? ?? 0,
        recipientName: json['recipientName'] as String? ?? '',
        message: json['message'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class PlayerMatch {
  const PlayerMatch({
    required this.id,
    required this.tournamentName,
    required this.courtName,
    required this.scheduledTime,
    required this.status,
    required this.teamOne,
    required this.teamTwo,
    required this.resultStatus,
    required this.canConfirmResult,
    this.score,
    this.winnerTeamId,
  });

  final int id;
  final String tournamentName;
  final String courtName;
  final DateTime scheduledTime;
  final String status;
  final String? score;
  final int? winnerTeamId;
  final String resultStatus;
  final bool canConfirmResult;
  final List<String> teamOne;
  final List<String> teamTwo;

  factory PlayerMatch.fromJson(Map<String, dynamic> json) => PlayerMatch(
    id: json['id'] as int? ?? 0,
    tournamentName: json['tournamentName'] as String? ?? '',
    courtName: json['courtName'] as String? ?? '',
    scheduledTime:
        DateTime.tryParse(json['scheduledTime'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    status: json['status'] as String? ?? '',
    score: json['score'] as String?,
    winnerTeamId: json['winnerTeamId'] as int?,
    resultStatus: json['resultStatus'] as String? ?? '',
    canConfirmResult: json['canConfirmResult'] as bool? ?? false,
    teamOne: (json['teamOne'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    teamTwo: (json['teamTwo'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
  );
}

class TournamentRegistration {
  const TournamentRegistration({
    required this.tournamentId,
    required this.tournamentName,
    required this.startDate,
    required this.registrationDeadline,
    required this.tournamentStatus,
    required this.registrationStatus,
    required this.teamNumber,
    required this.partnerName,
  });

  final int tournamentId;
  final String tournamentName;
  final DateTime startDate;
  final DateTime registrationDeadline;
  final String tournamentStatus;
  final String registrationStatus;
  final int teamNumber;
  final String partnerName;

  factory TournamentRegistration.fromJson(Map<String, dynamic> json) =>
      TournamentRegistration(
        tournamentId: json['tournamentId'] as int? ?? 0,
        tournamentName: json['tournamentName'] as String? ?? '',
        startDate:
            DateTime.tryParse(json['startDate'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        registrationDeadline:
            DateTime.tryParse(json['registrationDeadline'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        tournamentStatus: json['tournamentStatus'] as String? ?? '',
        registrationStatus: json['registrationStatus'] as String? ?? '',
        teamNumber: json['teamNumber'] as int? ?? 0,
        partnerName: json['partnerName'] as String? ?? '',
      );
}

class TournamentBracketMatch {
  const TournamentBracketMatch({
    required this.id,
    required this.round,
    required this.position,
    required this.scheduledTime,
    required this.status,
    required this.isBye,
    required this.teamOne,
    required this.teamTwo,
    this.score,
    this.winnerTeamId,
  });

  final int id;
  final int round;
  final int position;
  final DateTime scheduledTime;
  final String status;
  final bool isBye;
  final List<String> teamOne;
  final List<String> teamTwo;
  final String? score;
  final int? winnerTeamId;

  factory TournamentBracketMatch.fromJson(Map<String, dynamic> json) =>
      TournamentBracketMatch(
        id: json['id'] as int? ?? 0,
        round: json['round'] as int? ?? 0,
        position: json['position'] as int? ?? 0,
        scheduledTime:
            DateTime.tryParse(json['scheduledTime'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        status: json['status'] as String? ?? '',
        isBye: json['isBye'] as bool? ?? false,
        score: json['score'] as String?,
        winnerTeamId: json['winnerTeamId'] as int?,
        teamOne: _teamNames(json['teamOne']),
        teamTwo: _teamNames(json['teamTwo']),
      );

  static List<String> _teamNames(Object? source) =>
      (source as List<dynamic>? ?? const [])
          .map((member) {
            if (member is Map<String, dynamic>) {
              return member['name'] as String? ?? '';
            }
            return member.toString();
          })
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
}
