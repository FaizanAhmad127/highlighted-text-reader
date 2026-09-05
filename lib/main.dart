import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'home_screen.dart';
import 'presentation/pages/onboarding/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();

  FirebaseBootstrap.runGuarded(() {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final analyticsObserver = FirebaseBootstrap.analyticsObserver;
    final GoRouter router = GoRouter(
      initialLocation: AppConstants.onboardRoute,
      observers: analyticsObserver == null ? [] : [analyticsObserver],
      routes: [
        GoRoute(
          path: AppConstants.onboardRoute,
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => const HomeScreen(),
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
