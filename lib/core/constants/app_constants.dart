class AppConstants {
  // App Info
  static const String appName = 'Highlighted Text Reader';
  static const String supportEmail = 'khattakandcopk@gmail.com';

  static const int snackbarDurationSeconds = 3;

  // Routes
  static const String homeRoute = '/home';
  static const String onboardRoute = '/on-board';
  static const String savedRoute = '/saved';

  // Onboarding Assets
  static const String onboard1Asset = 'assets/onboard1.png';
  static const String onboard2Asset = 'assets/onboard2.png';
  static const String onboard3Asset = 'assets/onboard3.jpg';

  static const String geminiModelId = 'gemini-3.5-flash-lite';
  static const int maxImageEdgePx = 1536;
  static const int jpegQuality = 70;
  static const int maxScansPerDay = 20;
  static const Duration scanCooldown = Duration(seconds: 8);
}
