import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'media_sanitizer.dart';

/// Helper for robustly selecting images natively via [ImagePicker]
/// while enforcing size limits, validating format magic bytes,
/// stripping EXIF/GPS metadata, and recovering Android lost data.
class NativeImagePickerHelper {
  NativeImagePickerHelper({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Prompts the user to select Camera or Photo Library via a modal bottom sheet,
  /// then picks, validates, and sanitizes the image. Returns `null` on cancellation.
  Future<SanitizedImageResult?> promptAndPickSanitizedImage(
    BuildContext context, {
    int maxBytes = MediaSanitizer.defaultMaxBytes,
  }) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              key: const Key('image-picker-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Photo Library'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              key: const Key('image-picker-source-camera'),
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) {
      return null;
    }
    return pickSanitizedImage(source: source, maxBytes: maxBytes);
  }

  /// Picks an image from [source] (Camera or Gallery), reads bytes,
  /// validates format, enforces size limit (<= 5MB), strips metadata,
  /// and returns the [SanitizedImageResult]. Returns `null` on cancellation.
  Future<SanitizedImageResult?> pickSanitizedImage({
    ImageSource source = ImageSource.gallery,
    int maxBytes = MediaSanitizer.defaultMaxBytes,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file == null) {
        return null; // Graceful user cancellation
      }
      final Uint8List rawBytes = await _readXFileBytes(file);
      return MediaSanitizer.sanitizeAndValidate(rawBytes, maxBytes: maxBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NativeImagePickerHelper.pickSanitizedImage error: $e');
      }
      return null;
    }
  }

  /// Recovers lost image data on Android after MainActivity destruction.
  /// Validates and sanitizes the recovered payload. Returns `null` if no data was lost.
  Future<SanitizedImageResult?> retrieveLostSanitizedImage({
    int maxBytes = MediaSanitizer.defaultMaxBytes,
  }) async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) {
        return null;
      }
      final Uint8List rawBytes = await _readXFileBytes(response.file!);
      return MediaSanitizer.sanitizeAndValidate(rawBytes, maxBytes: maxBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NativeImagePickerHelper.retrieveLostSanitizedImage error: $e',
        );
      }
      return null;
    }
  }

  Future<Uint8List> _readXFileBytes(XFile file) async {
    if (!kIsWeb && file.path.isNotEmpty) {
      return File(file.path).readAsBytesSync();
    }
    return file.readAsBytes();
  }
}
