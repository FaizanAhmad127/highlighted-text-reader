import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/core/utils/camera_permission.dart';
import 'package:highlighted_text_reader/data/services/highlight_transfer_service.dart';
import 'package:highlighted_text_reader/data/services/saved_highlights_store.dart';
import 'package:highlighted_text_reader/data/services/swipe_delete_hint_store.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';
import 'package:highlighted_text_reader/domain/entities/saved_highlight.dart';
import 'package:highlighted_text_reader/presentation/pages/saved/saved_highlights_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    HighlightTransferService? transferService,
    Future<bool> Function()? hasConnection,
    bool Function()? isSignedIn,
    Future<String?> Function(BuildContext context)? scanQr,
    Future<bool> Function()? requestCameraPermission,
    Future<void> Function()? openAppSettings,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SavedHighlightsPage(
          store: store,
          clock: () => DateTime(2026, 9, 7, 16, 0),
          pickDate: pickDate,
          swipeHintStore: swipeHintStore,
          transferService: transferService,
          hasConnection: hasConnection ?? () async => true,
          isSignedIn: isSignedIn ?? () => true,
          scanQr: scanQr,
          requestCameraPermission: requestCameraPermission ?? () async => true,
          openAppSettings: openAppSettings,
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
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
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

  testWidgets('selected date and language chips stay first in their rows', (
    tester,
  ) async {
    await store.put(
      SavedHighlight(
        id: 'en',
        highlight: serendipity,
        meaningLanguageId: 'en',
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

    List<String> chipLabels(Key key) {
      return tester
          .widgetList<FilterChip>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(FilterChip),
            ),
          )
          .map((chip) => (chip.label as Text).data!)
          .toList();
    }

    expect(
      tester
          .widget<SingleChildScrollView>(
              find.byKey(const Key('savedDateFilters')))
          .scrollDirection,
      Axis.horizontal,
    );
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('savedLanguageFilters')),
          )
          .scrollDirection,
      Axis.horizontal,
    );
    expect(chipLabels(const Key('savedDateFilters')).first, 'All');
    expect(chipLabels(const Key('savedLanguageFilters')).first, 'All');

    await tester.tap(find.widgetWithText(FilterChip, 'This month'));
    await tester.pumpAndSettle();
    expect(chipLabels(const Key('savedDateFilters')).first, 'This month');

    await tester.tap(find.widgetWithText(FilterChip, 'Urdu'));
    await tester.pumpAndSettle();
    expect(chipLabels(const Key('savedLanguageFilters')).first, 'Urdu');
  });

  testWidgets('fades the overflowing end of a filter row', (tester) async {
    tester.view.physicalSize = const Size(240, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPage(tester);

    expect(
      find.byKey(const ValueKey('endFade:savedDateFilters')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('startFade:savedDateFilters')),
      findsNothing,
    );

    await tester.drag(
      find.byKey(const Key('savedDateFilters')),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('startFade:savedDateFilters')),
      findsOneWidget,
    );
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

  testWidgets('disables Share via QR when the library is empty',
      (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Transfer highlights'));
    await tester.pumpAndSettle();

    final share = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, 'Share via QR'),
    );
    expect(share.enabled, isFalse);
    expect(find.text('Import via QR'), findsOneWidget);
  });

  testWidgets('Share via QR shows a code for the current library', (
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
    final transfers = HighlightTransferService(
      store: MemoryHighlightTransferStore(),
      currentUid: () => 'uid-a',
      clock: () => DateTime.utc(2026, 9, 7, 16),
    );

    await pumpPage(tester, transferService: transfers);
    await tester.tap(find.byTooltip('Transfer highlights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share via QR'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Valid for 30 minutes'), findsOneWidget);
  });

  testWidgets('Import via QR merges highlights from a transfer',
      (tester) async {
    final transfers = HighlightTransferService(
      store: MemoryHighlightTransferStore(),
      currentUid: () => 'uid-a',
      clock: () => DateTime.utc(2026, 9, 7, 16),
    );
    await transfers.create([
      SavedHighlight(
        id: 'src-1',
        highlight: eloquent,
        meaningLanguageId: 'en',
        savedAt: DateTime.utc(2026, 8, 1),
      ),
    ]);

    await pumpPage(
      tester,
      transferService: transfers,
      scanQr: (_) async => 'htr1:uid-a',
    );
    await tester.tap(find.byTooltip('Transfer highlights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import via QR'));
    await tester.pumpAndSettle();

    expect(find.text('Added 1 highlight.'), findsOneWidget);
    expect(await store.current(), hasLength(1));
    expect((await store.current()).single.text, 'eloquent');
  });

  testWidgets('denied camera permission blocks QR import and opens settings', (
    tester,
  ) async {
    var openedSettings = 0;
    var scanned = 0;
    await pumpPage(
      tester,
      requestCameraPermission: () async => false,
      openAppSettings: () async => openedSettings++,
      scanQr: (_) async {
        scanned++;
        return null;
      },
    );

    await tester.tap(find.byTooltip('Transfer highlights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import via QR'));
    await tester.pumpAndSettle();

    expect(scanned, 0);
    expect(find.text(CameraPermission.qrMessage), findsOneWidget);
    await tester.tap(find.text(CameraPermission.settingsAction));
    await tester.pump();
    expect(openedSettings, 1);
  });

  testWidgets(
    'landscape scroll hides search and filters until the app bar, then scrolls cards',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (var i = 0; i < 8; i++) {
        await store.put(
          SavedHighlight(
            id: '$i',
            highlight: Highlight(
              text: 'saved phrase $i',
              literal: 'lit $i',
              contextual: 'ctx $i',
              color: '0xFFE8C547',
            ),
            meaningLanguageId: 'en',
            savedAt: DateTime(2026, 9, 7, 15, i),
          ),
        );
      }

      await pumpPage(tester);

      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(find.text('All').hitTestable(), findsWidgets);
      expect(find.text('saved phrase 7').hitTestable(), findsOneWidget);

      await _dragUntilHidden(
        tester,
        dragHandle: find.byType(NestedScrollView),
        hide: find.widgetWithText(FilterChip, 'All'),
      );

      expect(find.text('Saved highlights').hitTestable(), findsOneWidget);
      expect(find.byType(TextField).hitTestable(), findsNothing);
      expect(
          find.widgetWithText(FilterChip, 'All').hitTestable(), findsNothing);
      expect(find.textContaining('saved phrase').hitTestable(), findsWidgets);

      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      final listTop = find.text('Today').hitTestable();
      expect(listTop, findsOneWidget);
      expect(tester.getRect(listTop).top, greaterThan(appBarBottom - 1));
      expect(tester.getRect(listTop).top, lessThanOrEqualTo(appBarBottom + 56));

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, -420),
        2000,
      );
      await tester.pumpAndSettle();

      expect(find.text('saved phrase 7').hitTestable(), findsNothing);
      expect(find.textContaining('saved phrase').hitTestable(), findsWidgets);

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, 900),
        3000,
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(
          find.widgetWithText(FilterChip, 'All').hitTestable(), findsWidgets);
    },
  );
}

Future<void> _dragUntilHidden(
  WidgetTester tester, {
  required Finder dragHandle,
  required Finder hide,
}) async {
  for (var i = 0; i < 24; i++) {
    if (hide.hitTestable().evaluate().isEmpty) return;
    await tester.drag(dragHandle, const Offset(0, -48));
    await tester.pumpAndSettle();
  }
}
