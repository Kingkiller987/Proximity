import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum LocationPermissionState { prompt, granted, denied, simulated }

enum IdentityMode { anonymous, username }

enum EventAccessType { public, joinCode, inviteOnly }

enum DmRequestStatus { pending, accepted, declined }

@immutable
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.areaName,
  });

  final double latitude;
  final double longitude;
  final String areaName;

  double distanceMetersTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(other.latitude - latitude);
    final dLon = _toRad(other.longitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(latitude)) *
            math.cos(_toRad(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Coarse distance bucket so exact participant coordinates are never exposed.
  String privacyDistanceLabelTo(GeoPoint other) {
    final meters = distanceMetersTo(other);
    if (meters < 100) return '< 100m away';
    if (meters < 1000) return '~${(meters / 50).round() * 50}m away';
    return '~${(meters / 1000).toStringAsFixed(1)} km away';
  }

  static double _toRad(double deg) => deg * (math.pi / 180.0);
}

/// Non-plaintext digest for event join codes.
/// shortcut: FNV-1a64 salted hash in pure Dart for Milestone 1, replace with server-side pgcrypto crypt() in Milestone 2.
String hashSecretCode(String rawCode, {required String salt}) {
  final normalized = '$salt:${rawCode.trim()}';
  final bytes = utf8.encode(normalized);
  var hash = 0xcbf29ce484222325;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String formatRemainingTime(DateTime expiresAt, DateTime now) {
  final diff = expiresAt.difference(now);
  if (diff.isNegative) return 'Expired';
  if (diff.inMinutes < 60) return '${math.max(1, diff.inMinutes)}m left';
  final hours = diff.inHours;
  final mins = diff.inMinutes % 60;
  return mins == 0 ? '${hours}h left' : '${hours}h ${mins}m left';
}

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.anonymousHandle,
    required this.username,
    required this.identityMode,
    required this.visibleInNearby,
    required this.ghostBrowseNearby,
    required this.nearbyRadiusMeters,
    required this.messageRetentionHours,
  });

  final String id;
  final String anonymousHandle;
  final String username;
  final IdentityMode identityMode;
  final bool visibleInNearby;
  final bool ghostBrowseNearby;
  final double nearbyRadiusMeters;
  final int messageRetentionHours;

  String get activeDisplayName =>
      identityMode == IdentityMode.anonymous ? anonymousHandle : '@$username';

  bool get isAnonymous => identityMode == IdentityMode.anonymous;

  UserProfile copyWith({
    String? anonymousHandle,
    String? username,
    IdentityMode? identityMode,
    bool? visibleInNearby,
    bool? ghostBrowseNearby,
    double? nearbyRadiusMeters,
    int? messageRetentionHours,
  }) {
    return UserProfile(
      id: id,
      anonymousHandle: anonymousHandle ?? this.anonymousHandle,
      username: username ?? this.username,
      identityMode: identityMode ?? this.identityMode,
      visibleInNearby: visibleInNearby ?? this.visibleInNearby,
      ghostBrowseNearby: ghostBrowseNearby ?? this.ghostBrowseNearby,
      nearbyRadiusMeters: nearbyRadiusMeters ?? this.nearbyRadiusMeters,
      messageRetentionHours:
          messageRetentionHours ?? this.messageRetentionHours,
    );
  }
}

@immutable
class NearbyParticipant {
  const NearbyParticipant({
    required this.userId,
    required this.displayName,
    required this.isAnonymous,
    required this.location,
    required this.visibleInNearby,
  });

  final String userId;
  final String displayName;
  final bool isAnonymous;
  final GeoPoint location;
  final bool visibleInNearby;
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderDisplayName,
    required this.isAnonymous,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
    required this.originPoint,
    this.isSystemNotice = false,
  });

  final String id;
  final String channelId;
  final String senderId;
  final String senderDisplayName;
  final bool isAnonymous;
  final String body;
  final DateTime createdAt;
  final DateTime expiresAt;
  final GeoPoint originPoint;
  final bool isSystemNotice;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

@immutable
class ProximityEvent {
  const ProximityEvent({
    required this.id,
    required this.hostId,
    required this.hostDisplayName,
    required this.title,
    required this.description,
    required this.categoryTag,
    required this.location,
    required this.radiusMeters,
    required this.startsAt,
    required this.duration,
    required this.expiresAt,
    required this.accessType,
    this.joinCodeHash,
    this.invitedUserIds = const <String>{},
    this.participantIds = const <String>{},
    this.isEnded = false,
    this.locationMoveCount = 0,
    this.lastMovedNotice,
  });

  final String id;
  final String hostId;
  final String hostDisplayName;
  final String title;
  final String description;
  final String categoryTag;
  final GeoPoint location;
  final double radiusMeters;
  final DateTime startsAt;
  final Duration duration;
  final DateTime expiresAt;
  final EventAccessType accessType;
  final String? joinCodeHash;
  final Set<String> invitedUserIds;
  final Set<String> participantIds;
  final bool isEnded;
  final int locationMoveCount;
  final String? lastMovedNotice;

  bool isActiveAt(DateTime now) => !isEnded && expiresAt.isAfter(now);

  bool verifyJoinCode(String candidate) {
    if (accessType != EventAccessType.joinCode || joinCodeHash == null) {
      return false;
    }
    return hashSecretCode(candidate, salt: id) == joinCodeHash;
  }

  /// Moving an event preserves its ID, start time, and original expiration timer.
  ProximityEvent moveLocation(GeoPoint newLocation, {required String notice}) {
    return ProximityEvent(
      id: id,
      hostId: hostId,
      hostDisplayName: hostDisplayName,
      title: title,
      description: description,
      categoryTag: categoryTag,
      location: newLocation,
      radiusMeters: radiusMeters,
      startsAt: startsAt,
      duration: duration,
      expiresAt: expiresAt,
      accessType: accessType,
      joinCodeHash: joinCodeHash,
      invitedUserIds: invitedUserIds,
      participantIds: participantIds,
      isEnded: isEnded,
      locationMoveCount: locationMoveCount + 1,
      lastMovedNotice: notice,
    );
  }

  ProximityEvent copyWithDetails({
    String? title,
    String? description,
    double? radiusMeters,
    bool? isEnded,
    Set<String>? participantIds,
  }) {
    return ProximityEvent(
      id: id,
      hostId: hostId,
      hostDisplayName: hostDisplayName,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryTag: categoryTag,
      location: location,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      startsAt: startsAt,
      duration: duration,
      expiresAt: expiresAt,
      accessType: accessType,
      joinCodeHash: joinCodeHash,
      invitedUserIds: invitedUserIds,
      participantIds: participantIds ?? this.participantIds,
      isEnded: isEnded ?? this.isEnded,
      locationMoveCount: locationMoveCount,
      lastMovedNotice: lastMovedNotice,
    );
  }
}

@immutable
class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.senderDisplayName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderDisplayName;
  final String body;
  final DateTime createdAt;
}

@immutable
class DmRequest {
  const DmRequest({
    required this.id,
    required this.fromUserId,
    required this.fromDisplayName,
    required this.fromIsAnonymous,
    required this.toUserId,
    required this.toDisplayName,
    required this.introMessage,
    required this.createdAt,
    required this.status,
    this.messages = const <DirectMessage>[],
  });

  final String id;
  final String fromUserId;
  final String fromDisplayName;
  final bool fromIsAnonymous;
  final String toUserId;
  final String toDisplayName;
  final String introMessage;
  final DateTime createdAt;
  final DmRequestStatus status;
  final List<DirectMessage> messages;

  DmRequest copyWith({DmRequestStatus? status, List<DirectMessage>? messages}) {
    return DmRequest(
      id: id,
      fromUserId: fromUserId,
      fromDisplayName: fromDisplayName,
      fromIsAnonymous: fromIsAnonymous,
      toUserId: toUserId,
      toDisplayName: toDisplayName,
      introMessage: introMessage,
      createdAt: createdAt,
      status: status ?? this.status,
      messages: messages ?? this.messages,
    );
  }
}

@immutable
class SafetyReport {
  const SafetyReport({
    required this.id,
    required this.targetId,
    required this.targetLabel,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String targetId;
  final String targetLabel;
  final String reason;
  final DateTime createdAt;
}
