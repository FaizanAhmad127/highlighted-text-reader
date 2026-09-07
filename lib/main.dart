import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'data/services/onboarding_store.dart';
import 'home_screen.dart';
import 'presentation/pages/onboarding/onboarding_page.dart';
import 'presentation/pages/saved/saved_highlights_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  final onboardingStore = OnboardingStore();
  final onboardingCompleted = await onboardingStore.read();
  runApp(MyApp(
    onboardingCompleted: onboardingCompleted,
    onboardingStore: onboardingStore,
  ));
}

Future<String?> redirectIfOnboardingCompleted({
  required String matchedLocation,
  required bool completedAtLaunch,
  required OnboardingStore store,
}) async {
  if (matchedLocation != AppConstants.onboardRoute) {
    return null;
  }
  if (completedAtLaunch || await store.read()) {
    return AppConstants.homeRoute;
  }
  return null;
}

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    this.onboardingCompleted = false,
    OnboardingStore? onboardingStore,
  }) : onboardingStore = onboardingStore ?? OnboardingStore();

  final bool onboardingCompleted;
  final OnboardingStore onboardingStore;

  @override
  Widget build(BuildContext context) {
    final analyticsObserver = FirebaseBootstrap.analyticsObserver;
    final GoRouter router = GoRouter(
      initialLocation: onboardingCompleted
          ? AppConstants.homeRoute
          : AppConstants.onboardRoute,
      observers: analyticsObserver == null ? [] : [analyticsObserver],
      redirect: (context, state) => redirectIfOnboardingCompleted(
        matchedLocation: state.matchedLocation,
        completedAtLaunch: onboardingCompleted,
        store: onboardingStore,
      ),
      routes: [
        GoRoute(
          path: AppConstants.onboardRoute,
          builder: (context, state) => OnboardingPage(store: onboardingStore),
        ),
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppConstants.savedRoute,
          builder: (context, state) => const SavedHighlightsPage(),
        ),
      ],
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
