import 'package:flutter/foundation.dart';

@immutable
class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresIn: (json['expires_in'] as num).toInt(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'expires_in': expiresIn,
  };
}

@immutable
class UserProfileResponse {
  const UserProfileResponse({
    required this.id,
    required this.username,
    required this.email,
    required this.anonymousHandle,
    required this.identityMode,
    required this.visibleInNearby,
    required this.ghostBrowseNearby,
    required this.isGhostMode,
    required this.nearbyRadiusMeters,
    required this.messageRetentionHours,
    required this.bio,
    required this.createdAt,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    return UserProfileResponse(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      anonymousHandle: json['anonymous_handle'] as String,
      identityMode: json['identity_mode'] as String,
      visibleInNearby: json['visible_in_nearby'] as bool,
      ghostBrowseNearby: json['ghost_browse_nearby'] as bool,
      isGhostMode: json['is_ghost_mode'] as bool,
      nearbyRadiusMeters: (json['nearby_radius_meters'] as num).toDouble(),
      messageRetentionHours: (json['message_retention_hours'] as num).toInt(),
      bio: (json['bio'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String username;
  final String email;
  final String anonymousHandle;
  final String identityMode;
  final bool visibleInNearby;
  final bool ghostBrowseNearby;
  final bool isGhostMode;
  final double nearbyRadiusMeters;
  final int messageRetentionHours;
  final String bio;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'anonymous_handle': anonymousHandle,
    'identity_mode': identityMode,
    'visible_in_nearby': visibleInNearby,
    'ghost_browse_nearby': ghostBrowseNearby,
    'is_ghost_mode': isGhostMode,
    'nearby_radius_meters': nearbyRadiusMeters,
    'message_retention_hours': messageRetentionHours,
    'bio': bio,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

@immutable
class PublicIdentityProjection {
  const PublicIdentityProjection({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.isAnonymous,
  });

  factory PublicIdentityProjection.fromJson(Map<String, dynamic> json) {
    return PublicIdentityProjection(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      bio: (json['bio'] as String?) ?? '',
      isAnonymous: json['is_anonymous'] as bool,
    );
  }

  final String userId;
  final String displayName;
  final String bio;
  final bool isAnonymous;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'bio': bio,
    'is_anonymous': isAnonymous,
  };
}

@immutable
class LocationFixRequest {
  const LocationFixRequest({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.recordedAt,
    this.areaName,
  });

  factory LocationFixRequest.fromJson(Map<String, dynamic> json) {
    return LocationFixRequest(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracy_meters'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      areaName: json['area_name'] as String?,
    );
  }

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;
  final String? areaName;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_meters': accuracyMeters,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    if (areaName != null) 'area_name': areaName,
  };
}

@immutable
class LandmarkResponse {
  const LandmarkResponse({
    required this.id,
    required this.name,
    required this.areaName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.category,
    this.distanceMeters,
    this.distanceLabel,
    this.isUserInside,
  });

  factory LandmarkResponse.fromJson(Map<String, dynamic> json) {
    return LandmarkResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      areaName: json['area_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      category: json['category'] as String,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      distanceLabel: json['distance_label'] as String?,
      isUserInside: json['is_user_inside'] as bool?,
    );
  }

  final String id;
  final String name;
  final String areaName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String category;
  final double? distanceMeters;
  final String? distanceLabel;
  final bool? isUserInside;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'area_name': areaName,
    'latitude': latitude,
    'longitude': longitude,
    'radius_meters': radiusMeters,
    'category': category,
    if (distanceMeters != null) 'distance_meters': distanceMeters,
    if (distanceLabel != null) 'distance_label': distanceLabel,
    if (isUserInside != null) 'is_user_inside': isUserInside,
  };
}

@immutable
class LandmarkVisitResponse {
  const LandmarkVisitResponse({
    required this.sessionId,
    required this.landmarkId,
    required this.enteredAt,
    required this.lastHeartbeatAt,
    required this.minMessageSequence,
    required this.isActive,
  });

  factory LandmarkVisitResponse.fromJson(Map<String, dynamic> json) {
    return LandmarkVisitResponse(
      sessionId: json['session_id'] as String,
      landmarkId: json['landmark_id'] as String,
      enteredAt: DateTime.parse(json['entered_at'] as String),
      lastHeartbeatAt: DateTime.parse(json['last_heartbeat_at'] as String),
      minMessageSequence: (json['min_message_sequence'] as num).toInt(),
      isActive: json['is_active'] as bool,
    );
  }

  final String sessionId;
  final String landmarkId;
  final DateTime enteredAt;
  final DateTime lastHeartbeatAt;
  final int minMessageSequence;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'landmark_id': landmarkId,
    'entered_at': enteredAt.toUtc().toIso8601String(),
    'last_heartbeat_at': lastHeartbeatAt.toUtc().toIso8601String(),
    'min_message_sequence': minMessageSequence,
    'is_active': isActive,
  };
}

@immutable
class ChatMessageResponse {
  const ChatMessageResponse({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderDisplayName,
    required this.isAnonymous,
    required this.body,
    required this.sequence,
    required this.areaName,
    required this.distanceLabel,
    this.attachmentId,
    required this.isSystemNotice,
    required this.createdAt,
    required this.expiresAt,
  });

  factory ChatMessageResponse.fromJson(Map<String, dynamic> json) {
    return ChatMessageResponse(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      senderId: json['sender_id'] as String,
      senderDisplayName: json['sender_display_name'] as String,
      isAnonymous: json['is_anonymous'] as bool,
      body: json['body'] as String,
      sequence: (json['sequence'] as num).toInt(),
      areaName: json['area_name'] as String,
      distanceLabel: json['distance_label'] as String,
      attachmentId: json['attachment_id'] as String?,
      isSystemNotice: (json['is_system_notice'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final String id;
  final String channelId;
  final String senderId;
  final String senderDisplayName;
  final bool isAnonymous;
  final String body;
  final int sequence;
  final String areaName;
  final String distanceLabel;
  final String? attachmentId;
  final bool isSystemNotice;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel_id': channelId,
    'sender_id': senderId,
    'sender_display_name': senderDisplayName,
    'is_anonymous': isAnonymous,
    'body': body,
    'sequence': sequence,
    'area_name': areaName,
    'distance_label': distanceLabel,
    if (attachmentId != null) 'attachment_id': attachmentId,
    'is_system_notice': isSystemNotice,
    'created_at': createdAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };
}

@immutable
class EventResponse {
  const EventResponse({
    required this.id,
    required this.hostId,
    required this.title,
    required this.description,
    required this.categoryTag,
    required this.areaName,
    required this.radiusMeters,
    required this.accessType,
    required this.startsAt,
    required this.expiresAt,
    required this.venueTimezone,
    required this.defaultOpenMinutes,
    required this.defaultCloseMinutes,
    this.dailyOverrides = const <String, dynamic>{},
    required this.isCancelled,
    required this.isEnded,
    required this.isStarted,
    this.startedAt,
    this.participantCount,
    this.isJoined,
    this.isHost,
    this.distanceLabel,
    required this.createdAt,
  });

  factory EventResponse.fromJson(Map<String, dynamic> json) {
    return EventResponse(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      categoryTag: json['category_tag'] as String,
      areaName: json['area_name'] as String,
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      accessType: json['access_type'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      venueTimezone: (json['venue_timezone'] as String?) ?? 'America/New_York',
      defaultOpenMinutes: (json['default_open_minutes'] as num?)?.toInt() ?? 540,
      defaultCloseMinutes: (json['default_close_minutes'] as num?)?.toInt() ?? 1320,
      dailyOverrides: (json['daily_overrides'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      isCancelled: (json['is_cancelled'] as bool?) ?? false,
      isEnded: (json['is_ended'] as bool?) ?? false,
      isStarted: (json['is_started'] as bool?) ?? false,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      participantCount: (json['participant_count'] as num?)?.toInt(),
      isJoined: json['is_joined'] as bool?,
      isHost: json['is_host'] as bool?,
      distanceLabel: json['distance_label'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String hostId;
  final String title;
  final String description;
  final String categoryTag;
  final String areaName;
  final double radiusMeters;
  final String accessType;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String venueTimezone;
  final int defaultOpenMinutes;
  final int defaultCloseMinutes;
  final Map<String, dynamic> dailyOverrides;
  final bool isCancelled;
  final bool isEnded;
  final bool isStarted;
  final DateTime? startedAt;
  final int? participantCount;
  final bool? isJoined;
  final bool? isHost;
  final String? distanceLabel;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'host_id': hostId,
    'title': title,
    'description': description,
    'category_tag': categoryTag,
    'area_name': areaName,
    'radius_meters': radiusMeters,
    'access_type': accessType,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'venue_timezone': venueTimezone,
    'default_open_minutes': defaultOpenMinutes,
    'default_close_minutes': defaultCloseMinutes,
    'daily_overrides': dailyOverrides,
    'is_cancelled': isCancelled,
    'is_ended': isEnded,
    'is_started': isStarted,
    if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
    if (participantCount != null) 'participant_count': participantCount,
    if (isJoined != null) 'is_joined': isJoined,
    if (isHost != null) 'is_host': isHost,
    if (distanceLabel != null) 'distance_label': distanceLabel,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

@immutable
class NearbyParticipantResponse {
  const NearbyParticipantResponse({
    required this.userId,
    required this.displayName,
    required this.isAnonymous,
    required this.areaName,
    required this.distanceLabel,
    this.visibleInNearby = true,
  });

  factory NearbyParticipantResponse.fromJson(Map<String, dynamic> json) {
    return NearbyParticipantResponse(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      isAnonymous: json['is_anonymous'] as bool,
      areaName: json['area_name'] as String,
      distanceLabel: json['distance_label'] as String,
      visibleInNearby: (json['visible_in_nearby'] as bool?) ?? true,
    );
  }

  final String userId;
  final String displayName;
  final bool isAnonymous;
  final String areaName;
  final String distanceLabel;
  final bool visibleInNearby;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'is_anonymous': isAnonymous,
    'area_name': areaName,
    'distance_label': distanceLabel,
    'visible_in_nearby': visibleInNearby,
  };
}

@immutable
class MediaUploadResponse {
  const MediaUploadResponse({
    required this.mediaId,
    required this.mimeType,
    required this.sizeBytes,
    required this.width,
    required this.height,
  });

  factory MediaUploadResponse.fromJson(Map<String, dynamic> json) {
    return MediaUploadResponse(
      mediaId: json['media_id'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }

  final String mediaId;
  final String mimeType;
  final int sizeBytes;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {
    'media_id': mediaId,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'width': width,
    'height': height,
  };
}

@immutable
class MediaDownloadTokenResponse {
  const MediaDownloadTokenResponse({
    required this.token,
    required this.mediaId,
    required this.channelId,
    required this.expiresAt,
  });

  factory MediaDownloadTokenResponse.fromJson(Map<String, dynamic> json) {
    return MediaDownloadTokenResponse(
      token: json['token'] as String,
      mediaId: json['media_id'] as String,
      channelId: json['channel_id'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final String token;
  final String mediaId;
  final String channelId;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
    'token': token,
    'media_id': mediaId,
    'channel_id': channelId,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };
}
