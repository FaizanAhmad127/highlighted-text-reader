import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlighted_text_reader/core/constants/app_constants.dart';
import 'package:highlighted_text_reader/core/utils/camera_permission.dart';
import 'package:highlighted_text_reader/data/services/saved_highlights_store.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';
import 'package:highlighted_text_reader/domain/entities/meaning_language.dart';
import 'package:highlighted_text_reader/home_screen.dart';
import 'package:highlighted_text_reader/presentation/widgets/home/image_capture_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const serendipity = Highlight(
    text: 'serendipity',
    literal: 'happy accident',
    contextual: 'a pleasant surprise',
    color: '0xFFE8C547',
  );

  const eloquent = Highlight(
    text: 'eloquent',
    literal: 'fluent',
    contextual: 'spoke well',
    color: '0xFF4CAF50',
  );

  late MemorySavedHighlightsStore store;
  late Directory tempDir;
  late File imageFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = MemorySavedHighlightsStore();
    tempDir = await Directory.systemTemp.createTemp('home_save');
    imageFile = File('${tempDir.path}/page.png');
    await imageFile.writeAsBytes(_oneByOnePng);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    MeaningLanguage language = MeaningLanguage.english,
    String scanId = 'scan-home',
    bool quotaReady = true,
    Future<bool> Function()? requestCameraPermission,
    Future<void> Function()? openAppSettings,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          savedHighlightsStore: store,
          debugHighlightResponse: const HighlightResponse(
            found: true,
            highlights: [serendipity, eloquent],
          ),
          debugMeaningLanguage: language,
          debugScanId: scanId,
          debugImage: imageFile,
          debugQuotaReady: quotaReady,
          requestCameraPermission: requestCameraPermission,
          openAppSettings: openAppSettings,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('bookmark saves then unsaves without expanding the card', (
    tester,
  ) async {
    await pumpHome(
      tester,
      language: const MeaningLanguage(id: 'ur', name: 'Urdu'),
    );

    expect(find.text('Tap for meaning'), findsNWidgets(2));
    expect(find.text('Save all'), findsOneWidget);

    await tester.tap(find.byTooltip('Save').first);
    await tester.pumpAndSettle();

    expect(await store.current(), hasLength(1));
    expect((await store.current()).single.meaningLanguageId, 'ur');
    expect((await store.current()).single.scanId, 'scan-home');
    expect(find.text('Saved to your library.'), findsOneWidget);
    expect(find.text('Literal'), findsNothing);
    expect(find.text('Save all'), findsOneWidget);

    await tester.tap(find.byTooltip('Unsave'));
    await tester.pumpAndSettle();

    expect(await store.current(), isEmpty);
    expect(find.text('Removed from your library.'), findsOneWidget);
    expect(find.text('Literal'), findsNothing);
    expect(find.byTooltip('Save'), findsNWidgets(2));
  });

  testWidgets('unsaving one card after Save all re-enables Save all', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.text('Save all'));
    await tester.pumpAndSettle();

    expect(await store.current(), hasLength(2));
    expect(find.text('All saved'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'All saved'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Unsave').first);
    await tester.pumpAndSettle();

    expect(await store.current(), hasLength(1));
    expect(find.text('Save all'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save all'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('blocks gallery and camera until quota is ready', (tester) async {
    await pumpHome(tester, quotaReady: false);

    expect(find.text(ImageCaptureSection.quotaLoadingMessage), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Gallery'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Camera'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.bookmarks_outlined))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.translate))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('opens saved highlights while quota is still loading',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppConstants.homeRoute,
      routes: [
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => HomeScreen(
            savedHighlightsStore: store,
            debugHighlightResponse: const HighlightResponse(
              found: true,
              highlights: [serendipity, eloquent],
            ),
            debugMeaningLanguage: MeaningLanguage.english,
            debugScanId: 'scan-home',
            debugImage: imageFile,
            debugQuotaReady: false,
          ),
        ),
        GoRoute(
          path: AppConstants.savedRoute,
          builder: (context, state) => const Scaffold(
            body: Text('Saved library'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(ImageCaptureSection.quotaLoadingMessage), findsOneWidget);

    await tester.tap(find.byTooltip('Saved highlights'));
    await tester.pumpAndSettle();

    expect(find.text('Saved library'), findsOneWidget);
  });

  testWidgets('denied camera permission shows settings snackbar', (
    tester,
  ) async {
    var openedSettings = 0;
    await pumpHome(
      tester,
      requestCameraPermission: () async => false,
      openAppSettings: () async => openedSettings++,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Camera'));
    await tester.pumpAndSettle();

    expect(find.text(CameraPermission.photoMessage), findsOneWidget);
    await tester.tap(find.text(CameraPermission.settingsAction));
    await tester.pump();
    expect(openedSettings, 1);
  });

  testWidgets(
    'landscape scroll collapses capture until the app bar, then scrolls the list',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final highlights = [
        for (var i = 0; i < 8; i++)
          Highlight(
            text: 'phrase $i',
            literal: 'lit $i',
            contextual: 'ctx $i',
            color: '0xFFE8C547',
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            savedHighlightsStore: store,
            debugHighlightResponse: HighlightResponse(
              found: true,
              highlights: highlights,
            ),
            debugMeaningLanguage: MeaningLanguage.english,
            debugScanId: 'scan-home',
            debugImage: imageFile,
            debugQuotaReady: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.widgetWithText(OutlinedButton, 'Gallery').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Save all').hitTestable(), findsOneWidget);
      expect(find.text('phrase 0').hitTestable(), findsOneWidget);

      await _dragUntilHidden(
        tester,
        dragHandle: find.byType(NestedScrollView),
        hide: find.text('Save all'),
      );

      expect(find.text(AppConstants.appName).hitTestable(), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Gallery').hitTestable(),
        findsNothing,
      );
      expect(find.text('Save all').hitTestable(), findsNothing);
      expect(find.textContaining('phrase').hitTestable(), findsWidgets);

      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      final visiblePhrase = find.textContaining('phrase').hitTestable().first;
      expect(
        tester.getRect(visiblePhrase).top,
        greaterThan(appBarBottom - 1),
      );
      expect(tester.getRect(visiblePhrase).top, lessThan(appBarBottom + 80));

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, -420),
        2000,
      );
      await tester.pumpAndSettle();

      expect(find.text('phrase 0').hitTestable(), findsNothing);
      expect(find.textContaining('phrase').hitTestable(), findsWidgets);

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, 900),
        3000,
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Gallery').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Save all').hitTestable(), findsOneWidget);
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

final Uint8List _oneByOnePng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
