import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/app_crashlytics.dart';
import '../../core/firebase/saved_highlights_identity.dart';
import '../../domain/entities/saved_highlight.dart';

class SharedPrefsSavedHighlightsCache {
  SharedPrefsSavedHighlightsCache({SharedPreferences? prefs}) : _prefs = prefs;

  static const prefsKey = 'saved_highlights_json';
  static const ownerKey = 'saved_highlights_owner_uid';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  static String keyForUid(String uid) => '${prefsKey}_$uid';

  Future<List<SavedHighlight>> readForUid(String? uid) async {
    if (uid == null || uid.isEmpty) return const [];
    final prefs = await _store;
    final namespaced = prefs.getString(keyForUid(uid));
    if (namespaced != null && namespaced.isNotEmpty) {
      return _decode(namespaced);
    }

    final legacy = prefs.getString(prefsKey);
    if (legacy == null || legacy.isEmpty) return const [];

    final owner = prefs.getString(ownerKey);
    final ownedByCurrent = owner == null || owner.isEmpty || owner == uid;
    if (!ownedByCurrent || !SavedHighlightsIdentity.canAdoptLegacyCache(uid)) {
      await prefs.remove(prefsKey);
      return const [];
    }

    final items = _decode(legacy);
    await writeForUid(uid, items);
    await prefs.remove(prefsKey);
    await prefs.setString(ownerKey, uid);
    return items;
  }

  Future<void> writeForUid(String? uid, List<SavedHighlight> items) async {
    if (uid == null || uid.isEmpty) return;
    final prefs = await _store;
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString(keyForUid(uid), encoded);
    await prefs.setString(ownerKey, uid);
  }

  Future<List<SavedHighlight>> read() => readForUid(
        SavedHighlightsIdentity.uidAtProcessStart,
      );

  Future<void> write(List<SavedHighlight> items) => writeForUid(
        SavedHighlightsIdentity.uidAtProcessStart,
        items,
      );

  List<SavedHighlight> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => SavedHighlight.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'saved_highlights_cache_read');
      return const [];
    }
  }
}
