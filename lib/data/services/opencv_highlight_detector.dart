import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv.dart' as cv;

import '../models/highlight_detection.dart';

/// Detects highlighter ink using OpenCV (morphology + CC) and Dart color logic.
class OpenCvHighlightDetector {
  static const int _maxWidth = 800;

  Future<HighlightMask> detect(List<int> imageBytes) async {
    try {
      final bytes =
          imageBytes is Uint8List ? imageBytes : Uint8List.fromList(imageBytes);
      return _detectIsolate(bytes);
    } catch (e, st) {
      if (kDebugMode) {
        print('Highlight detection failed: $e\n$st');
      }
      return _emptyMask();
    }
  }

  static HighlightMask _detectIsolate(Uint8List bytes) {
    cv.Mat? decoded;
    cv.Mat? bgr;
    cv.Mat? working;
    cv.Mat? rawMat;
    cv.Mat? kernel;
    cv.Mat? closed;
    cv.Mat? labels;
    cv.Mat? stats;
    cv.Mat? centroids;

    try {
      decoded = cv.imdecode(bytes, cv.IMREAD_COLOR);
      if (decoded.isEmpty) {
        return _emptyMask();
      }

      bgr = decoded;
      if (decoded.channels == 4) {
        bgr = cv.cvtColor(decoded, cv.COLOR_BGRA2BGR);
      }

      working = bgr;
      final sourceWidth = bgr.cols;
      final sourceHeight = bgr.rows;
      if (sourceWidth > _maxWidth) {
        final scale = _maxWidth / sourceWidth;
        working = cv.resize(
          bgr,
          (0, 0),
          fx: scale,
          fy: scale,
          interpolation: cv.INTER_AREA,
        );
      }

      final width = working.cols;
      final height = working.rows;
      final paper = _estimatePaperBgr(working);
      final paperHsv = _rgbToHsv(paper.$1, paper.$2, paper.$3);

      final raw = Uint8List(width * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final pixel = working.atPixel(y, x);
          final b = pixel[0].toInt();
          final g = pixel[1].toInt();
          final r = pixel[2].toInt();
          if (_isHighlighterPixel(r, g, b, paper, paperHsv)) {
            raw[y * width + x] = 255;
          }
        }
      }

      rawMat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, raw.toList());
      kernel = cv.getStructuringElement(cv.MORPH_RECT, (5, 3));
      closed = cv.morphologyEx(
        rawMat,
        cv.MORPH_CLOSE,
        kernel,
        iterations: 1,
      );

      labels = cv.Mat.empty();
      stats = cv.Mat.empty();
      centroids = cv.Mat.empty();
      cv.connectedComponentsWithStats(
        closed,
        labels,
        stats,
        centroids,
        8,
        cv.MatType.CV_32SC1.value,
        cv.CCL_DEFAULT,
      );

      final minPixels = math.max(24, (width * height * 0.0004).round());
      final numLabels = stats.rows;
      final blobs = <HighlightBlob>[];

      for (var label = 1; label < numLabels; label++) {
        final area = stats.atI32(label, i1: cv.CC_STAT_AREA);
        if (area < minPixels) continue;

        final x = stats.atI32(label, i1: cv.CC_STAT_LEFT);
        final y = stats.atI32(label, i1: cv.CC_STAT_TOP);
        final w = stats.atI32(label, i1: cv.CC_STAT_WIDTH);
        final h = stats.atI32(label, i1: cv.CC_STAT_HEIGHT);

        final (r, g, b) = _averageBlobColor(working, x, y, w, h);
        final color = 0xFF000000 | (r << 16) | (g << 8) | b;
        blobs.add(
          HighlightBlob(
            minX: x,
            minY: y,
            maxX: x + w - 1,
            maxY: y + h - 1,
            pixelCount: area,
            color: color,
            textColor: _contrastColor(r, g, b),
          ),
        );
      }

      blobs.sort((a, b) {
        final dy = a.minY.compareTo(b.minY);
        return dy != 0 ? dy : a.minX.compareTo(b.minX);
      });

      final pixels = Uint8List(width * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          pixels[y * width + x] = closed.atU8(y, i1: x) > 0 ? 1 : 0;
        }
      }

      return HighlightMask(
        width: width,
        height: height,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        pixels: pixels,
        blobs: blobs,
      );
    } finally {
      decoded?.dispose();
      if (bgr != null && bgr != decoded) bgr.dispose();
      if (working != null && working != bgr) working.dispose();
      rawMat?.dispose();
      kernel?.dispose();
      closed?.dispose();
      labels?.dispose();
      stats?.dispose();
      centroids?.dispose();
    }
  }

  static (int, int, int) _averageBlobColor(
    cv.Mat bgr,
    int x,
    int y,
    int w,
    int h,
  ) {
    var rSum = 0, gSum = 0, bSum = 0, count = 0;
    final stepX = math.max(1, w ~/ 6);
    final stepY = math.max(1, h ~/ 4);
    for (var py = y; py < y + h; py += stepY) {
      for (var px = x; px < x + w; px += stepX) {
        if (py < 0 || px < 0 || py >= bgr.rows || px >= bgr.cols) continue;
        final pixel = bgr.atPixel(py, px);
        bSum += pixel[0].toInt();
        gSum += pixel[1].toInt();
        rSum += pixel[2].toInt();
        count++;
      }
    }
    if (count == 0) {
      final cy = (y + h ~/ 2).clamp(0, bgr.rows - 1);
      final cx = (x + w ~/ 2).clamp(0, bgr.cols - 1);
      final pixel = bgr.atPixel(cy, cx);
      return (pixel[2].toInt(), pixel[1].toInt(), pixel[0].toInt());
    }
    return (rSum ~/ count, gSum ~/ count, bSum ~/ count);
  }

  static HighlightMask _emptyMask() {
    return const HighlightMask(
      width: 1,
      height: 1,
      sourceWidth: 1,
      sourceHeight: 1,
      pixels: [0],
      blobs: [],
    );
  }

  static (int, int, int) _estimatePaperBgr(cv.Mat bgr) {
    final counts = <int, List<int>>{};
    final h = bgr.rows;
    final w = bgr.cols;
    final step = math.max(4, math.min(h, w) ~/ 80);

    for (var y = 0; y < h; y += step) {
      for (var x = 0; x < w; x += step) {
        final pixel = bgr.atPixel(y, x);
        final b = pixel[0].toInt();
        final g = pixel[1].toInt();
        final r = pixel[2].toInt();
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        if (lum < 0.45 * 255) continue;
        final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
        final bucket = counts.putIfAbsent(key, () => [0, 0, 0, 0]);
        bucket[0] += r;
        bucket[1] += g;
        bucket[2] += b;
        bucket[3] += 1;
      }
    }

    if (counts.isEmpty) return (255, 255, 255);

    var bestKey = counts.keys.first;
    var bestCount = -1;
    for (final entry in counts.entries) {
      if (entry.value[3] > bestCount) {
        bestCount = entry.value[3];
        bestKey = entry.key;
      }
    }
    final sum = counts[bestKey]!;
    return (sum[0] ~/ sum[3], sum[1] ~/ sum[3], sum[2] ~/ sum[3]);
  }

  static (double h, double s, double v) _rgbToHsv(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;
    final max = math.max(rf, math.max(gf, bf));
    final min = math.min(rf, math.min(gf, bf));
    final d = max - min;
    var h = 0.0;
    if (d != 0) {
      if (max == rf) {
        h = 60 * (((gf - bf) / d) % 6);
      } else if (max == gf) {
        h = 60 * (((bf - rf) / d) + 2);
      } else {
        h = 60 * (((rf - gf) / d) + 4);
      }
    }
    if (h < 0) h += 360;
    final s = max == 0 ? 0.0 : d / max;
    return (h, s, max);
  }

  static bool _isHighlighterPixel(
    int r,
    int g,
    int b,
    (int, int, int) paper,
    (double, double, double) paperHsv,
  ) {
    final hsv = _rgbToHsv(r, g, b);
    final h = hsv.$1;
    final s = hsv.$2;
    final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;

    if (lum < 0.35 || lum > 0.97) return false;
    if (s < 0.20) return false;

    final (pr, pg, pb) = paper;
    final paperDiff = (r - pr).abs() + (g - pg).abs() + (b - pb).abs();
    if (paperDiff < 45) return false;

    final (ph, ps, _) = paperHsv;
    if (ps >= 0.18) {
      final hueDist = _hueDistance(h, ph);
      final saturatedEnough = s >= ps + 0.12;
      if (hueDist < 45 && !saturatedEnough) return false;
    } else if (s < ps + 0.16) {
      return false;
    }

    final isPink = (h >= 275 && h <= 350) || (h <= 12 && s > 0.28);
    final isYellow = h >= 40 && h <= 72 && s > 0.25;
    final isGreen = h >= 80 && h <= 165 && s > 0.28;
    final isOrange = h >= 16 && h <= 40 && s > 0.28;
    final isBlue = h >= 170 && h <= 250 && s > 0.35;
    final isMagenta = h >= 300 && s > 0.22;
    return isPink || isYellow || isGreen || isOrange || isBlue || isMagenta;
  }

  static double _hueDistance(double a, double b) {
    final d = (a - b).abs() % 360;
    return math.min(d, 360 - d);
  }

  static int _contrastColor(int r, int g, int b) {
    final lum = 0.299 * r + 0.587 * g + 0.114 * b;
    return lum > 150 ? 0xFF000000 : 0xFFFFFFFF;
  }
}
