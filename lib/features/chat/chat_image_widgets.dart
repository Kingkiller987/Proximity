import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/media/media_sanitizer.dart';
import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

/// Generates a minimal valid 64x48 JPEG with an embedded APP1 Exif tag so
/// users can test EXIF-stripped image sharing directly in Simulator/UI flows
/// without requiring physical camera roll photos.
Uint8List buildSampleCameraJpegBytes() {
  return Uint8List.fromList(<int>[
    0xFF, 0xD8, // SOI
    0xFF, 0xE1, 0x00, 0x14, // APP1 Exif header (will be stripped by sanitizer)
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
    0x47, 0x50, 0x53, 0x4C, 0x61, 0x74, 0x34, 0x30, 0x2E, 0x39, 0x31, 0x35,
    0xFF,
    0xC0,
    0x00,
    0x0B,
    0x08,
    0x00,
    0x30,
    0x00,
    0x40,
    0x01,
    0x01,
    0x11,
    0x00,
    0xFF, 0xD9, // EOI
  ]);
}

class ChatImageBubble extends StatelessWidget {
  const ChatImageBubble({
    super.key,
    required this.controller,
    required this.attachment,
  });

  final AppController controller;
  final ChatImageAttachment attachment;

  void _openFullScreenViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final currentBytes = controller.fetchAuthorizedImageBytes(
              attachment.mediaId,
            );
            return Dialog.fullscreen(
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                appBar: AppBar(
                  title: Text(
                    'Shared Photo (${attachment.width}×${attachment.height})',
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                body: Center(
                  child: currentBytes == null
                      ? Text(
                          'Photo access revoked or session ended.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      : InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: _DecodedOrCardPreview(
                            attachment: attachment,
                            bytes: currentBytes,
                            isFullScreen: true,
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authorizedBytes = controller.fetchAuthorizedImageBytes(
      attachment.mediaId,
    );

    if (authorizedBytes == null) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_clock_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Photo unavailable (session ended or access revoked)',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openFullScreenViewer(context),
        child: _DecodedOrCardPreview(
          attachment: attachment,
          bytes: authorizedBytes,
          isFullScreen: false,
        ),
      ),
    );
  }
}

class _DecodedOrCardPreview extends StatelessWidget {
  const _DecodedOrCardPreview({
    required this.attachment,
    required this.bytes,
    required this.isFullScreen,
  });

  final ChatImageAttachment attachment;
  final Uint8List bytes;
  final bool isFullScreen;

  @override
  Widget build(BuildContext context) {
    final kb = (attachment.sizeBytes / 1024)
        .clamp(0.1, 10240)
        .toStringAsFixed(1);
    final strippedOk = !MediaSanitizer.containsExifMetadata(bytes);

    return Container(
      width: isFullScreen ? 320 : 240,
      height: isFullScreen ? 240 : 136,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF132A3E), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.pulseMint.withValues(alpha: 0.45)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.photo_camera_back_outlined,
                      size: 32,
                      color: AppTheme.pulseMint,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${attachment.width}×${attachment.height} • ${attachment.mimeType.split('/').last.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strippedOk ? 'EXIF & GPS stripped • ${kb}KB' : '${kb}KB',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.pulseMint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 11,
                      color: AppTheme.pulseMint,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'EXIF Stripped',
                      style: TextStyle(fontSize: 9, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StagedImagePreviewBar extends StatelessWidget {
  const StagedImagePreviewBar({
    super.key,
    required this.pendingUploads,
    required this.onCancel,
  });

  final List<PendingImageUpload> pendingUploads;
  final ValueChanged<String> onCancel;

  @override
  Widget build(BuildContext context) {
    if (pendingUploads.isEmpty) return const SizedBox.shrink();
    final upload = pendingUploads.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.image_outlined, size: 18, color: AppTheme.pulseMint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Photo staged (${upload.width}×${upload.height}, EXIF stripped) — ready to send',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Remove staged photo',
            visualDensity: VisualDensity.compact,
            onPressed: () => onCancel(upload.uploadId),
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
}
