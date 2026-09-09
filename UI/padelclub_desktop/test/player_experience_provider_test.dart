import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/features/player_experience/presentation/providers/player_experience_provider.dart';

void main() {
  test('loads the authenticated player hub through owner-scoped endpoints', () async {
    final requestedPaths = <String>[];
    final provider = PlayerExperienceProvider(
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer player-token'},
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer player-token');
        switch (request.url.path) {
          case '/PlayerExperience/profile/mine':
            return http.Response(jsonEncode(_profile()), 200);
          case '/PlayerExperience/partners':
            return http.Response(jsonEncode([_partner()]), 200);
          case '/PlayerExperience/invitations/mine':
            return http.Response(jsonEncode([]), 200);
          case '/PlayerExperience/matches/mine':
            return http.Response(jsonEncode([_match(canConfirmResult: true)]), 200);
          case '/Tournaments/mine':
            return http.Response(jsonEncode([]), 200);
          default:
            return http.Response('Unexpected request', 404);
        }
      }),
    );

    await provider.load(partnerQuery: 'Ana');

    expect(provider.errorMessage, isNull);
    expect(provider.profile?.playerName, 'Player One');
    expect(provider.partners, hasLength(1));
    expect(provider.matches.single.canConfirmResult, isTrue);
    expect(requestedPaths, containsAll(<String>[
      '/PlayerExperience/profile/mine',
      '/PlayerExperience/partners',
      '/PlayerExperience/invitations/mine',
      '/PlayerExperience/matches/mine',
      '/Tournaments/mine',
    ]));
  });

  test('registers with a selected partner then refreshes only owner registrations', () async {
    var registrationsLoaded = 0;
    final provider = PlayerExperienceProvider(
      baseUrl: 'https://padelclub.test',
      headersProvider: () => const {'Authorization': 'Bearer player-token'},
      client: MockClient((request) async {
        if (request.url.path == '/Tournaments/12/register') {
          expect(request.method, 'POST');
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {'partnerUserId': 8});
          return http.Response('', 204);
        }
        if (request.url.path == '/Tournaments/mine') {
          registrationsLoaded++;
          return http.Response(
            jsonEncode([
              {
                'tournamentId': 12,
                'tournamentName': 'Autumn Cup',
                'startDate': '2026-10-04T08:00:00Z',
                'registrationDeadline': '2026-09-30T12:00:00Z',
                'tournamentStatus': 'Upcoming',
                'registrationStatus': 'Confirmed',
                'teamNumber': 4,
                'partnerName': 'Ana Player',
              },
            ]),
            200,
          );
        }
        return http.Response('Unexpected request', 404);
      }),
    );

    final registered = await provider.registerTournament(
      tournamentId: 12,
      partnerUserId: 8,
    );

    expect(registered, isTrue);
    expect(registrationsLoaded, 1);
    expect(provider.registrations.single.partnerName, 'Ana Player');
    expect(provider.actionErrorMessage, isNull);
  });

  test('treats a missing player profile as an onboarding state', () async {
    final provider = PlayerExperienceProvider(
      baseUrl: 'https://padelclub.test',
      client: MockClient((request) async {
        if (request.url.path == '/PlayerExperience/profile/mine') {
          return http.Response('Complete player onboarding first.', 404);
        }
        return http.Response(jsonEncode([]), 200);
      }),
    );

    await provider.load();

    expect(provider.errorMessage, isNull);
    expect(provider.profile, isNull);
  });

  test('uses the server supplied opaque match confirmation decision', () {
    final match = PlayerMatch.fromJson({
      ..._match(canConfirmResult: false),
      'reportedByUserId': 999,
    });

    expect(match.canConfirmResult, isFalse);
  });
}

Map<String, dynamic> _profile() => {
  'userId': 7,
  'playerName': 'Player One',
  'skillLevel': 'Intermediate',
  'preferredSide': 'Left',
  'city': 'Sarajevo',
  'bio': 'Likes morning padel.',
  'availability': 'Weekends',
  'isDiscoverable': true,
  'rating': 1120,
};

Map<String, dynamic> _partner() => {
  'userId': 8,
  'playerName': 'Ana Player',
  'skillLevel': 'Intermediate',
  'preferredSide': 'Right',
  'city': 'Sarajevo',
  'bio': '',
  'availability': 'Evenings',
  'rating': 1110,
};

Map<String, dynamic> _match({required bool canConfirmResult}) => {
  'id': 13,
  'tournamentName': 'Autumn Cup',
  'courtName': 'Court 1',
  'scheduledTime': '2026-10-04T08:00:00Z',
  'status': 'Scheduled',
  'resultStatus': 'PendingConfirmation',
  'canConfirmResult': canConfirmResult,
  'teamOne': ['Player One'],
  'teamTwo': ['Player Two'],
};
