import 'package:flutter_test/flutter_test.dart';

import 'package:padelclub_desktop/main.dart';

void main() {
  testWidgets('shows the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PadelClubApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
