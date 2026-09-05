import 'dart:io';
import 'dart:typed_data';

class CompressedPageImage {
  const CompressedPageImage({
    required this.bytes,
    this.mimeType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String mimeType;
}

class PageImageCompressor {
  const PageImageCompressor();

  Future<CompressedPageImage> compress(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return CompressedPageImage(
      bytes: bytes,
      mimeType: mimeTypeFor(imageFile.path),
    );
  }

  static String mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
