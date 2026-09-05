import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen page photo viewer with pinch-to-zoom.
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({super.key, required this.image});

  final File image;

  static Future<void> open(BuildContext context, File image) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => FullScreenImageViewer(image: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Page photo'),
          centerTitle: true,
        ),
        body: InteractiveViewer(
          minScale: 0.75,
          maxScale: 5,
          child: Center(
            child: Image.file(
              image,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
