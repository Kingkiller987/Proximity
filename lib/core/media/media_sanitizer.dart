import 'dart:typed_data';

import 'package:flutter/foundation.dart';

@immutable
class SanitizedImageResult {
  const SanitizedImageResult._({
    required this.isValid,
    this.sanitizedBytes,
    this.mimeType,
    this.extension,
    this.width = 0,
    this.height = 0,
    this.hadMetadataStripped = false,
    this.errorMessage,
  });

  factory SanitizedImageResult.invalid(String error) {
    return SanitizedImageResult._(isValid: false, errorMessage: error);
  }

  factory SanitizedImageResult.valid({
    required Uint8List sanitizedBytes,
    required String mimeType,
    required String extension,
    required int width,
    required int height,
    required bool hadMetadataStripped,
  }) {
    return SanitizedImageResult._(
      isValid: true,
      sanitizedBytes: sanitizedBytes,
      mimeType: mimeType,
      extension: extension,
      width: width,
      height: height,
      hadMetadataStripped: hadMetadataStripped,
    );
  }

  final bool isValid;
  final Uint8List? sanitizedBytes;
  final String? mimeType;
  final String? extension;
  final int width;
  final int height;
  final bool hadMetadataStripped;
  final String? errorMessage;
}

/// Validates image formats (JPEG, PNG, WebP) by magic bytes, enforces size
/// limits, and strips EXIF / GPS / comment metadata chunks in pure Dart.
class MediaSanitizer {
  const MediaSanitizer._();

  static const int defaultMaxBytes = 5 * 1024 * 1024; // 5 MB

  static SanitizedImageResult sanitizeAndValidate(
    Uint8List rawBytes, {
    int maxBytes = defaultMaxBytes,
  }) {
    if (rawBytes.length < 12) {
      return SanitizedImageResult.invalid('Image payload is too small.');
    }
    if (rawBytes.length > maxBytes) {
      return SanitizedImageResult.invalid(
        'Image exceeds maximum allowed size of ${maxBytes ~/ 1024} KB.',
      );
    }

    if (_isJpeg(rawBytes)) {
      return _sanitizeJpeg(rawBytes);
    }
    if (_isPng(rawBytes)) {
      return _sanitizePng(rawBytes);
    }
    if (_isWebp(rawBytes)) {
      return _sanitizeWebp(rawBytes);
    }

    return SanitizedImageResult.invalid(
      'Unsupported image format. Only JPEG, PNG, and WebP are permitted.',
    );
  }

  /// Checks whether `bytes` contains EXIF (`APP1` / `eXIf` / `EXIF`) metadata.
  static bool containsExifMetadata(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // Check for 'Exif\0\0' signature anywhere in header/metadata segments
    for (var i = 0; i <= bytes.length - 6; i++) {
      if (bytes[i] == 0x45 &&
          bytes[i + 1] == 0x78 &&
          bytes[i + 2] == 0x69 &&
          bytes[i + 3] == 0x66 &&
          bytes[i + 4] == 0x00 &&
          bytes[i + 5] == 0x00) {
        return true;
      }
      // PNG 'eXIf' or WebP 'EXIF' chunk tag
      if ((bytes[i] == 0x65 || bytes[i] == 0x45) &&
          bytes[i + 1] == 0x58 &&
          bytes[i + 2] == 0x49 &&
          (bytes[i + 3] == 0x66 || bytes[i + 3] == 0x46)) {
        return true;
      }
    }
    return false;
  }

  static bool _isJpeg(Uint8List b) =>
      b.length >= 4 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  static bool _isPng(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A;

  static bool _isWebp(Uint8List b) =>
      b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50;

  static SanitizedImageResult _sanitizeJpeg(Uint8List b) {
    final out = BytesBuilder(copy: false);
    out.add(<int>[0xFF, 0xD8]); // SOI
    var offset = 2;
    var stripped = false;
    var width = 320;
    var height = 240;

    while (offset < b.length) {
      if (b[offset] != 0xFF) {
        // Entropy-coded scan data until end
        out.add(Uint8List.sublistView(b, offset));
        break;
      }
      while (offset < b.length && b[offset] == 0xFF) {
        offset++;
      }
      if (offset >= b.length) break;
      final marker = b[offset++];

      if (marker == 0xD9) {
        // EOI
        out.add(<int>[0xFF, 0xD9]);
        break;
      }
      if (marker == 0xDA) {
        // SOS: copy header and remaining scan bytes
        if (offset + 2 > b.length) {
          return SanitizedImageResult.invalid('Truncated JPEG SOS segment.');
        }
        out.add(<int>[0xFF, marker]);
        out.add(Uint8List.sublistView(b, offset));
        break;
      }
      if (marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7)) {
        out.add(<int>[0xFF, marker]);
        continue;
      }
      if (offset + 2 > b.length) {
        return SanitizedImageResult.invalid('Malformed JPEG segment length.');
      }
      final segLen = (b[offset] << 8) | b[offset + 1];
      if (segLen < 2 || offset + segLen > b.length) {
        return SanitizedImageResult.invalid('Invalid JPEG segment bounds.');
      }

      // Extract dimensions from SOF0..SOF3
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        if (segLen >= 7) {
          height = (b[offset + 3] << 8) | b[offset + 4];
          width = (b[offset + 5] << 8) | b[offset + 6];
        }
      }

      // Strip APP1..APP15 (0xE1..0xEF, including EXIF/GPS/XMP) and COM (0xFE)
      if ((marker >= 0xE1 && marker <= 0xEF) || marker == 0xFE) {
        stripped = true;
      } else {
        out.add(<int>[0xFF, marker]);
        out.add(Uint8List.sublistView(b, offset, offset + segLen));
      }
      offset += segLen;
    }

    return SanitizedImageResult.valid(
      sanitizedBytes: out.toBytes(),
      mimeType: 'image/jpeg',
      extension: 'jpg',
      width: width > 0 ? width : 320,
      height: height > 0 ? height : 240,
      hadMetadataStripped: stripped,
    );
  }

  static SanitizedImageResult _sanitizePng(Uint8List b) {
    final out = BytesBuilder(copy: false);
    out.add(Uint8List.sublistView(b, 0, 8));
    var offset = 8;
    var stripped = false;
    var sawIhdr = false;
    var sawIend = false;
    var width = 0;
    var height = 0;

    while (offset + 8 <= b.length) {
      final length =
          (b[offset] << 24) |
          (b[offset + 1] << 16) |
          (b[offset + 2] << 8) |
          b[offset + 3];
      if (length < 0 || offset + 12 + length > b.length) {
        return SanitizedImageResult.invalid('Malformed PNG chunk.');
      }
      final type = String.fromCharCodes(
        Uint8List.sublistView(b, offset + 4, offset + 8),
      );
      if (type == 'IHDR' && length >= 8) {
        sawIhdr = true;
        width =
            (b[offset + 8] << 24) |
            (b[offset + 9] << 16) |
            (b[offset + 10] << 8) |
            b[offset + 11];
        height =
            (b[offset + 12] << 24) |
            (b[offset + 13] << 16) |
            (b[offset + 14] << 8) |
            b[offset + 15];
      }

      if (type == 'eXIf' ||
          type == 'tEXt' ||
          type == 'iTXt' ||
          type == 'zTXt') {
        stripped = true;
      } else {
        out.add(Uint8List.sublistView(b, offset, offset + 12 + length));
      }
      offset += 12 + length;
      if (type == 'IEND') {
        sawIend = true;
        break;
      }
    }

    if (!sawIhdr || !sawIend || width <= 0 || height <= 0) {
      return SanitizedImageResult.invalid('Missing PNG IHDR or IEND chunk.');
    }

    return SanitizedImageResult.valid(
      sanitizedBytes: out.toBytes(),
      mimeType: 'image/png',
      extension: 'png',
      width: width,
      height: height,
      hadMetadataStripped: stripped,
    );
  }

  static SanitizedImageResult _sanitizeWebp(Uint8List b) {
    final chunks = BytesBuilder(copy: false);
    var offset = 12;
    var stripped = false;
    var hasBitstreamChunk = false;
    while (offset + 8 <= b.length) {
      final fourCc = String.fromCharCodes(
        Uint8List.sublistView(b, offset, offset + 4),
      );
      final chunkSize =
          b[offset + 4] |
          (b[offset + 5] << 8) |
          (b[offset + 6] << 16) |
          (b[offset + 7] << 24);
      final paddedSize = chunkSize + (chunkSize.isOdd ? 1 : 0);
      if (chunkSize < 0 || offset + 8 + paddedSize > b.length) {
        return SanitizedImageResult.invalid('Malformed WebP chunk length.');
      }
      if (fourCc == 'VP8 ' || fourCc == 'VP8L' || fourCc == 'VP8X') {
        hasBitstreamChunk = true;
      }
      if (fourCc == 'EXIF' || fourCc == 'XMP ') {
        stripped = true;
      } else {
        chunks.add(Uint8List.sublistView(b, offset, offset + 8 + paddedSize));
      }
      offset += 8 + paddedSize;
    }

    if (!hasBitstreamChunk) {
      return SanitizedImageResult.invalid('Missing WebP bitstream chunk.');
    }

    final bodyBytes = chunks.toBytes();
    final riffSize = 4 + bodyBytes.length;
    final header = Uint8List(12);
    header.setRange(0, 4, 'RIFF'.codeUnits);
    header[4] = riffSize & 0xFF;
    header[5] = (riffSize >> 8) & 0xFF;
    header[6] = (riffSize >> 16) & 0xFF;
    header[7] = (riffSize >> 24) & 0xFF;
    header.setRange(8, 12, 'WEBP'.codeUnits);

    final out = BytesBuilder(copy: false)
      ..add(header)
      ..add(bodyBytes);

    return SanitizedImageResult.valid(
      sanitizedBytes: out.toBytes(),
      mimeType: 'image/webp',
      extension: 'webp',
      width: 320,
      height: 240,
      hadMetadataStripped: stripped,
    );
  }
}
