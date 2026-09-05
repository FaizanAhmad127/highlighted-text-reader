import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/highlight_detection.dart';

/// On-device OCR via Google ML Kit (Android / iOS).
class OcrService {
  Future<List<OcrWord>> recognize(File imageFile) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw UnsupportedError(
        'On-device OCR is only available on Android and iOS.',
      );
    }

    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(inputImage);
      final words = <OcrWord>[];
      for (var b = 0; b < result.blocks.length; b++) {
        final block = result.blocks[b];
        for (var l = 0; l < block.lines.length; l++) {
          final line = block.lines[l];
          for (var w = 0; w < line.elements.length; w++) {
            final element = line.elements[w];
            final box = element.boundingBox;
            final text = element.text.trim();
            if (text.isEmpty) continue;
            words.add(
              OcrWord(
                text: text,
                boundingBox: WordBox(
                  left: box.left,
                  top: box.top,
                  right: box.right,
                  bottom: box.bottom,
                ),
                blockIndex: b,
                lineIndex: l,
                wordIndex: w,
              ),
            );
          }
        }
      }
      return words;
    } finally {
      await recognizer.close();
    }
  }

  String fullPageText(List<OcrWord> words) {
    if (words.isEmpty) return '';
    final buffer = StringBuffer();
    var lastBlock = words.first.blockIndex;
    var lastLine = words.first.lineIndex;
    for (final word in words) {
      if (word.blockIndex != lastBlock) {
        buffer.write('\n\n');
        lastBlock = word.blockIndex;
        lastLine = word.lineIndex;
      } else if (word.lineIndex != lastLine) {
        buffer.write('\n');
        lastLine = word.lineIndex;
      } else if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(word.text);
    }
    return buffer.toString();
  }
}
