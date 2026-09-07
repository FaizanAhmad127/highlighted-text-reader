import 'dart:convert';

import '../../core/firebase/app_crashlytics.dart';
import '../../domain/entities/highlight.dart';

class GeminiHighlightParser {
  static const defaultInk = '0xFFE8C547';

  static HighlightResponse parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const HighlightResponse(found: false, highlights: []);
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const HighlightResponse(found: false, highlights: []);
      }
      final items = decoded['highlights'];
      if (items is! List) {
        return const HighlightResponse(found: false, highlights: []);
      }
      final highlights = <Highlight>[];
      for (final item in items) {
        if (item is! Map) continue;
        final text = '${item['text'] ?? ''}'.trim();
        if (text.length < 2) continue;
        final literal = '${item['literal'] ?? ''}'.trim();
        final contextual = '${item['contextual'] ?? ''}'.trim();
        highlights.add(
          Highlight(
            text: text,
            literal: literal.isEmpty ? 'Meaning unavailable.' : literal,
            contextual: contextual,
            color: _color('${item['color'] ?? ''}'),
          ),
        );
      }
      return HighlightResponse(
        found: highlights.isNotEmpty,
        highlights: highlights,
      );
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'gemini_parse');
      return const HighlightResponse(found: false, highlights: []);
    }
  }

  static String _color(String raw) {
    final value = raw.trim();
    if (RegExp(r'^0x[0-9A-Fa-f]{8}$').hasMatch(value)) return value;
    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return '0xFF${value.substring(1).toUpperCase()}';
    }
    return defaultInk;
  }
}
