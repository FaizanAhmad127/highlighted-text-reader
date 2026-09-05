import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/gemini_highlight_service.dart';
import 'package:highlighted_text_reader/data/services/highlight_scan_service.dart';
import 'package:highlighted_text_reader/data/services/page_image_compressor.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';

void main() {
  test('scan preserves the generic message for Gemini failures', () async {
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
          'Could not read the page. Check your internet connection and try again.',
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
          'Could not read the page. The request timed out. Try again.',
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
  Future<HighlightResponse> analyze(CompressedPageImage image) async {
    throw StateError('Gemini failed');
  }
}

class _NeverCompletesGemini implements GeminiHighlightService {
  @override
  Future<HighlightResponse> analyze(CompressedPageImage image) {
    return Completer<HighlightResponse>().future;
  }
}
