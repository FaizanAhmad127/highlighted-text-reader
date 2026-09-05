class Highlight {
  final String text;
  final String literal;
  final String contextual;
  final String color;

  const Highlight({
    required this.text,
    required this.literal,
    required this.contextual,
    required this.color,
  });
}

class HighlightResponse {
  final bool found;
  final List<Highlight>? highlights;

  const HighlightResponse({
    required this.found,
    this.highlights,
  });
}
