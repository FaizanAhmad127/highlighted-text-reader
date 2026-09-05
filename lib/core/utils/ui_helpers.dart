import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class UIHelpers {
  // Snackbar utility
  static void showSnackbar(
    BuildContext context,
    String message, {
    int durationSeconds = AppConstants.snackbarDurationSeconds,
    Color backgroundColor = Colors.blueAccent,
    IconData icon = Icons.info,
  }) {
    final snackBar = SnackBar(
      duration: Duration(seconds: durationSeconds),
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(snackBar);
  }

  // Common loading indicator
  static Widget loadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // Common text styles
  static const TextStyle titleTextStyle = TextStyle(
    color: Colors.black,
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyTextStyle = TextStyle(
    color: Colors.black,
    fontSize: 14.0,
  );
}
