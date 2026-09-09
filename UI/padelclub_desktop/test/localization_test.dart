import 'package:padelclub_desktop/features/player_experience/domain/entities/player_city.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:padelclub_desktop/core/localization/app_localizations.dart';
import 'package:padelclub_desktop/core/localization/bosnian_messages.dart';
import 'package:padelclub_desktop/core/localization/locale_controller.dart';
import 'package:padelclub_desktop/core/validation/form_validators.dart';
import 'package:padelclub_desktop/core/theme/app_theme.dart';
import 'package:padelclub_desktop/dashboard_page.dart';
import 'package:padelclub_desktop/features/operations/presentation/providers/operations_analytics_provider.dart';
import 'package:padelclub_desktop/features/player_experience/presentation/providers/player_experience_provider.dart';
import 'package:padelclub_desktop/features/player_experience/presentation/screens/player_hub_screen.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/main.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

void main() {
  test('catalogs match and bundled Bosnian translations are current', () {
    final en = Map<String, String>.from(
      jsonDecode(File('assets/l10n/en.json').readAsStringSync()),
    );
    final bs = Map<String, String>.from(
      jsonDecode(File('assets/l10n/bs.json').readAsStringSync()),
    );
    expect(bs.keys.toSet(), en.keys.toSet());
    expect(bosnianMessages, bs);
    for (final entry in bs.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
      final sourceParameters = RegExp(
        r'\{\w+\}',
      ).allMatches(entry.key).map((m) => m.group(0)).toSet();
      final translatedParameters = RegExp(
        r'\{\w+\}',
      ).allMatches(entry.value).map((m) => m.group(0)).toSet();
      expect(
        sourceParameters.containsAll(translatedParameters),
        isTrue,
        reason: 'Unknown placeholder in ${entry.key}',
      );
    }
  });

  test('language preference survives a new controller', () async {
    final store = _MemoryLocaleStore();
    final first = LocaleController(store: store);
    expect(await first.setLanguage('bs'), isTrue);
    final second = LocaleController(store: store);
    await second.load();
    expect(second.locale.languageCode, 'bs');
    expect(await second.setLanguage('en'), isTrue);
    expect(store.value, 'en');
    first.dispose();
    second.dispose();
  });

  test('late stored preference cannot overwrite a user selection', () async {
    final store = _DelayedLocaleStore();
    final controller = LocaleController(store: store);
    final loading = controller.load();
    await controller.setLanguage('bs');
    store.readResult.complete('en');
    await loading;
    expect(controller.locale.languageCode, 'bs');
    controller.dispose();
  });

  test(
    'storage failures and unsupported saved locales keep the app usable',
    () async {
      final store = _MemoryLocaleStore()..value = 'xx';
      final controller = LocaleController(store: store);
      await controller.load();
      expect(controller.locale.languageCode, 'en');
      store.failWrites = true;
      expect(await controller.setLanguage('bs'), isFalse);
      expect(controller.locale.languageCode, 'bs');
      expect(controller.setLanguage('xx'), throwsArgumentError);
      controller.dispose();
    },
  );

  test('Bosnian validators preserve Unicode and translate field errors', () {
    const l10n = AppLocalizations(Locale('bs'), bosnianMessages);
    expect(
      FormValidators.text('Džana Čengić', label: 'your first name', l10n: l10n),
      isNull,
    );
    expect(
      FormValidators.text('', label: 'your first name', l10n: l10n),
      'Unesite ime.',
    );
    expect(
      FormValidators.decimal('12,50', label: 'an hourly rate', l10n: l10n),
      isNull,
    );
    expect(
      FormValidators.integer('abc', label: 'Quantity', l10n: l10n),
      'Unesite cijeli broj.',
    );
    expect(
      l10n.text('Welcome back, {p1}', {'p1': 'Čengić {p2}'}),
      'Dobro došli nazad, Čengić {p2}',
    );
    expect(
      l10n.text('An untranslated server message'),
      'An untranslated server message',
    );
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      '$platform switches login and shell without losing route or input',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = platform == TargetPlatform.windows
            ? const Size(1440, 1000)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = LocaleController(store: _MemoryLocaleStore());
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _NoStorageAuthProvider(),
            child: PadelClubApp(
              localeController: controller,
              homeRouteBuilder: (_) => const MasterScreen(
                title: 'Home',
                child: TextField(key: Key('retained-field')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, 'Džana');
        await tester.tap(find.text('BS'));
        await tester.pumpAndSettle();
        expect(find.text('Dobro došli nazad'), findsOneWidget);
        expect(find.text('Prijavi se'), findsOneWidget);
        expect(find.text('Džana'), findsOneWidget);
        final loginContext = tester.element(find.byType(LoginPage));
        expect(
          MaterialLocalizations.of(loginContext).cancelButtonLabel,
          'Otkaži',
        );
        expect(loginContext.l10n.money(1234.5), '1.234,50 KM');
        expect(loginContext.l10n.date(DateTime(2026, 9, 8)), contains('2026'));
        Navigator.of(loginContext).pushReplacementNamed('/home');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('retained-field')),
          'Sačuvano',
        );
        if (platform == TargetPlatform.android) {
          expect(find.text('Početna'), findsWidgets);
          expect(find.text('Prodavnica'), findsOneWidget);
        } else {
          expect(find.text('Upravljanje korisnicima'), findsOneWidget);
        }
        await tester.tap(find.text('EN'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsNothing);
        expect(find.text('Sačuvano'), findsOneWidget);
        expect(
          ModalRoute.of(
            tester.element(find.byType(MasterScreen)),
          )?.settings.name,
          '/home',
        );
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('Bosnian admin dashboard renders without overflow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider()..roles = ['Administrator'],
          ),
          ChangeNotifierProvider<OperationsAnalyticsProvider>(
            create: (_) => _NoopOperations(),
          ),
        ],
        child: MaterialApp(
          theme: PadelTheme.light,
          locale: const Locale('bs'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pregled upravljanja'), findsOneWidget);
    expect(find.text('Operational recommendation readiness'), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Bosnian player form submits canonical option values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final player = _CapturingPlayerProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider()..isEmailVerified = true,
          ),
          ChangeNotifierProvider<PlayerExperienceProvider>.value(value: player),
        ],
        child: MaterialApp(
          theme: PadelTheme.light,
          locale: const Locale('bs'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const PlayerHubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dovrši'));
    await tester.pumpAndSettle();
    expect(find.text('Početni'), findsWidgets);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Napredni').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Grad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarajevo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvaj profil'));
    await tester.pumpAndSettle();
    expect(player.savedSkill, 'Advanced');
    expect(player.savedSide, 'Either');
    expect(tester.takeException(), isNull);
  });
}

class _MemoryLocaleStore implements LocaleStore {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String code) async {
    if (failWrites) throw StateError('Storage unavailable');
    value = code;
  }
}

class _DelayedLocaleStore extends _MemoryLocaleStore {
  final readResult = Completer<String?>();
  @override
  Future<String?> read() => readResult.future;
}

class _NoStorageAuthProvider extends AuthProvider {
  @override
  Future<({String username, String password})?> rememberedLogin() async => null;
}

class _NoopOperations extends OperationsAnalyticsProvider {
  @override
  Future<void> load() async {}
}

class _CapturingPlayerProvider extends PlayerExperienceProvider {
  @override
  Future<List<PlayerCity>> loadCities() async => [
    const PlayerCity(id: 1, name: 'Sarajevo'),
  ];
  String? savedSkill;
  String? savedSide;
  @override
  Future<void> load({String partnerQuery = ''}) async {}
  @override
  Future<bool> saveProfile({
    required String skillLevel,
    required String preferredSide,
    required int cityId,
    required String bio,
    required String availability,
    required bool isDiscoverable,
  }) async {
    savedSkill = skillLevel;
    savedSide = preferredSide;
    return true;
  }
}
