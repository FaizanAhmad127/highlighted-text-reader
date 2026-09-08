import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/gemini_highlight_service.dart';
import 'package:highlighted_text_reader/data/services/highlight_scan_service.dart';
import 'package:highlighted_text_reader/data/services/page_image_compressor.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';
import 'package:highlighted_text_reader/domain/entities/meaning_language.dart';

void main() {
  test('maps empty Gemini content to a try-another-photo message', () {
    expect(
      HighlightScanErrors.userMessage(
        Exception(
          'Unhandled format for Content: {}\n'
          'This indicates a problem with the Firebase AI Logic SDK.',
        ),
      ),
      HighlightScanErrors.unreadable,
    );
  });

  test('maps prepaid billing errors to a paused-scanning message', () {
    expect(
      HighlightScanErrors.userMessage(
        Exception('Add funds to your prepaid billing account'),
      ),
      HighlightScanErrors.billing,
    );
  });

  test('maps quota errors to a wait-and-retry message', () {
    expect(
      HighlightScanErrors.userMessage(
        Exception('RESOURCE_EXHAUSTED: quota exceeded'),
      ),
      HighlightScanErrors.quota,
    );
  });

  test('maps a deleted Firebase Auth user to a temporary-unavailable message',
      () {
    expect(
      HighlightScanErrors.userMessage(
        Exception(
          '[firebase_auth/user-not-found] There is no user record corresponding to this identifier.',
        ),
      ),
      HighlightScanErrors.unavailable,
    );
  });

  test('maps permission errors to a temporary-unavailable message', () {
    expect(
      HighlightScanErrors.userMessage(
        Exception('PERMISSION_DENIED: Firebase App Check token is invalid'),
      ),
      HighlightScanErrors.unavailable,
    );
  });

  test('scan uses a generic retry message, not an internet message', () async {
    final service = HighlightScanService(
      compressor: _FakeCompressor(),
      gemini: _ThrowingGemini(),
    );

    await expectLater(
      service.scan(File('unused.jpg')),
      throwsA(
        isA<HighlightScanException>().having(
          (error) => error.userMessage,
          'userMessage',
          HighlightScanErrors.generic,
        ),
      ),
    );
  });

  test('scan reports a timed out Gemini request', () async {
    final service = HighlightScanService(
      compressor: _FakeCompressor(),
      gemini: _NeverCompletesGemini(),
      geminiTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      service.scan(File('unused.jpg')),
      throwsA(
        isA<HighlightScanException>().having(
          (error) => error.userMessage,
          'userMessage',
          HighlightScanErrors.timedOut,
        ),
      ),
    );
  });
}

class _FakeCompressor implements PageImageCompressor {
  @override
  Future<CompressedPageImage> compress(File imageFile) async {
    return CompressedPageImage(bytes: Uint8List.fromList([1, 2, 3]));
  }
}

class _ThrowingGemini implements GeminiHighlightService {
  @override
  Future<HighlightResponse> analyze(
    CompressedPageImage image, {
    MeaningLanguage meaningLanguage = MeaningLanguage.defaultLanguage,
  }) async {
    throw StateError('Gemini failed');
  }
}

class _NeverCompletesGemini implements GeminiHighlightService {
  @override
  Future<HighlightResponse> analyze(
    CompressedPageImage image, {
    MeaningLanguage meaningLanguage = MeaningLanguage.defaultLanguage,
  }) {
    return Completer<HighlightResponse>().future;
  }
}
