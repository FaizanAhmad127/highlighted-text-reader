import 'dart:io';

import 'package:flutter/material.dart';

import 'full_screen_image_viewer.dart';

/// Top capture area: page preview, processing state, and gallery/camera actions.
class ImageCaptureSection extends StatelessWidget {
  const ImageCaptureSection({
    super.key,
    this.image,
    required this.isProcessing,
    this.status,
    required this.offline,
    required this.compact,
    required this.quotaReady,
    required this.onGallery,
    required this.onCamera,
    this.scansUsed,
    this.scansMax,
    this.onRequestExtraQuota,
  });

  static const quotaLoadingMessage = 'Please wait, loading assets';

  final File? image;
  final bool isProcessing;
  final String? status;
  final bool offline;
  final bool compact;
  final bool quotaReady;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final int? scansUsed;
  final int? scansMax;
  final VoidCallback? onRequestExtraQuota;

  bool get _captureEnabled => quotaReady && !offline && !isProcessing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final previewMaxHeight =
        compact ? 112.0 : (image != null ? screenHeight * 0.32 : 200.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offline)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OfflineBanner(theme: theme),
            ),
          if (!quotaReady)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QuotaLoadingBanner(theme: theme),
            ),
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: previewMaxHeight,
                  child: _PreviewArea(
                    image: image,
                    isProcessing: isProcessing,
                    status: status,
                    compact: compact,
                    theme: theme,
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CaptureActionButton(
                          label: 'Gallery',
                          icon: Icons.photo_library_outlined,
                          onPressed: _captureEnabled ? onGallery : null,
                          filled: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CaptureActionButton(
                          label: 'Camera',
                          icon: Icons.camera_alt_outlined,
                          onPressed: _captureEnabled ? onCamera : null,
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!compact && image == null) ...[
            const SizedBox(height: 10),
            Text(
              'Use a sharp, well-lit photo of a book page with highlighter marks.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (scansUsed != null && scansMax != null) ...[
            const SizedBox(height: 10),
            _QuotaLabel(
              used: scansUsed!,
              max: scansMax!,
              onRequestExtraQuota: onRequestExtraQuota,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuotaLabel extends StatelessWidget {
  const _QuotaLabel({
    required this.used,
    required this.max,
    this.onRequestExtraQuota,
  });

  final int used;
  final int max;
  final VoidCallback? onRequestExtraQuota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atLimit = used >= max;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: atLimit
          ? theme.colorScheme.error
          : theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final countLabel = '$used of $max scans today';

    if (atLimit && onRequestExtraQuota != null) {
      return Column(
        children: [
          Text(countLabel, textAlign: TextAlign.center, style: style),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRequestExtraQuota,
            icon: const Icon(Icons.mail_outline, size: 16),
            label: const Text('Request extra'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.55),
              ),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Text(countLabel, textAlign: TextAlign.center, style: style);
  }
}

class _QuotaLoadingBanner extends StatelessWidget {
  const _QuotaLoadingBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ImageCaptureSection.quotaLoadingMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — connect to the internet to scan a page',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({
    required this.image,
    required this.isProcessing,
    required this.status,
    required this.compact,
    required this.theme,
  });

  final File? image;
  final bool isProcessing;
  final String? status;
  final bool compact;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return _EmptyPreview(theme: theme);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isProcessing
            ? null
            : () => FullScreenImageViewer.open(context, image!),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              image!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            if (isProcessing) _ProcessingOverlay(status: status, theme: theme),
            if (!isProcessing)
              Positioned(
                left: 10,
                bottom: 10,
                right: 10,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _PreviewChip(
                    icon: Icons.fullscreen_rounded,
                    label: compact ? 'Tap to expand' : 'Tap to view full image',
                    theme: theme,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_outlined,
              size: 28,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Scan a highlighted page',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your photo will appear here',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay({
    required this.status,
    required this.theme,
  });

  final String? status;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                status ?? 'Processing…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureActionButton extends StatelessWidget {
  const _CaptureActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        foregroundColor: theme.colorScheme.primary,
        side: BorderSide(color: theme.colorScheme.outline),
      ),
    );
  }
}
