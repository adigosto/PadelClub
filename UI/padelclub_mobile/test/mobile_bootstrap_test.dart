import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padelclub_desktop/core/di/injection.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';
import 'package:padelclub_desktop/main.dart' show LoginPage;
import 'package:padelclub_desktop/providers/auth_provider.dart';
import 'package:padelclub_mobile/main.dart';

void main() {
  setUpAll(sl.init);

  testWidgets('mobile runner starts at login and opens the player shell', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildPadelClubMobileApp(
        authProvider: _NoopAuthProvider(),
        homeRouteBuilder: (_) => const MasterScreen(
          title: 'Home',
          child: Center(child: Text('Player content')),
        ),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.bySemanticsLabel('PadelClub logo'), findsOneWidget);

    Navigator.of(tester.element(find.byType(LoginPage))).pushNamed('/home');
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });
}

class _NoopAuthProvider extends AuthProvider {
  @override
  Future<({String username, String password})?> rememberedLogin() async {
    return null;
  }
}
