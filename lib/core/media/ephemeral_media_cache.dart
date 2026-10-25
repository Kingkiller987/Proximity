import 'dart:typed_data';

class _CachedMediaEntry {
  _CachedMediaEntry({
    required this.mediaId,
    required this.channelId,
    required this.senderId,
    required this.bytes,
    this.visitSessionId,
  });

  final String mediaId;
  final String channelId;
  final String senderId;
  final String? visitSessionId;
  final Uint8List bytes;

  void zeroOut() {
    bytes.fillRange(0, bytes.length, 0);
  }
}

/// In-memory ephemeral cache for authorized chat images.
/// Never writes decrypted media to persistent unencrypted disk storage, and
/// zeroes + evicts buffers immediately upon landmark exit, event leave,
/// permission loss, or user block.
class EphemeralMediaCache {
  final Map<String, _CachedMediaEntry> _entries = <String, _CachedMediaEntry>{};

  bool contains(String mediaId) => _entries.containsKey(mediaId);

  Uint8List? get(String mediaId, {String? requiredVisitSessionId}) {
    final entry = _entries[mediaId];
    if (entry == null) return null;
    if (requiredVisitSessionId != null &&
        entry.visitSessionId != requiredVisitSessionId) {
      entry.zeroOut();
      _entries.remove(mediaId);
      return null;
    }
    return Uint8List.fromList(entry.bytes);
  }

  void put({
    required String mediaId,
    required String channelId,
    required String senderId,
    required Uint8List bytes,
    String? visitSessionId,
  }) {
    _entries[mediaId]?.zeroOut();
    _entries[mediaId] = _CachedMediaEntry(
      mediaId: mediaId,
      channelId: channelId,
      senderId: senderId,
      visitSessionId: visitSessionId,
      bytes: Uint8List.fromList(bytes),
    );
  }

  void evictByChannel(String channelId) {
    final toRemove = _entries.values
        .where((e) => e.channelId == channelId)
        .map((e) => e.mediaId)
        .toList();
    for (final id in toRemove) {
      _entries.remove(id)?.zeroOut();
    }
  }

  void evictByVisitSession(String visitSessionId) {
    final toRemove = _entries.values
        .where((e) => e.visitSessionId == visitSessionId)
        .map((e) => e.mediaId)
        .toList();
    for (final id in toRemove) {
      _entries.remove(id)?.zeroOut();
    }
  }

  void evictBySender(String senderId) {
    final toRemove = _entries.values
        .where((e) => e.senderId == senderId)
        .map((e) => e.mediaId)
        .toList();
    for (final id in toRemove) {
      _entries.remove(id)?.zeroOut();
    }
  }

  void clearAll() {
    for (final entry in _entries.values) {
      entry.zeroOut();
    }
    _entries.clear();
  }
}
