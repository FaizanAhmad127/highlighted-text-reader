import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'presentation/pages/auth/auth_check_page.dart';
import 'presentation/pages/onboarding/onboarding_page.dart';
import 'home_screen.dart'; // TODO: Refactor this to clean architecture
import 'phone_auth_screen.dart'; // TODO: Refactor this to clean architecture
import 'presentation/pages/buy_token/buy_token_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      routes: [
        GoRoute(
          path: AppConstants.rootRoute,
          builder: (context, state) => const AuthCheckPage(),
        ),
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppConstants.phoneAuthRoute,
          builder: (context, state) => PhoneAuthScreen(),
        ),
        GoRoute(
          path: AppConstants.buyTokenRoute,
          builder: (context, state) => const BuyTokenPage(),
        ),
        GoRoute(
          path: AppConstants.onboardRoute,
          builder: (context, state) => const OnboardingPage(),
        ),
      ],
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      routerConfig: router,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
