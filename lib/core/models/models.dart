import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _tzInitialized = false;

void ensureTimezonesInitialized() {
  if (_tzInitialized) return;
  tz_data.initializeTimeZones();
  _tzInitialized = true;
}

enum LocationPermissionState { prompt, granted, denied, simulated }

enum IdentityMode {
  anonymous,
  username;

  static const IdentityMode real = IdentityMode.username;
}

enum LandmarkCategory {
  settlement,
  district,
  complex,
  venue,
  pointOfInterest;

  String get label {
    switch (this) {
      case LandmarkCategory.settlement:
        return 'City / Town';
      case LandmarkCategory.district:
        return 'District';
      case LandmarkCategory.complex:
        return 'Complex / Campus';
      case LandmarkCategory.venue:
        return 'Venue / Building';
      case LandmarkCategory.pointOfInterest:
        return 'Point Of Interest';
    }
  }
}

enum EventAccessType { public, joinCode, inviteOnly }

enum DmRequestStatus { pending, accepted, declined }

enum LandmarkCreationPolicy { curatedSystemOnly, roleAuthorized }

enum EventLifecycleStatus { scheduled, active, ended, cancelled }

enum CalendarViewMode { day, week, month }

enum UploadLifecycleState { previewing, uploading, failed, completed }

@immutable
class ChatImageAttachment {
  const ChatImageAttachment({
    required this.mediaId,
    required this.storageObjectKey,
    required this.mimeType,
    required this.sizeBytes,
    required this.width,
    required this.height,
  });

  final String mediaId;

  /// Private bucket key (`private/chat-media/<scope>/<channel>/<uuid>.<ext>`).
  /// Never exposes device-local file paths or unauthenticated public URLs.
  final String storageObjectKey;
  final String mimeType;
  final int sizeBytes;
  final int width;
  final int height;
}

@immutable
class MediaDownloadToken {
  const MediaDownloadToken({
    required this.token,
    required this.mediaId,
    required this.channelId,
    required this.expiresAt,
    this.visitSessionId,
  });

  final String token;
  final String mediaId;
  final String channelId;
  final DateTime expiresAt;
  final String? visitSessionId;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

@immutable
class PendingImageUpload {
  const PendingImageUpload({
    required this.uploadId,
    required this.channelId,
    required this.mimeType,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.state,
    this.progress = 0.0,
    this.errorMessage,
  });

  final String uploadId;
  final String channelId;
  final String mimeType;
  final int sizeBytes;
  final int width;
  final int height;
  final UploadLifecycleState state;
  final double progress;
  final String? errorMessage;
}

@immutable
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.recordedAt,
    this.areaName,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;
  final String? areaName;

  GeoPoint toGeoPoint({required String fallbackAreaName}) {
    return GeoPoint(
      latitude: latitude,
      longitude: longitude,
      areaName: areaName ?? fallbackAreaName,
    );
  }
}

@immutable
class LandmarkChat {
  const LandmarkChat({
    required this.id,
    required this.name,
    required this.areaName,
    required this.center,
    required this.radiusMeters,
    required this.distanceMeters,
    required this.distanceLabel,
    required this.headerDistanceLabel,
    required this.visitSessionId,
    required this.visitEnteredAt,
    required this.activeMessageCount,
    required this.unreadCount,
  });

  final String id;
  final String name;
  final String areaName;
  final GeoPoint center;
  final double radiusMeters;
  final double distanceMeters;
  final String distanceLabel;

  /// Formatted as e.g. `Staller Steps · 100 m away`.
  final String headerDistanceLabel;
  final String visitSessionId;
  final DateTime visitEnteredAt;
  final int activeMessageCount;
  final int unreadCount;
}

@immutable
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.areaName,
    this.timezone = 'America/New_York',
  });

  final double latitude;
  final double longitude;
  final String areaName;
  final String timezone;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          areaName == other.areaName &&
          timezone == other.timezone;

  @override
  int get hashCode => Object.hash(latitude, longitude, areaName, timezone);
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

/// Formats sent timestamps: 'h:mm a' (e.g. '10:42 PM') for today,
/// or 'MMM d, h:mm a' (e.g. 'Oct 24, 10:42 PM') for prior dates.
String formatMessageTimestamp(DateTime timestamp, DateTime now) {
  final isSameDay =
      timestamp.year == now.year &&
      timestamp.month == now.month &&
      timestamp.day == now.day;
  if (isSameDay) {
    return DateFormat('h:mm a').format(timestamp);
  }
  return DateFormat('MMM d, h:mm a').format(timestamp);
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
    this.bio = '',
    this.avatarBytes,
    this.isGhostMode = false,
    this.notifyNearbyEvents = true,
    this.notifyNearbyChat = true,
    this.notifyJoinedEventChat = true,
  });

  final String id;
  final String anonymousHandle;
  final String username;
  final IdentityMode identityMode;
  final bool visibleInNearby;
  final bool ghostBrowseNearby;
  final double nearbyRadiusMeters;
  final int messageRetentionHours;
  final String bio;
  final Uint8List? avatarBytes;
  final bool isGhostMode;
  final bool notifyNearbyEvents;
  final bool notifyNearbyChat;
  final bool notifyJoinedEventChat;

  String get activeDisplayName =>
      identityMode == IdentityMode.anonymous ? anonymousHandle : '@$username';

  String get publicDisplayName => '@$username';

  bool get isAnonymous => identityMode == IdentityMode.anonymous;

  UserProfile copyWith({
    String? anonymousHandle,
    String? username,
    IdentityMode? identityMode,
    bool? visibleInNearby,
    bool? ghostBrowseNearby,
    double? nearbyRadiusMeters,
    int? messageRetentionHours,
    String? bio,
    Uint8List? avatarBytes,
    bool clearAvatar = false,
    bool? isGhostMode,
    bool? notifyNearbyEvents,
    bool? notifyNearbyChat,
    bool? notifyJoinedEventChat,
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
      bio: bio ?? this.bio,
      avatarBytes: clearAvatar ? null : (avatarBytes ?? this.avatarBytes),
      isGhostMode: isGhostMode ?? this.isGhostMode,
      notifyNearbyEvents: notifyNearbyEvents ?? this.notifyNearbyEvents,
      notifyNearbyChat: notifyNearbyChat ?? this.notifyNearbyChat,
      notifyJoinedEventChat:
          notifyJoinedEventChat ?? this.notifyJoinedEventChat,
    );
  }
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.targetEventId,
    this.targetLandmarkId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? targetEventId;
  final String? targetLandmarkId;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      targetEventId: targetEventId,
      targetLandmarkId: targetLandmarkId,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Structural public identity projection for profile sheets, participants, and chat bubbles.
/// Private username, bio, and avatar are strictly omitted when anonymous.
@immutable
class PublicIdentityProjection {
  const PublicIdentityProjection({
    required this.userId,
    required this.displayName,
    required this.bio,
    this.avatarBytes,
    required this.isAnonymous,
  });

  factory PublicIdentityProjection.fromProfile(UserProfile profile) {
    if (profile.isAnonymous) {
      return PublicIdentityProjection(
        userId: profile.id,
        displayName: profile.anonymousHandle,
        bio: "I'm anonymous.",
        avatarBytes: null,
        isAnonymous: true,
      );
    }
    return PublicIdentityProjection(
      userId: profile.id,
      displayName: '@${profile.username}',
      bio: profile.bio,
      avatarBytes: profile.avatarBytes,
      isAnonymous: false,
    );
  }

  final String userId;
  final String displayName;
  final String bio;
  final Uint8List? avatarBytes;
  final bool isAnonymous;
}

/// Public discovery projection for Explore Map and proximity-chat dropdown.
@immutable
class LandmarkDiscovery {
  const LandmarkDiscovery({
    required this.id,
    required this.name,
    required this.areaName,
    required this.center,
    required this.radiusMeters,
    required this.distanceMeters,
    required this.distanceLabel,
    required this.isUserInside,
    required this.category,
    this.parentLandmarkId,
  });

  final String id;
  final String name;
  final String areaName;
  final GeoPoint center;
  final double radiusMeters;
  final double distanceMeters;
  final String distanceLabel;
  final bool isUserInside;
  final LandmarkCategory category;
  final String? parentLandmarkId;

  bool get isEligible => isUserInside;
}

/// Public-facing nearby participant projection with coarse distance only.
/// Exact `GeoPoint` coordinates are never exposed on public projections.
@immutable
class NearbyParticipant {
  const NearbyParticipant({
    required this.userId,
    required this.displayName,
    required this.isAnonymous,
    required this.areaName,
    required this.distanceLabel,
    required this.visibleInNearby,
    this.avatarBytes,
  });

  final String userId;
  final String displayName;
  final bool isAnonymous;
  final String areaName;
  final String distanceLabel;
  final bool visibleInNearby;
  final Uint8List? avatarBytes;
}

/// Public-facing chat message projection with coarse distance only.
/// Exact `GeoPoint` sender origin coordinates are never exposed.
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
    required this.areaName,
    required this.distanceLabel,
    this.attachment,
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
  final String areaName;
  final String distanceLabel;
  final ChatImageAttachment? attachment;
  final bool isSystemNotice;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

@immutable
class DailyScheduleOverride {
  const DailyScheduleOverride({
    required this.localDateIso,
    this.isClosed = false,
    this.openMinutes,
    this.closeMinutes,
  });

  final String localDateIso;
  final bool isClosed;
  final int? openMinutes;
  final int? closeMinutes;
}

@immutable
class EventSchedule {
  const EventSchedule({
    required this.startDate,
    required this.endDate,
    required this.venueTimezone,
    required this.defaultOpenMinutes,
    required this.defaultCloseMinutes,
    this.dailyOverrides = const <String, DailyScheduleOverride>{},
    this.isCancelled = false,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String venueTimezone;
  final int defaultOpenMinutes;
  final int defaultCloseMinutes;
  final Map<String, DailyScheduleOverride> dailyOverrides;
  final bool isCancelled;

  static String formatIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String formatMinutesOfDay(int minutes) {
    final clamped = minutes.clamp(0, 1439);
    final h = (clamped ~/ 60).toString().padLeft(2, '0');
    final m = (clamped % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get isValid {
    ensureTimezonesInitialized();
    try {
      tz.getLocation(venueTimezone);
    } catch (_) {
      return false;
    }
    final s = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final e = DateTime.utc(endDate.year, endDate.month, endDate.day);
    if (e.isBefore(s)) return false;
    final totalDays = e.difference(s).inDays;
    if (totalDays > 365) return false;
    if (defaultOpenMinutes < 0 ||
        defaultOpenMinutes >= 1440 ||
        defaultCloseMinutes < 0 ||
        defaultCloseMinutes >= 1440) {
      return false;
    }
    for (final ov in dailyOverrides.values) {
      if (!ov.isClosed) {
        final om = ov.openMinutes ?? defaultOpenMinutes;
        final cm = ov.closeMinutes ?? defaultCloseMinutes;
        if (om < 0 || om >= 1440 || cm < 0 || cm >= 1440) {
          return false;
        }
      }
    }
    var hasOpenDay = false;
    for (var i = 0; i <= totalDays; i++) {
      final d = s.add(Duration(days: i));
      final ov = dailyOverrides[formatIsoDate(d)];
      if (ov == null || !ov.isClosed) {
        hasOpenDay = true;
        break;
      }
    }
    return hasOpenDay;
  }

  bool spansLocalDate(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final s = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final e = DateTime.utc(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  bool isOpenOnLocalDate(DateTime date) {
    if (isCancelled || !isValid || !spansLocalDate(date)) return false;
    final ov = dailyOverrides[formatIsoDate(date)];
    return ov == null || !ov.isClosed;
  }

  bool occursOnLocalDate(DateTime date) => isOpenOnLocalDate(date);

  (int, int) hoursForLocalDate(DateTime date) {
    final ov = dailyOverrides[formatIsoDate(date)];
    return (
      ov?.openMinutes ?? defaultOpenMinutes,
      ov?.closeMinutes ?? defaultCloseMinutes,
    );
  }

  bool isOpenAt(DateTime instant) {
    if (isCancelled || !isValid) return false;
    ensureTimezonesInitialized();
    final loc = tz.getLocation(venueTimezone);
    final localNow = tz.TZDateTime.from(instant, loc);
    final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
    final minOfDay = localNow.hour * 60 + localNow.minute;

    if (isOpenOnLocalDate(today)) {
      final (openM, closeM) = hoursForLocalDate(today);
      if (closeM > openM) {
        if (minOfDay >= openM && minOfDay < closeM) return true;
      } else {
        if (minOfDay >= openM) return true;
      }
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (isOpenOnLocalDate(yesterday)) {
      final (yOpen, yClose) = hoursForLocalDate(yesterday);
      if (yClose <= yOpen && minOfDay < yClose) return true;
    }

    return false;
  }

  DateTime get startsAtInstant {
    ensureTimezonesInitialized();
    final loc = tz.getLocation(venueTimezone);
    final s = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final e = DateTime.utc(endDate.year, endDate.month, endDate.day);
    final days = e.difference(s).inDays;
    for (var i = 0; i <= days; i++) {
      final d = s.add(Duration(days: i));
      if (isOpenOnLocalDate(d)) {
        final (openM, _) = hoursForLocalDate(d);
        return tz.TZDateTime(
          loc,
          d.year,
          d.month,
          d.day,
          openM ~/ 60,
          openM % 60,
        ).toUtc();
      }
    }
    return startDate.toUtc();
  }

  DateTime get expiresAtInstant {
    ensureTimezonesInitialized();
    final loc = tz.getLocation(venueTimezone);
    final s = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final e = DateTime.utc(endDate.year, endDate.month, endDate.day);
    final days = e.difference(s).inDays;
    for (var i = days; i >= 0; i--) {
      final d = s.add(Duration(days: i));
      if (isOpenOnLocalDate(d)) {
        final (openM, closeM) = hoursForLocalDate(d);
        final extraDay = closeM <= openM ? 1 : 0;
        final endD = d.add(Duration(days: extraDay));
        return tz.TZDateTime(
          loc,
          endD.year,
          endD.month,
          endD.day,
          closeM ~/ 60,
          closeM % 60,
        ).toUtc();
      }
    }
    return endDate.toUtc();
  }

  String get dateRangeLabel {
    final fmt = DateFormat('MMM d');
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    if (s == e) return fmt.format(s);
    return '${fmt.format(s)} – ${fmt.format(e)}';
  }

  String get dailyHoursLabel {
    final openStr = formatMinutesOfDay(defaultOpenMinutes);
    final closeStr = formatMinutesOfDay(defaultCloseMinutes);
    final overnightSuffix = defaultCloseMinutes <= defaultOpenMinutes
        ? ' (+1d)'
        : '';
    return '$openStr–$closeStr$overnightSuffix ($venueTimezone)';
  }

  EventSchedule copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? defaultOpenMinutes,
    int? defaultCloseMinutes,
    bool? isCancelled,
  }) {
    return EventSchedule(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      venueTimezone: venueTimezone,
      defaultOpenMinutes: defaultOpenMinutes ?? this.defaultOpenMinutes,
      defaultCloseMinutes: defaultCloseMinutes ?? this.defaultCloseMinutes,
      dailyOverrides: dailyOverrides,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  bool isStartInPast(DateTime now) {
    if (!isValid) return true;
    return startsAtInstant.isBefore(now.toUtc());
  }

  String? validateScheduleAgainst({required DateTime now}) {
    if (!isValid) {
      return 'Invalid event schedule configuration or unrecognized timezone ($venueTimezone).';
    }
    if (isStartInPast(now)) {
      return 'Cannot schedule an event with a start time in the past.';
    }
    return null;
  }

  String? validateStartWindow({required DateTime now}) {
    if (isCancelled) {
      return 'Event schedule has been cancelled.';
    }
    if (!isValid) {
      return 'Event schedule configuration is invalid.';
    }
    ensureTimezonesInitialized();
    final loc = tz.getLocation(venueTimezone);
    final localNow = tz.TZDateTime.from(now, loc);
    final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
    if (!spansLocalDate(today)) {
      return 'Event is not scheduled for today ($venueTimezone).';
    }
    if (!isOpenOnLocalDate(today)) {
      return 'Event venue is closed today according to its schedule.';
    }
    final nowUtc = now.toUtc();
    if (nowUtc.isBefore(startsAtInstant)) {
      return 'Event cannot be started before its scheduled start time ($dailyHoursLabel).';
    }
    if (!nowUtc.isBefore(expiresAtInstant)) {
      return 'Event cannot be started after its scheduled operating window has ended.';
    }
    if (!isOpenAt(now)) {
      return 'Event cannot be started outside scheduled daily operating hours.';
    }
    return null;
  }
}

/// Public-facing projection of an event.
/// Restricted membership sets, invitation lists, join-code hashes, and exact
/// `GeoPoint` coordinates are never exposed on public event projections;
/// private descriptions and attendance counts are disclosed only when authorized.
@immutable
class ProximityEvent {
  const ProximityEvent({
    required this.id,
    required this.hostId,
    required this.hostDisplayName,
    required this.title,
    required this.description,
    required this.categoryTag,
    required this.areaName,
    required this.distanceLabel,
    required this.radiusMeters,
    required this.startsAt,
    required this.duration,
    required this.expiresAt,
    required this.accessType,
    this.schedule,
    this.dateRangeLabel = 'Today',
    this.dailyHoursLabel = 'Flexible hours',
    this.venuePoint,
    this.isAuthorized = true,
    this.isJoined = false,
    this.isHost = false,
    this.participantCount,
    this.isDetailsRedacted = false,
    this.isEnded = false,
    this.locationMoveCount = 0,
    this.lastMovedNotice,
    this.isStarted = false,
    this.startedAt,
    this.pendingHostTransferUserId,
    this.isPendingHostTransferForMe = false,
    this.posterBytes,
  });

  final String id;
  final String hostId;
  final String hostDisplayName;
  final String title;
  final String description;
  final String categoryTag;
  final String areaName;
  final String distanceLabel;
  final double radiusMeters;
  final DateTime startsAt;
  final Duration duration;
  final DateTime expiresAt;
  final EventAccessType accessType;
  final EventSchedule? schedule;
  final String dateRangeLabel;
  final String dailyHoursLabel;

  /// Venue marker center for map display (coarse area center when restricted details are redacted).
  final GeoPoint? venuePoint;
  GeoPoint? get location => venuePoint;
  final bool isAuthorized;
  final bool isJoined;
  final bool isHost;

  /// Optional event poster image bytes.
  final Uint8List? posterBytes;

  /// Null when the caller is not authorized to view restricted attendance.
  final int? participantCount;
  final bool isDetailsRedacted;
  final bool isEnded;
  final int locationMoveCount;
  final String? lastMovedNotice;
  final bool isStarted;
  final DateTime? startedAt;
  final String? pendingHostTransferUserId;
  final bool isPendingHostTransferForMe;

  EventLifecycleStatus statusAt(DateTime now) {
    if (schedule != null && schedule!.isCancelled) {
      return EventLifecycleStatus.cancelled;
    }
    if (isEnded || !expiresAt.isAfter(now)) {
      return EventLifecycleStatus.ended;
    }
    if (isStarted) {
      return EventLifecycleStatus.active;
    }
    return EventLifecycleStatus.scheduled;
  }

  bool get isScheduled =>
      statusAt(DateTime.now()) == EventLifecycleStatus.scheduled;

  bool isActiveAt(DateTime now) {
    return statusAt(now) == EventLifecycleStatus.active;
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
    this.attachment,
  });

  final String id;
  final String senderId;
  final String senderDisplayName;
  final String body;
  final DateTime createdAt;
  final ChatImageAttachment? attachment;
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
    this.fromRealUsername,
    this.fromRealBio,
    this.fromRealAvatarBytes,
    this.isPinned = false,
    this.isArchived = false,
    this.deletedByUserIds = const <String>{},
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
  final String? fromRealUsername;
  final String? fromRealBio;
  final Uint8List? fromRealAvatarBytes;
  final bool isPinned;
  final bool isArchived;
  final Set<String> deletedByUserIds;

  DmRequest copyWith({
    DmRequestStatus? status,
    List<DirectMessage>? messages,
    String? fromRealUsername,
    String? fromRealBio,
    Uint8List? fromRealAvatarBytes,
    bool? isPinned,
    bool? isArchived,
    Set<String>? deletedByUserIds,
  }) {
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
      fromRealUsername: fromRealUsername ?? this.fromRealUsername,
      fromRealBio: fromRealBio ?? this.fromRealBio,
      fromRealAvatarBytes: fromRealAvatarBytes ?? this.fromRealAvatarBytes,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      deletedByUserIds: deletedByUserIds ?? this.deletedByUserIds,
    );
  }
}

enum ReportReasonPreset {
  spamming('Spamming'),
  harassment('Harassment'),
  other('Other');

  const ReportReasonPreset(this.displayName);
  final String displayName;
}

@immutable
class SafetyReport {
  const SafetyReport({
    required this.id,
    required this.targetId,
    required this.targetLabel,
    required this.preset,
    required this.explanation,
    required this.createdAt,
    this.status = 'Local Demo Ticket (Pending Review)',
  });

  final String id;
  final String targetId;
  final String targetLabel;
  final ReportReasonPreset preset;
  final String explanation;
  final DateTime createdAt;
  final String status;

  String get reason => '[${preset.displayName.toUpperCase()}] $explanation';
}
