import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/page_image_compressor.dart';

void main() {
  test('compress returns jpeg mime for .jpg paths', () async {
    final file = File('test/fixtures/tiny.jpg');
    expect(PageImageCompressor.mimeTypeFor(file.path), 'image/jpeg');
  });

  test('mimeTypeFor maps common extensions', () {
    expect(PageImageCompressor.mimeTypeFor('photo.png'), 'image/png');
    expect(PageImageCompressor.mimeTypeFor('photo.webp'), 'image/webp');
    expect(PageImageCompressor.mimeTypeFor('photo.heic'), 'image/heic');
    expect(PageImageCompressor.mimeTypeFor('photo.heif'), 'image/heic');
    expect(PageImageCompressor.mimeTypeFor('photo.JPG'), 'image/jpeg');
    expect(PageImageCompressor.mimeTypeFor('photo.unknown'), 'image/jpeg');
  });
}
