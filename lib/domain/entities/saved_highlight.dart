import 'dart:math';

import 'highlight.dart';

class SavedHighlight {
  const SavedHighlight({
    required this.id,
    required this.highlight,
    required this.meaningLanguageId,
    required this.savedAt,
    this.scanId,
  });

  final String id;
  final Highlight highlight;
  final String meaningLanguageId;
  final DateTime savedAt;
  final String? scanId;

  String get text => highlight.text;
  String get literal => highlight.literal;
  String get contextual => highlight.contextual;
  String get color => highlight.color;

  String get dedupKey => dedupKeyFor(text, meaningLanguageId);

  static String dedupKeyFor(String text, String meaningLanguageId) {
    return '${text.trim().toLowerCase()}\u0000$meaningLanguageId';
  }

  static String newId([Random? random]) {
    final rand = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'literal': literal,
      'contextual': contextual,
      'color': color,
      'meaningLanguageId': meaningLanguageId,
      'savedAt': savedAt.toIso8601String(),
      if (scanId != null && scanId!.isNotEmpty) 'scanId': scanId,
    };
  }

  factory SavedHighlight.fromJson(Map<String, dynamic> json) {
    final rawScanId = json['scanId'] as String?;
    return SavedHighlight(
      id: json['id'] as String,
      highlight: Highlight(
        text: json['text'] as String? ?? '',
        literal: json['literal'] as String? ?? '',
        contextual: json['contextual'] as String? ?? '',
        color: json['color'] as String? ?? '',
      ),
      meaningLanguageId: json['meaningLanguageId'] as String? ?? '',
      savedAt: DateTime.parse(json['savedAt'] as String),
      scanId: (rawScanId != null && rawScanId.isNotEmpty) ? rawScanId : null,
    );
  }
}
