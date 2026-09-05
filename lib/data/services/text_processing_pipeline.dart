import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/entities/highlight.dart';
import '../../core/constants/app_constants.dart';
import 'dictionary_meaning_service.dart';
import 'highlight_extractor.dart';
import 'ocr_service.dart';
import 'opencv_highlight_detector.dart';

/// On-device pipeline: OpenCV highlight blobs + ML Kit OCR + dictionary.
class TextProcessingPipeline {
  TextProcessingPipeline({
    OpenCvHighlightDetector? detector,
    OcrService? ocr,
    HighlightExtractor? extractor,
    DictionaryMeaningService? meanings,
  })  : _detector = detector ?? OpenCvHighlightDetector(),
        _ocr = ocr ?? OcrService(),
        _extractor = extractor ?? HighlightExtractor(),
        _meanings = meanings ?? DictionaryMeaningService();

  final OpenCvHighlightDetector _detector;
  final OcrService _ocr;
  final HighlightExtractor _extractor;
  final DictionaryMeaningService _meanings;

  Future<HighlightResponse> process(
    File imageFile, {
    void Function(String status)? onStatus,
    bool lookupMeanings = true,
  }) async {
    onStatus?.call('Detecting highlighted text');
    final bytes = await imageFile.readAsBytes();
    final maskFuture = _detector.detect(bytes);

    onStatus?.call('Reading the page');
    final wordsFuture = _ocr.recognize(imageFile);

    final mask = await maskFuture;
    final words = await wordsFuture;
    final pageText = _ocr.fullPageText(words);

    if (mask.isEmpty) {
      return const HighlightResponse(found: false, highlights: []);
    }

    if (words.isEmpty) {
      return const HighlightResponse(found: false, highlights: []);
    }

    final phrases = _extractor.extractByBlobs(
      mask: mask,
      words: words,
      pageText: pageText,
    );

    if (phrases.isEmpty) {
      return const HighlightResponse(found: false, highlights: []);
    }

    if (!lookupMeanings) {
      return HighlightResponse(
        found: true,
        highlights: phrases
            .map(
              (p) => Highlight(
                text: p.text,
                literal: AppConstants.meaningPendingPlaceholder,
                contextual: '',
                color: p.colorHex,
                textColor: p.textColorHex,
              ),
            )
            .toList(),
      );
    }

    onStatus?.call('Looking up definitions');
    final result = await _meanings.explain(phrases);
    if (kDebugMode) {
      print(
        'Phrases=${phrases.length} dictionaryError=${_meanings.lastError}',
      );
    }
    return result;
  }

  String? get lastMeaningError => _meanings.lastError;

  bool get hadNetworkLookupFailure => _meanings.hadNetworkFailure;

  static bool hasLoadedDefinition(String literal) {
    return literal != AppConstants.meaningPendingPlaceholder &&
        literal != AppConstants.meaningUnavailablePlaceholder;
  }

  static bool hasAnyLoadedDefinition(List<Highlight> highlights) {
    return highlights.any((highlight) => hasLoadedDefinition(highlight.literal));
  }

  static bool hasPendingMeanings(List<Highlight> highlights) {
    return highlights.any((highlight) => _needsMeaningRefresh(highlight.literal));
  }

  static bool _needsMeaningRefresh(String literal) {
    return literal == AppConstants.meaningPendingPlaceholder ||
        literal == AppConstants.meaningUnavailablePlaceholder;
  }

  /// Fetches dictionary definitions for highlights that still need them.
  Future<HighlightResponse> refreshMeanings(List<Highlight> highlights) async {
    if (highlights.isEmpty) {
      return const HighlightResponse(found: false, highlights: []);
    }

    _meanings.resetLookupState();

    final updated = <Highlight>[];
    for (final highlight in highlights) {
      if (!_needsMeaningRefresh(highlight.literal)) {
        updated.add(highlight);
        continue;
      }

      final literal = await _meanings.lookupLiteral(highlight.text);
      if (literal != null && literal.isNotEmpty) {
        updated.add(highlight.copyWith(literal: literal));
      } else {
        updated.add(highlight);
      }
    }

    if (_meanings.hadNetworkFailure &&
        !hasAnyLoadedDefinition(updated) &&
        hasPendingMeanings(updated)) {
      _meanings.lastError = 'Could not load dictionary definitions.';
    }

    return HighlightResponse(found: true, highlights: updated);
  }
}
