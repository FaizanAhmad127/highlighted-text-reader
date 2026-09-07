import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlighted_text_reader/core/constants/app_constants.dart';
import 'package:highlighted_text_reader/data/services/onboarding_store.dart';
import 'package:highlighted_text_reader/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late OnboardingStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = OnboardingStore();
  });

  GoRouter routerForTest({required bool onboardingCompleted}) {
    return GoRouter(
      initialLocation: onboardingCompleted
          ? AppConstants.homeRoute
          : AppConstants.onboardRoute,
      redirect: (context, state) => redirectIfOnboardingCompleted(
        matchedLocation: state.matchedLocation,
        completedAtLaunch: onboardingCompleted,
        store: store,
      ),
      routes: [
        GoRoute(
          path: AppConstants.onboardRoute,
          builder: (context, state) => const Scaffold(body: Text('Onboarding')),
        ),
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
  }

  test('does not redirect onboarding when it is still incomplete', () async {
    expect(
      await redirectIfOnboardingCompleted(
        matchedLocation: AppConstants.onboardRoute,
        completedAtLaunch: false,
        store: store,
      ),
      isNull,
    );
  });

  test('redirects onboarding to home when completed at launch', () async {
    expect(
      await redirectIfOnboardingCompleted(
        matchedLocation: AppConstants.onboardRoute,
        completedAtLaunch: true,
        store: store,
      ),
      AppConstants.homeRoute,
    );
  });

  test('redirects onboarding to home after the flag is written', () async {
    await store.writeCompleted();

    expect(
      await redirectIfOnboardingCompleted(
        matchedLocation: AppConstants.onboardRoute,
        completedAtLaunch: false,
        store: store,
      ),
      AppConstants.homeRoute,
    );
  });

  test('does not redirect home', () async {
    await store.writeCompleted();

    expect(
      await redirectIfOnboardingCompleted(
        matchedLocation: AppConstants.homeRoute,
        completedAtLaunch: true,
        store: store,
      ),
      isNull,
    );
  });

  testWidgets('starts on home when onboarding is already completed',
      (tester) async {
    await store.writeCompleted();
    final router = routerForTest(onboardingCompleted: await store.read());

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
  });

  testWidgets('redirects /on-board to home after onboarding is completed',
      (tester) async {
    await store.writeCompleted();
    final router = routerForTest(onboardingCompleted: true);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.go(AppConstants.onboardRoute);
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
  });
}
