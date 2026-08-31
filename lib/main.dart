import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'presentation/pages/onboarding/onboarding_page.dart';
import 'home_screen.dart';
import 'presentation/pages/buy_token/buy_token_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: AppConstants.onboardRoute,
      routes: [
        GoRoute(
          path: AppConstants.onboardRoute,
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppConstants.buyTokenRoute,
          builder: (context, state) => const BuyTokenPage(),
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
