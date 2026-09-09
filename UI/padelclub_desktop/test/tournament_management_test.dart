import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/features/tournament_management/data/tournament_management_remote_data_source.dart';
import 'package:padelclub_desktop/features/tournament_management/domain/entities/tournament_draft.dart';
import 'package:padelclub_desktop/features/tournament_management/presentation/providers/tournament_management_provider.dart';
import 'package:padelclub_desktop/features/tournament_management/presentation/screens/tournament_management_screen.dart';

void main() {
  test(
    'admin CRUD and bracket generation refresh the server tournament list',
    () async {
      final calls = <String>[];
      final snapshots = <List<Map<String, Object?>>>[
        [_tournamentJson(name: 'Spring Cup')],
        [_tournamentJson(name: 'Summer Cup')],
        [_tournamentJson(name: 'Summer Cup Updated')],
        [_tournamentJson(name: 'Summer Cup Updated')],
        [],
      ];
      final dataSource = TournamentManagementRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          expect(request.headers['Authorization'], 'Bearer administrator');
          if (request.method == 'GET') {
            expect(request.url.queryParameters['PageSize'], '200');
            return http.Response(
              jsonEncode({'items': snapshots.removeAt(0)}),
              200,
            );
          }
          if (request.method == 'POST' && request.url.path == '/Tournament') {
            expect(request.headers['Content-Type'], 'application/json');
            expect(jsonDecode(request.body), _draftJson('Summer Cup'));
            return http.Response(
              jsonEncode(_tournamentJson(name: 'Summer Cup')),
              200,
            );
          }
          if (request.method == 'PUT' && request.url.path == '/Tournament/7') {
            expect(jsonDecode(request.body), _draftJson('Summer Cup Updated'));
            return http.Response(
              jsonEncode(_tournamentJson(name: 'Summer Cup Updated')),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/Tournaments/7/bracket/generate') {
            return http.Response('', 204);
          }
          if (request.method == 'DELETE' &&
              request.url.path == '/Tournament/7') {
            return http.Response('true', 200);
          }
          return http.Response('Unexpected request', 404);
        }),
      );
      final provider = TournamentManagementProvider(dataSource);
      addTearDown(provider.dispose);

      await provider.load();
      final created = await provider.create(_draft('Summer Cup'));
      final updated = await provider.update(
        tournamentId: 7,
        draft: _draft('Summer Cup Updated'),
      );
      final bracketGenerated = await provider.generateBracket(7);
      final deleted = await provider.delete(7);

      expect(created, isTrue);
      expect(updated, isTrue);
      expect(bracketGenerated, isTrue);
      expect(deleted, isTrue);
      expect(provider.tournaments, isEmpty);
      expect(provider.lastOperationMessage, contains('permanently deleted'));
      expect(calls, [
        'GET /Tournament',
        'POST /Tournament',
        'GET /Tournament',
        'PUT /Tournament/7',
        'GET /Tournament',
        'POST /Tournaments/7/bracket/generate',
        'GET /Tournament',
        'DELETE /Tournament/7',
        'GET /Tournament',
      ]);
    },
  );

  test(
    'surfaces the server bracket conflict without a false success',
    () async {
      final dataSource = TournamentManagementRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
        client: MockClient((request) async {
          expect(request.method, 'POST');
          return http.Response('The bracket has already been generated.', 409);
        }),
      );
      final provider = TournamentManagementProvider(dataSource);
      addTearDown(provider.dispose);

      final saved = await provider.generateBracket(7);

      expect(saved, isFalse);
      expect(provider.errorMessage, 'The bracket has already been generated.');
      expect(provider.lastOperationMessage, isNull);
    },
  );

  testWidgets('requires staff confirmation before generating a bracket', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = <String>[];
    final provider = TournamentManagementProvider(
      TournamentManagementRemoteDataSourceImpl(
        baseUrl: 'https://padelclub.test',
        headersProvider: () => const {'Authorization': 'Bearer administrator'},
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'items': [_tournamentJson()],
              }),
              200,
            );
          }
          if (request.method == 'POST') return http.Response('', 204);
          return http.Response('Unexpected request', 404);
        }),
      ),
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PadelTheme.light,
        home: TournamentManagementScreen(provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Generate one-way bracket'));
    await tester.pumpAndSettle();

    expect(find.text('Generate tournament bracket?'), findsOneWidget);
    expect(find.textContaining('one-way server operation'), findsOneWidget);
    expect(calls, ['GET /Tournament']);

    await tester.tap(find.text('Generate bracket'));
    await tester.pumpAndSettle();

    expect(calls, [
      'GET /Tournament',
      'POST /Tournaments/7/bracket/generate',
      'GET /Tournament',
    ]);
    expect(
      find.text('Bracket generated and refreshed from the server.'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

TournamentDraft _draft(String name) => TournamentDraft(
  name: name,
  description: 'A competitive doubles event.',
  startDate: DateTime.utc(2026, 9, 20),
  endDate: DateTime.utc(2026, 9, 21),
  registrationDeadline: DateTime.utc(2026, 9, 18),
  maxParticipants: 16,
  entryFee: 25,
  prizeInfo: 'Club trophy',
);

Map<String, Object?> _draftJson(String name) => {
  'name': name,
  'description': 'A competitive doubles event.',
  'startDate': '2026-09-20T00:00:00.000Z',
  'endDate': '2026-09-21T00:00:00.000Z',
  'registrationDeadline': '2026-09-18T00:00:00.000Z',
  'maxParticipants': 16,
  'entryFee': 25.0,
  'prizeInfo': 'Club trophy',
};

Map<String, Object?> _tournamentJson({String name = 'Spring Cup'}) => {
  'id': 7,
  'name': name,
  'description': 'A competitive doubles event.',
  'startDate': '2026-09-20T00:00:00Z',
  'endDate': '2026-09-21T00:00:00Z',
  'registrationDeadline': '2026-09-18T00:00:00Z',
  'maxParticipants': 16,
  'entryFee': 25,
  'status': 'Upcoming',
  'prizeInfo': 'Club trophy',
};
