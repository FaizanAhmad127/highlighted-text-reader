import 'dart:io';

import '../../domain/entities/highlight.dart';
import 'gemini_highlight_service.dart';
import 'page_image_compressor.dart';

class HighlightScanException implements Exception {
  HighlightScanException(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}

class HighlightScanService {
  HighlightScanService({
    PageImageCompressor? compressor,
    GeminiHighlightService? gemini,
  })  : _compressor = compressor ?? const PageImageCompressor(),
        _gemini = gemini ?? GeminiHighlightService();

  final PageImageCompressor _compressor;
  final GeminiHighlightService _gemini;

  Future<HighlightResponse> scan(
    File imageFile, {
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Preparing photo');
    final compressed = await _compressor.compress(imageFile);

    onStatus?.call('Finding highlighted text');
    try {
      return await _gemini.analyze(compressed);
    } catch (e) {
      throw HighlightScanException(
        'Could not read the page. Check your internet connection and try again.',
        cause: e,
      );
    }
  }
}
