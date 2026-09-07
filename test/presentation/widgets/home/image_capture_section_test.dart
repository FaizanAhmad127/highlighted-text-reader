import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/presentation/widgets/home/image_capture_section.dart';
import 'package:highlighted_text_reader/presentation/widgets/home/full_screen_image_viewer.dart';

void main() {
  late Directory tempDir;
  late File imageFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('preview_chip');
    imageFile = File('${tempDir.path}/page.png');
    await imageFile.writeAsBytes(_oneByOnePng);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('tapping Tap to expand opens the full page photo',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageCaptureSection(
            image: imageFile,
            isProcessing: false,
            offline: false,
            compact: true,
            quotaReady: true,
            onGallery: () {},
            onCamera: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tap to expand'));
    await tester.pumpAndSettle();

    expect(find.byType(FullScreenImageViewer), findsOneWidget);
  });

  testWidgets('disables gallery and camera until quota is ready',
      (tester) async {
    var galleryTaps = 0;
    var cameraTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageCaptureSection(
            isProcessing: false,
            offline: false,
            compact: false,
            quotaReady: false,
            onGallery: () => galleryTaps++,
            onCamera: () => cameraTaps++,
          ),
        ),
      ),
    );

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

    await tester.tap(find.text('Gallery'));
    await tester.tap(find.text('Camera'));
    expect(galleryTaps, 0);
    expect(cameraTaps, 0);
  });

  testWidgets('enables gallery and camera after quota is ready',
      (tester) async {
    var galleryTaps = 0;
    var cameraTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageCaptureSection(
            isProcessing: false,
            offline: false,
            compact: false,
            quotaReady: true,
            onGallery: () => galleryTaps++,
            onCamera: () => cameraTaps++,
          ),
        ),
      ),
    );

    expect(find.text(ImageCaptureSection.quotaLoadingMessage), findsNothing);
    await tester.tap(find.text('Gallery'));
    await tester.tap(find.text('Camera'));
    expect(galleryTaps, 1);
    expect(cameraTaps, 1);
  });

  testWidgets('keeps capture buttons disabled while a scan is processing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageCaptureSection(
            isProcessing: true,
            offline: false,
            compact: false,
            quotaReady: true,
            onGallery: () {},
            onCamera: () {},
          ),
        ),
      ),
    );

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
  });
}

/// 1x1 transparent PNG so Image.file has a real file to decode.
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
