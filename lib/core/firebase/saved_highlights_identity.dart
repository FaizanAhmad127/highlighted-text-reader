/// Auth uid seen when the process started, before deleted/disabled recovery.
///
/// Unscoped local cache may only be adopted by this same uid. A later
/// anonymous replacement must not upload the previous user's library, including
/// on the next launch when that replacement is the signed-in user.
class SavedHighlightsIdentity {
  SavedHighlightsIdentity._();

  static String? uidAtProcessStart;

  static void capture(String? uid) {
    uidAtProcessStart ??= (uid == null || uid.isEmpty) ? null : uid;
  }

  static void reset() {
    uidAtProcessStart = null;
  }

  static bool canAdoptLegacyCache(String? currentUid) {
    if (currentUid == null || currentUid.isEmpty) return false;
    final start = uidAtProcessStart;
    return start != null && start == currentUid;
  }
}
