import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/highlight.dart';
import '../../domain/entities/meaning_language.dart';
import 'gemini_highlight_service.dart';
import 'page_image_compressor.dart';

class HighlightScanException implements Exception {
  HighlightScanException(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}

/// Maps Gemini / network failures to short user-facing copy.
/// Internet copy is not used here — HomeScreen shows that only on real
/// connectivity changes.
class HighlightScanErrors {
  static const timedOut =
      'Could not read the page. The request timed out. Try again.';
  static const quota =
      'Too many scans right now. Wait a moment and try again.';
  static const billing =
      'Scanning is paused right now. Please try again later.';
  static const unavailable =
      'Scanning is temporarily unavailable. Please try again later.';
  static const region = 'Scanning is not available in your region yet.';
  static const generic = 'Could not read the page. Please try again.';

  static String userMessage(Object error) {
    if (error is TimeoutException) return timedOut;
    if (error is QuotaExceeded ||
        _contains(error, const ['quota', 'resource_exhausted', 'rate limit'])) {
      return quota;
    }
    if (_contains(error, const [
      'billing',
      'prepaid',
      'prepay',
      'payment required',
      'insufficient',
      'consumer',
      'suspended',
    ])) {
      return billing;
    }
    if (error is ServiceApiNotEnabled ||
        error is InvalidApiKey ||
        _contains(error, const [
          'permission_denied',
          'app check',
          'unauthenticated',
          'appattest',
          'user-not-found',
          'user-token-expired',
          'invalid-user-token',
        ])) {
      return unavailable;
    }
    if (error is UnsupportedUserLocation) return region;
    return generic;
  }

  static bool _contains(Object error, List<String> needles) {
    final haystack = error.toString().toLowerCase();
    return needles.any(haystack.contains);
  }
}

class HighlightScanService {
  HighlightScanService({
    PageImageCompressor? compressor,
    GeminiHighlightService? gemini,
    Duration geminiTimeout = defaultGeminiTimeout,
  })  : _compressor = compressor ?? const PageImageCompressor(),
        _gemini = gemini ?? GeminiHighlightService(),
        _geminiTimeout = geminiTimeout;

  static const Duration defaultGeminiTimeout = Duration(seconds: 45);

  final PageImageCompressor _compressor;
  final GeminiHighlightService _gemini;
  final Duration _geminiTimeout;

  Future<HighlightResponse> scan(
    File imageFile, {
    MeaningLanguage meaningLanguage = MeaningLanguage.defaultLanguage,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Preparing photo');
    final compressed = await _compressor.compress(imageFile);

    onStatus?.call('Finding highlighted text');
    try {
      return await _gemini
          .analyze(compressed, meaningLanguage: meaningLanguage)
          .timeout(_geminiTimeout);
    } on TimeoutException catch (e) {
      throw HighlightScanException(
        HighlightScanErrors.timedOut,
        cause: e,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Highlight scan failed: $e');
      }
      throw HighlightScanException(
        HighlightScanErrors.userMessage(e),
        cause: e,
      );
    }
  }
}
