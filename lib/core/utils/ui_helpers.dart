import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class UIHelpers {
  // Snackbar utility
  static void showSnackbar(
    BuildContext context,
    String message, {
    int durationSeconds = AppConstants.snackbarDurationSeconds,
    Color? backgroundColor,
    IconData icon = Icons.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final hasAction = actionLabel != null && onAction != null;
    final snackBar = SnackBar(
      duration: Duration(seconds: durationSeconds),
      content: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onPrimary),
            ),
          ),
          if (hasAction)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
        ],
      ),
      backgroundColor: backgroundColor ?? theme.colorScheme.primary,
      behavior: SnackBarBehavior.fixed,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
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
