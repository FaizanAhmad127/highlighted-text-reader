import '../../domain/entities/saved_highlight.dart';

enum SavedDateFilter { all, today, thisWeek, thisMonth, custom }

class SavedScanGroup {
  const SavedScanGroup({required this.scanId, required this.items});

  final String? scanId;
  final List<SavedHighlight> items;
}

class SavedHighlightSection {
  const SavedHighlightSection({
    required this.day,
    required this.groups,
  });

  final DateTime day;
  final List<SavedScanGroup> groups;

  List<SavedHighlight> get items => [
        for (final group in groups) ...group.items,
      ];
}

class SavedHighlightsQueryResult {
  const SavedHighlightsQueryResult({
    required this.items,
    required this.sections,
  });

  final List<SavedHighlight> items;
  final List<SavedHighlightSection> sections;
}

class SavedHighlightsQuery {
  SavedHighlightsQuery._();

  static List<String> distinctLanguageIds(List<SavedHighlight> items) {
    final seen = <String>{};
    final ids = <String>[];
    for (final item in items) {
      final id = item.meaningLanguageId;
      if (id.isEmpty || !seen.add(id)) continue;
      ids.add(id);
    }
    return ids;
  }

  static SavedHighlightsQueryResult apply(
    List<SavedHighlight> items, {
    String query = '',
    SavedDateFilter dateFilter = SavedDateFilter.all,
    DateTime? customDay,
    String? languageId,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final needle = query.trim().toLowerCase();
    final today = DateTime(clock.year, clock.month, clock.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(clock.year, clock.month, 1);
    final custom = customDay == null
        ? null
        : DateTime(customDay.year, customDay.month, customDay.day);

    final filtered = items.where((item) {
      if (needle.isNotEmpty && !item.text.toLowerCase().contains(needle)) {
        return false;
      }
      if (languageId != null && item.meaningLanguageId != languageId) {
        return false;
      }
      final local = item.savedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (dateFilter == SavedDateFilter.custom) {
        if (custom == null) return true;
        return day == custom;
      }
      switch (dateFilter) {
        case SavedDateFilter.all:
        case SavedDateFilter.custom:
          return true;
        case SavedDateFilter.today:
          return !day.isBefore(today) && !day.isAfter(today);
        case SavedDateFilter.thisWeek:
          return !day.isBefore(weekStart) && !day.isAfter(today);
        case SavedDateFilter.thisMonth:
          return !day.isBefore(monthStart) && !day.isAfter(today);
      }
    }).toList();

    filtered.sort((a, b) => b.savedAt.compareTo(a.savedAt));

    final groupsByKey = <String, SavedScanGroup>{};
    final groupOrder = <String>[];
    for (final item in filtered) {
      final key = _groupKey(item);
      final existing = groupsByKey[key];
      if (existing == null) {
        groupsByKey[key] = SavedScanGroup(
          scanId: _explicitScanId(item),
          items: [item],
        );
        groupOrder.add(key);
      } else {
        existing.items.add(item);
      }
    }

    final sections = <SavedHighlightSection>[];
    for (final key in groupOrder) {
      final group = groupsByKey[key]!;
      final newest = group.items.first;
      final local = newest.savedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (sections.isEmpty || sections.last.day != day) {
        sections.add(SavedHighlightSection(day: day, groups: [group]));
      } else {
        sections.last.groups.add(group);
      }
    }

    return SavedHighlightsQueryResult(items: filtered, sections: sections);
  }

  static String? _explicitScanId(SavedHighlight item) {
    final scanId = item.scanId;
    if (scanId == null || scanId.isEmpty) return null;
    return scanId;
  }

  static String _groupKey(SavedHighlight item) {
    final scanId = _explicitScanId(item);
    if (scanId != null) return 'scan:$scanId';
    final local = item.savedAt.toLocal();
    final second = DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
    return 'time:${second.millisecondsSinceEpoch}';
  }
}
