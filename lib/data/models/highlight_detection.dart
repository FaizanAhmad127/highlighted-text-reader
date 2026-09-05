/// Downsampled highlight mask plus detected blobs.
class HighlightMask {
  final int width;
  final int height;
  final int sourceWidth;
  final int sourceHeight;
  final List<int> pixels; // 1 = highlighter, 0 = not
  final List<HighlightBlob> blobs;

  const HighlightMask({
    required this.width,
    required this.height,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.pixels,
    required this.blobs,
  });

  bool get isEmpty => blobs.isEmpty;

  double get scaleX => width / sourceWidth;
  double get scaleY => height / sourceHeight;

  bool isHighlighted(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    return pixels[y * width + x] == 1;
  }
}

class HighlightBlob {
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
  final int pixelCount;
  final int color; // 0xAARRGGBB
  final int textColor;

  const HighlightBlob({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.pixelCount,
    required this.color,
    required this.textColor,
  });

  String get colorHex =>
      '0x${color.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  String get textColorHex =>
      '0x${textColor.toRadixString(16).toUpperCase().padLeft(8, '0')}';
}

class WordBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const WordBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
}

class OcrWord {
  final String text;
  final WordBox boundingBox;
  final int blockIndex;
  final int lineIndex;
  final int wordIndex;

  const OcrWord({
    required this.text,
    required this.boundingBox,
    required this.blockIndex,
    required this.lineIndex,
    required this.wordIndex,
  });
}

class ExtractedPhrase {
  final String text;
  final String surroundingContext;
  final String colorHex;
  final String textColorHex;

  const ExtractedPhrase({
    required this.text,
    required this.surroundingContext,
    required this.colorHex,
    required this.textColorHex,
  });
}
