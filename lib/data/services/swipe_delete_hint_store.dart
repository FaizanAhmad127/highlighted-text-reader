class SwipeDeleteHintStore {
  static bool _shownThisSession = false;

  bool shouldShow() => !_shownThisSession;

  void markShown() {
    _shownThisSession = true;
  }

  /// Clears the in-memory session flag. Production never needs this; a new
  /// process starts with the hint eligible again.
  static void resetForTest() {
    _shownThisSession = false;
  }
}
