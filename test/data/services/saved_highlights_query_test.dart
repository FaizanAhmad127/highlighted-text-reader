import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/saved_highlights_query.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';
import 'package:highlighted_text_reader/domain/entities/saved_highlight.dart';

void main() {
  final now = DateTime(2026, 9, 7, 15, 30);

  SavedHighlight item({
    required String id,
    required String text,
    String literal = 'literal meaning',
    String contextual = 'contextual meaning',
    String lang = 'en',
    String? scanId,
    required DateTime savedAt,
  }) {
    return SavedHighlight(
      id: id,
      highlight: Highlight(
        text: text,
        literal: literal,
        contextual: contextual,
        color: '0xFFE8C547',
      ),
      meaningLanguageId: lang,
      savedAt: savedAt,
      scanId: scanId,
    );
  }

  test('search matches highlighted phrase text only, ignoring meanings', () {
    final items = [
      item(
        id: '1',
        text: 'serendipity',
        literal: 'needle in a haystack',
        contextual: 'another needle',
        savedAt: now,
      ),
      item(
        id: '2',
        text: 'a quiet phrase',
        literal: 'serendipity',
        contextual: 'serendipity in use',
        savedAt: now.subtract(const Duration(minutes: 1)),
      ),
    ];

    final result = SavedHighlightsQuery.apply(items, query: 'Serendip');

    expect(result.items.map((e) => e.id), ['1']);
  });

  test('search is case-insensitive and uses contains', () {
    final items = [
      item(id: '1', text: 'The Quick Brown Fox', savedAt: now),
      item(id: '2', text: 'slow green turtle', savedAt: now),
    ];

    final result = SavedHighlightsQuery.apply(items, query: '  BROWN  ');

    expect(result.items.map((e) => e.id), ['1']);
  });

  test('today keeps only the local calendar day', () {
    final items = [
      item(id: 'today-am', text: 'a', savedAt: DateTime(2026, 9, 7, 0, 5)),
      item(id: 'today-pm', text: 'b', savedAt: DateTime(2026, 9, 7, 23, 50)),
      item(id: 'yesterday', text: 'c', savedAt: DateTime(2026, 9, 6, 23, 59)),
    ];

    final result = SavedHighlightsQuery.apply(
      items,
      dateFilter: SavedDateFilter.today,
      now: now,
    );

    expect(result.items.map((e) => e.id), ['today-pm', 'today-am']);
  });

  test('this week uses the local Monday-through-now window', () {
    final items = [
      item(id: 'mon', text: 'a', savedAt: DateTime(2026, 9, 7, 0, 1)),
      item(id: 'sun', text: 'b', savedAt: DateTime(2026, 9, 6, 23, 59)),
      item(id: 'next', text: 'c', savedAt: DateTime(2026, 9, 8, 8, 0)),
    ];

    // Monday 7 Sep 2026. Previous Sunday is last week.
    final monday = DateTime(2026, 9, 7, 10, 0);
    final result = SavedHighlightsQuery.apply(
      items,
      dateFilter: SavedDateFilter.thisWeek,
      now: monday,
    );

    expect(result.items.map((e) => e.id), ['mon']);
  });

  test('this month keeps the local calendar month', () {
    final items = [
      item(id: 'sep', text: 'a', savedAt: DateTime(2026, 9, 1, 0, 0)),
      item(id: 'aug', text: 'b', savedAt: DateTime(2026, 8, 31, 23, 59)),
    ];

    final result = SavedHighlightsQuery.apply(
      items,
      dateFilter: SavedDateFilter.thisMonth,
      now: now,
    );

    expect(result.items.map((e) => e.id), ['sep']);
  });

  test('language filter matches meaningLanguageId exactly', () {
    final items = [
      item(id: 'en', text: 'same phrase', lang: 'en', savedAt: now),
      item(
        id: 'ur',
        text: 'same phrase',
        lang: 'ur',
        savedAt: now.subtract(const Duration(minutes: 1)),
      ),
    ];

    final result = SavedHighlightsQuery.apply(items, languageId: 'ur');

    expect(result.items.map((e) => e.id), ['ur']);
  });

  test('sorts newest first and groups consecutive items by local day', () {
    final items = [
      item(id: 'old-day', text: 'c', savedAt: DateTime(2026, 9, 5, 18, 0)),
      item(id: 'today-early', text: 'a', savedAt: DateTime(2026, 9, 7, 9, 0)),
      item(id: 'today-late', text: 'b', savedAt: DateTime(2026, 9, 7, 20, 0)),
    ];

    final result = SavedHighlightsQuery.apply(items, now: now);

    expect(result.items.map((e) => e.id), [
      'today-late',
      'today-early',
      'old-day',
    ]);
    expect(result.sections, hasLength(2));
    expect(result.sections[0].day, DateTime(2026, 9, 7));
    expect(result.sections[0].items.map((e) => e.id), [
      'today-late',
      'today-early',
    ]);
    expect(result.sections[1].day, DateTime(2026, 9, 5));
    expect(result.sections[1].items.map((e) => e.id), ['old-day']);
  });

  test('custom date keeps only the picked local calendar day', () {
    final items = [
      item(id: 'aug', text: 'a', savedAt: DateTime(2026, 8, 15, 9, 0)),
      item(id: 'today', text: 'b', savedAt: now),
      item(id: 'aug-late', text: 'c', savedAt: DateTime(2026, 8, 15, 23, 0)),
    ];

    final result = SavedHighlightsQuery.apply(
      items,
      dateFilter: SavedDateFilter.custom,
      customDay: DateTime(2026, 8, 15),
      now: now,
    );

    expect(result.items.map((e) => e.id), ['aug-late', 'aug']);
  });

  test('distinctLanguageIds lists every id present, first-seen order', () {
    final items = [
      item(id: '1', text: 'a', lang: 'ur', savedAt: now),
      item(id: '2', text: 'b', lang: 'en', savedAt: now),
      item(id: '3', text: 'c', lang: 'ur', savedAt: now),
      item(id: '4', text: 'd', lang: 'ar', savedAt: now),
    ];

    expect(
      SavedHighlightsQuery.distinctLanguageIds(items),
      ['ur', 'en', 'ar'],
    );
  });

  test('groups items that share a scanId even when saved at different times', () {
    final items = [
      item(
        id: 'scan-a-new',
        text: 'a',
        scanId: 'scan-a',
        savedAt: DateTime(2026, 9, 7, 20, 0),
      ),
      item(
        id: 'scan-b',
        text: 'b',
        scanId: 'scan-b',
        savedAt: DateTime(2026, 9, 7, 19, 0),
      ),
      item(
        id: 'scan-a-old',
        text: 'c',
        scanId: 'scan-a',
        savedAt: DateTime(2026, 9, 6, 10, 0),
      ),
    ];

    final result = SavedHighlightsQuery.apply(items, now: now);

    expect(result.items.map((e) => e.id), [
      'scan-a-new',
      'scan-b',
      'scan-a-old',
    ]);
    expect(result.sections, hasLength(1));
    expect(result.sections.single.groups, hasLength(2));
    expect(result.sections.single.groups[0].scanId, 'scan-a');
    expect(result.sections.single.groups[0].items.map((e) => e.id), [
      'scan-a-new',
      'scan-a-old',
    ]);
    expect(result.sections.single.groups[1].scanId, 'scan-b');
    expect(result.sections.single.groups[1].items.map((e) => e.id), ['scan-b']);
  });

  test('items without scanId group only when savedAt matches the same second', () {
    final sameSecond = DateTime(2026, 9, 7, 12, 0, 0, 10);
    final items = [
      item(id: 'a', text: 'a', savedAt: sameSecond),
      item(
        id: 'b',
        text: 'b',
        savedAt: DateTime(2026, 9, 7, 12, 0, 0, 90),
      ),
      item(id: 'c', text: 'c', savedAt: DateTime(2026, 9, 7, 11, 59, 59)),
    ];

    final result = SavedHighlightsQuery.apply(items, now: now);

    expect(result.sections.single.groups, hasLength(2));
    expect(result.sections.single.groups[0].items.map((e) => e.id), ['b', 'a']);
    expect(result.sections.single.groups[0].scanId, isNull);
    expect(result.sections.single.groups[1].items.map((e) => e.id), ['c']);
  });
}
