import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/saved_highlights_store.dart';
import 'package:highlighted_text_reader/data/services/swipe_delete_hint_store.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';
import 'package:highlighted_text_reader/domain/entities/saved_highlight.dart';
import 'package:highlighted_text_reader/presentation/pages/saved/saved_highlights_page.dart';

void main() {
  late MemorySavedHighlightsStore store;

  const serendipity = Highlight(
    text: 'serendipity',
    literal: 'needle meaning',
    contextual: 'another needle',
    color: '0xFFE8C547',
  );

  const eloquent = Highlight(
    text: 'eloquent',
    literal: 'fluent',
    contextual: 'spoke well',
    color: '0xFF4CAF50',
  );

  const sakura = Highlight(
    text: 'sakura',
    literal: 'cherry blossom',
    contextual: 'spring flowers',
    color: '0xFFFF80AB',
  );

  setUp(() {
    SwipeDeleteHintStore.resetForTest();
    SwipeDeleteHintStore().markShown();
    store = MemorySavedHighlightsStore();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Future<DateTime?> Function(BuildContext context)? pickDate,
    SwipeDeleteHintStore? swipeHintStore,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SavedHighlightsPage(
          store: store,
          clock: () => DateTime(2026, 9, 7, 16, 0),
          pickDate: pickDate,
          swipeHintStore: swipeHintStore,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty library copy when nothing is saved', (tester) async {
    await pumpPage(tester);

    expect(find.text('No saved highlights yet'), findsOneWidget);
    expect(
      find.text('Save phrases from a scan to see them here.'),
      findsOneWidget,
    );
    expect(find.text('No highlights match these filters'), findsNothing);
  });

  testWidgets('search filters by highlighted phrase text only', (tester) async {
    await store.put(
      SavedHighlight(
        id: '1',
        highlight: serendipity,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 9, 7, 15, 0),
      ),
    );
    await store.put(
      SavedHighlight(
        id: '2',
        highlight: eloquent,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 9, 7, 14, 0),
      ),
    );

    await pumpPage(tester);

    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('eloquent'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pumpAndSettle();

    expect(find.text('No highlights match these filters'), findsOneWidget);
    expect(find.text('serendipity'), findsNothing);
    expect(find.text('eloquent'), findsNothing);

    await tester.enterText(find.byType(TextField), 'eloq');
    await tester.pumpAndSettle();

    expect(find.text('eloquent'), findsOneWidget);
    expect(find.text('serendipity'), findsNothing);
    expect(find.text('No highlights match these filters'), findsNothing);
  });

  testWidgets('search clear icon appears with text and clears the query', (
    tester,
  ) async {
    await store.put(
      SavedHighlight(
        id: '1',
        highlight: serendipity,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 9, 7, 15, 0),
      ),
    );
    await store.put(
      SavedHighlight(
        id: '2',
        highlight: eloquent,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 9, 7, 14, 0),
      ),
    );

    await pumpPage(tester);

    expect(find.byTooltip('Clear search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'eloq');
    await tester.pumpAndSettle();

    expect(find.text('eloquent'), findsOneWidget);
    expect(find.text('serendipity'), findsNothing);
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear search'), findsNothing);
    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('eloquent'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('date and language filters narrow the list', (tester) async {
    await store.put(
      SavedHighlight(
        id: 'old-en',
        highlight: serendipity,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 8, 1, 10, 0),
      ),
    );
    await store.put(
      SavedHighlight(
        id: 'today-ur',
        highlight: eloquent,
        meaningLanguageId: 'ur',
        savedAt: DateTime(2026, 9, 7, 11, 0),
      ),
    );

    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Today'));
    await tester.pumpAndSettle();

    expect(find.text('eloquent'), findsOneWidget);
    expect(find.text('serendipity'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Urdu'));
    await tester.pumpAndSettle();

    expect(find.text('eloquent'), findsOneWidget);
    expect(find.text('serendipity'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'English'));
    await tester.pumpAndSettle();

    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('eloquent'), findsNothing);
  });

  testWidgets('language chips list every distinct saved language', (
    tester,
  ) async {
    await store.put(
      SavedHighlight(
        id: 'ja',
        highlight: sakura,
        meaningLanguageId: 'ja',
        savedAt: DateTime(2026, 9, 7, 12, 0),
      ),
    );
    await store.put(
      SavedHighlight(
        id: 'ur',
        highlight: eloquent,
        meaningLanguageId: 'ur',
        savedAt: DateTime(2026, 9, 7, 11, 0),
      ),
    );

    await pumpPage(tester);

    expect(find.widgetWithText(FilterChip, 'Japanese'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Urdu'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'English'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Arabic'), findsNothing);
  });

  testWidgets('custom date chip filters to the picked day', (tester) async {
    await store.put(
      SavedHighlight(
        id: 'old-en',
        highlight: serendipity,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 8, 1, 10, 0),
      ),
    );
    await store.put(
      SavedHighlight(
        id: 'today-en',
        highlight: eloquent,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 9, 7, 11, 0),
      ),
    );

    await pumpPage(
      tester,
      pickDate: (_) async => DateTime(2026, 8, 1),
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Custom'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Aug 1, 2026'), findsOneWidget);
    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('eloquent'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Today'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Custom'), findsOneWidget);
    expect(find.text('eloquent'), findsOneWidget);
    expect(find.text('serendipity'), findsNothing);
  });

  testWidgets('groups cards that share a scanId', (tester) async {
    await store.put(
      SavedHighlight(
        id: '1',
        highlight: serendipity,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 9, 7, 15, 0),
        scanId: 'scan-1',
      ),
    );
    await store.put(
      SavedHighlight(
        id: '2',
        highlight: eloquent,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 9, 7, 14, 0),
        scanId: 'scan-1',
      ),
    );

    await pumpPage(tester);

    expect(find.text('2 from this scan'), findsOneWidget);
    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('eloquent'), findsOneWidget);
  });

  testWidgets('opening with items does not delete the first card', (
    tester,
  ) async {
    SwipeDeleteHintStore.resetForTest();
    await store.put(
      SavedHighlight(
        id: '1',
        highlight: serendipity,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 9, 7, 15, 0),
      ),
    );

    await pumpPage(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(find.text('serendipity'), findsOneWidget);
    expect(await store.current(), hasLength(1));
    expect(find.byType(Dismissible), findsOneWidget);
  });

  testWidgets('shows empty filter copy when filters match nothing', (
    tester,
  ) async {
    await store.put(
      SavedHighlight(
        id: 'old-en',
        highlight: serendipity,
        meaningLanguageId: 'en',
        savedAt: DateTime(2026, 8, 1, 10, 0),
      ),
    );

    await pumpPage(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Today'));
    await tester.pumpAndSettle();

    expect(find.text('No highlights match these filters'), findsOneWidget);
    expect(find.text('No saved highlights yet'), findsNothing);
  });
}
