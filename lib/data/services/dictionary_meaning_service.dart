import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/highlight.dart';
import '../models/highlight_detection.dart';
import '../../core/constants/app_constants.dart';

/// Looks up dictionary definitions for highlighted phrases (no AI).
class DictionaryMeaningService {
  DictionaryMeaningService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Future<String?>> _wordCache = {};
  String? lastError;
  bool _networkFailure = false;

  bool get hadNetworkFailure => _networkFailure;

  void resetLookupState() {
    lastError = null;
    _networkFailure = false;
    _wordCache.clear();
  }

  Future<HighlightResponse> explain(List<ExtractedPhrase> phrases) async {
    resetLookupState();
    if (phrases.isEmpty) {
      return const HighlightResponse(found: false, highlights: []);
    }

    final literals = await Future.wait(
      phrases.map((phrase) => lookupLiteral(phrase.text)),
    );

    var foundAny = false;
    var missedAny = false;
    final highlights = <Highlight>[];

    for (var i = 0; i < phrases.length; i++) {
      final phrase = phrases[i];
      final literal = literals[i];
      if (literal != null && literal.isNotEmpty) {
        foundAny = true;
      } else {
        missedAny = true;
      }
      highlights.add(
        Highlight(
          text: phrase.text,
          literal: literal ?? AppConstants.meaningUnavailablePlaceholder,
          color: phrase.colorHex,
          textColor: phrase.textColorHex,
        ),
      );
    }

    if (missedAny && !foundAny && _networkFailure) {
      lastError = 'Could not load dictionary definitions.';
    }

    return HighlightResponse(
      found: highlights.isNotEmpty,
      highlights: highlights,
    );
  }

  Future<String?> lookupLiteral(String phrase) async {
    final cleaned = _cleanPhrase(phrase);
    if (cleaned.isEmpty) return null;

    if (!cleaned.contains(' ')) {
      return _lookupWord(cleaned.toLowerCase());
    }

    final words = cleaned
        .split(' ')
        .where((w) => w.length > 1)
        .toList(growable: false);
    if (words.isEmpty) return null;

    final defs = await Future.wait(
      words.map((word) async {
        final def = await _lookupWord(word.toLowerCase());
        if (def == null || def.isEmpty) return null;
        final label = word[0].toUpperCase() + word.substring(1).toLowerCase();
        return '$label: $def';
      }),
    );

    final parts = defs.whereType<String>().toList(growable: false);
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  String _cleanPhrase(String phrase) {
    return phrase
        .replaceAll(RegExp(r'\.{2,}'), ' ')
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<String?> _lookupWord(String word) {
    if (word.isEmpty) return Future.value(null);
    return _wordCache.putIfAbsent(word, () async {
      final datamuse = await _lookupDatamuse(word);
      if (datamuse != null) return datamuse;
      return _lookupFreeDictionary(word);
    });
  }

  Future<String?> _lookupDatamuse(String word) async {
    try {
      final uri = Uri.https(
        'api.datamuse.com',
        '/words',
        {'sp': word, 'md': 'd', 'max': '1'},
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data is! List || data.isEmpty) return null;
      final defs = data.first['defs'];
      if (defs is! List || defs.isEmpty) return null;
      return _parseDatamuseDefinition(defs.first);
    } catch (e) {
      if (_isNetworkError(e)) _networkFailure = true;
      if (kDebugMode) {
        print('Datamuse lookup failed for "$word": $e');
      }
      return null;
    }
  }

  String? _parseDatamuseDefinition(Object raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final parts = raw.split('\t');
    final def = (parts.length > 1 ? parts.sublist(1).join(' ') : raw).trim();
    return def.isEmpty ? null : def;
  }

  Future<String?> _lookupFreeDictionary(String word) async {
    try {
      final uri = Uri.parse(
        'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}',
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data is! List || data.isEmpty) return null;
      final meanings = data.first['meanings'];
      if (meanings is! List || meanings.isEmpty) return null;
      final defs = meanings.first['definitions'];
      if (defs is! List || defs.isEmpty) return null;
      final def = defs.first['definition'];
      if (def is String && def.isNotEmpty) return def;
    } catch (e) {
      if (_isNetworkError(e)) _networkFailure = true;
      if (kDebugMode) {
        print('Free Dictionary lookup failed for "$word": $e');
      }
    }
    return null;
  }

  bool _isNetworkError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is http.ClientException;
  }
}
