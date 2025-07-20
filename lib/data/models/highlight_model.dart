import 'dart:convert';
import '../../domain/entities/highlight.dart';

class HighlightModel extends Highlight {
  const HighlightModel({
    required super.text,
    required super.literal,
    required super.contextual,
    required super.color,
    required super.textColor,
  });

  factory HighlightModel.fromMap(Map<String, dynamic> map) {
    return HighlightModel(
      text: map['text'] ?? '',
      literal: map['literal'] ?? '',
      contextual: map['contextual'] ?? '',
      color: map['color'] ?? '',
      textColor: map['textColor'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'literal': literal,
      'contextual': contextual,
      'color': color,
      'textColor': textColor,
    };
  }

  factory HighlightModel.fromEntity(Highlight highlight) {
    return HighlightModel(
      text: highlight.text,
      literal: highlight.literal,
      contextual: highlight.contextual,
      color: highlight.color,
      textColor: highlight.textColor,
    );
  }

  Highlight toEntity() {
    return Highlight(
      text: text,
      literal: literal,
      contextual: contextual,
      color: color,
      textColor: textColor,
    );
  }
}

class HighlightResponseModel extends HighlightResponse {
  const HighlightResponseModel({
    required super.found,
    super.highlights,
  });

  factory HighlightResponseModel.fromJson(String source) =>
      HighlightResponseModel.fromMap(json.decode(source));

  factory HighlightResponseModel.fromMap(Map<String, dynamic> map) {
    return HighlightResponseModel(
      found: map['found'] ?? false,
      highlights: map['found'] == true
          ? List<HighlightModel>.from(
              map['highlights']?.map((x) => HighlightModel.fromMap(x)) ?? [])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'found': found,
      'highlights':
          highlights?.map((x) => (x as HighlightModel).toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  factory HighlightResponseModel.fromEntity(HighlightResponse response) {
    return HighlightResponseModel(
      found: response.found,
      highlights: response.highlights
          ?.map((h) => HighlightModel.fromEntity(h))
          .toList(),
    );
  }

  HighlightResponse toEntity() {
    return HighlightResponse(
      found: found,
      highlights: highlights?.map((h) => h as Highlight).toList(),
    );
  }
}
