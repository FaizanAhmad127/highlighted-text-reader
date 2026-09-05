import '../models/highlight_detection.dart';

/// Intersects OCR words with the highlighter mask and groups them into phrases.
class HighlightExtractor {
  /// Group OCR words per OpenCV highlight blob (better for angled book photos).
  List<ExtractedPhrase> extractByBlobs({
    required HighlightMask mask,
    required List<OcrWord> words,
    required String pageText,
  }) {
    if (mask.isEmpty || words.isEmpty) return const [];

    final phrases = <ExtractedPhrase>[];
    for (final blob in mask.blobs) {
      final left = blob.minX / mask.scaleX;
      final top = blob.minY / mask.scaleY;
      final right = (blob.maxX + 1) / mask.scaleX;
      final bottom = (blob.maxY + 1) / mask.scaleY;
      final padX = (right - left) * 0.05;
      final padY = (bottom - top) * 0.15;

      final inBlob = words.where((word) {
        final box = word.boundingBox;
        final cx = (box.left + box.right) / 2;
        final cy = (box.top + box.bottom) / 2;
        return cx >= left - padX &&
            cx <= right + padX &&
            cy >= top - padY &&
            cy <= bottom + padY;
      }).toList();

      if (inBlob.isEmpty) continue;

      inBlob.sort((a, b) {
        final dy = a.boundingBox.top.compareTo(b.boundingBox.top);
        if (dy.abs() > 8) return dy;
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      });

      final text = _groupWords(inBlob);
      if (text.trim().length < 2) continue;

      phrases.add(
        ExtractedPhrase(
          text: text,
          surroundingContext: _surroundingContext(inBlob, words, pageText),
          colorHex: blob.colorHex,
          textColorHex: blob.textColorHex,
        ),
      );
    }

    return _dedupePhrases(phrases);
  }

  String _groupWords(List<OcrWord> words) {
    if (words.isEmpty) return '';
    final buffer = StringBuffer(words.first.text);
    for (var i = 1; i < words.length; i++) {
      final prev = words[i - 1];
      final word = words[i];
      final sameLine =
          (word.boundingBox.top - prev.boundingBox.top).abs() < 12;
      buffer.write(sameLine ? ' ' : '\n');
      buffer.write(word.text);
    }
    return buffer.toString().replaceAll('\n ', '\n').trim();
  }

  List<ExtractedPhrase> _dedupePhrases(List<ExtractedPhrase> phrases) {
    if (phrases.length <= 1) return phrases;
    final kept = <ExtractedPhrase>[];
    for (final phrase in phrases) {
      final dup = kept.any(
        (k) =>
            k.text.contains(phrase.text) ||
            (phrase.text.contains(k.text) &&
                phrase.text.length <= k.text.length),
      );
      if (!dup) kept.add(phrase);
    }
    return kept;
  }

  String _surroundingContext(
    List<OcrWord> group,
    List<OcrWord> allWords,
    String pageText,
  ) {
    final block = group.first.blockIndex;
    final line = group.first.lineIndex;
    final nearby = allWords.where(
      (w) => w.blockIndex == block && (w.lineIndex - line).abs() <= 1,
    );
    final lineText = nearby.map((w) => w.text).join(' ');
    if (lineText.trim().length >= 20) return lineText;
    if (pageText.length <= 1800) return pageText;
    return pageText.substring(0, 1800);
  }
}
