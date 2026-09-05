class Highlight {
  final String text;
  final String literal;
  final String color;
  final String textColor;

  const Highlight({
    required this.text,
    required this.literal,
    required this.color,
    required this.textColor,
  });

  Highlight copyWith({
    String? text,
    String? literal,
    String? color,
    String? textColor,
  }) {
    return Highlight(
      text: text ?? this.text,
      literal: literal ?? this.literal,
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
    );
  }
}

class HighlightResponse {
  final bool found;
  final List<Highlight>? highlights;

  const HighlightResponse({
    required this.found,
    this.highlights,
  });

  HighlightResponse copyWith({
    bool? found,
    List<Highlight>? highlights,
  }) {
    return HighlightResponse(
      found: found ?? this.found,
      highlights: highlights ?? this.highlights,
    );
  }
}
