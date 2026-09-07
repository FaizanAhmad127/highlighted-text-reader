import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlighted_text_reader/core/constants/app_constants.dart';
import 'package:highlighted_text_reader/data/services/onboarding_store.dart';
import 'package:highlighted_text_reader/presentation/pages/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late OnboardingStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = OnboardingStore();
  });

  Future<void> pumpOnboarding(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppConstants.onboardRoute,
      routes: [
        GoRoute(
          path: AppConstants.onboardRoute,
          builder: (context, state) => OnboardingPage(store: store),
        ),
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('Skip writes the completed flag and goes home', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(await store.read(), isTrue);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Done writes the completed flag and goes home', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(await store.read(), isTrue);
    expect(find.text('Home'), findsOneWidget);
  });
}
