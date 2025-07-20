import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/ui_helpers.dart';

class AuthCheckPage extends StatelessWidget {
  const AuthCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _checkUserSignedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: UIHelpers.loadingIndicator(),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          // Navigate to HomeScreen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(AppConstants.homeRoute);
          });
          return const SizedBox.shrink();
        } else {
          // Navigate to OnboardingScreen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(AppConstants.onboardRoute);
          });
          return const SizedBox.shrink();
        }
      },
    );
  }

  Future<User?> _checkUserSignedIn() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      user = FirebaseAuth.instance.currentUser;
    }
    return user;
  }
}
