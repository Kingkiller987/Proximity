import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../auth/auth_session_store.dart';
import '../identity/anonymous_name_generator.dart';
import '../location/location_service.dart';
import '../media/ephemeral_media_cache.dart';
import '../media/media_sanitizer.dart';
import '../models/models.dart';
import '../network/api_client.dart';
import '../network/api_models.dart' hide PublicIdentityProjection;

@immutable
class _StoredNearbyParticipant {
  const _StoredNearbyParticipant({
    required this.userId,
    required this.displayName,
    required this.isAnonymous,
    required this.location,
    required this.visibleInNearby,
    this.avatarBytes,
  });

  final String userId;
  final String displayName;
  final bool isAnonymous;
  final GeoPoint location;
  final bool visibleInNearby;
  final Uint8List? avatarBytes;
}

@immutable
class _StoredChatMessage {
  const _StoredChatMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderDisplayName,
    required this.isAnonymous,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
    required this.originPoint,
    this.sequence = 0,
    this.isSystemNotice = false,
    this.attachment,
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
  final int sequence;
  final bool isSystemNotice;
  final ChatImageAttachment? attachment;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

@immutable
class _StoredEvent {
  const _StoredEvent({
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
    this.schedule,
    this.joinCodeHash,
    this.invitedUserIds = const <String>{},
    this.participantIds = const <String>{},
    this.isEnded = false,
    this.locationMoveCount = 0,
    this.lastMovedNotice,
    this.isStarted = false,
    this.startedAt,
    this.pendingHostTransferUserId,
    this.posterBytes,
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
  final EventSchedule? schedule;
  final String? joinCodeHash;
  final Set<String> invitedUserIds;
  final Set<String> participantIds;
  final bool isEnded;
  final int locationMoveCount;
  final String? lastMovedNotice;
  final bool isStarted;
  final DateTime? startedAt;
  final String? pendingHostTransferUserId;
  final Uint8List? posterBytes;

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

  bool isActiveAt(DateTime now) {
    return statusAt(now) == EventLifecycleStatus.active;
  }

  bool isAvailableForDiscoveryAt(DateTime now) {
    if (isEnded) return false;
    if (schedule != null && schedule!.isCancelled) return false;
    return expiresAt.isAfter(now);
  }

  bool occursOnLocalDate(DateTime date) {
    if (isEnded) return false;
    if (schedule != null) {
      return schedule!.occursOnLocalDate(date);
    }
    final targetDay = DateTime.utc(date.year, date.month, date.day);
    final startDay = DateTime.utc(startsAt.year, startsAt.month, startsAt.day);
    final endDay = DateTime.utc(expiresAt.year, expiresAt.month, expiresAt.day);
    return !targetDay.isBefore(startDay) && !targetDay.isAfter(endDay);
  }

  bool verifyJoinCode(String candidate) {
    if (accessType != EventAccessType.joinCode || joinCodeHash == null) {
      return false;
    }
    return hashSecretCode(candidate, salt: id) == joinCodeHash;
  }

  /// Moving an event preserves its ID, start time, and original expiration timer.
  _StoredEvent moveLocation(GeoPoint newLocation, {required String notice}) {
    return _StoredEvent(
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
      schedule: schedule,
      joinCodeHash: joinCodeHash,
      invitedUserIds: invitedUserIds,
      participantIds: participantIds,
      isEnded: isEnded,
      locationMoveCount: locationMoveCount + 1,
      lastMovedNotice: notice,
      isStarted: isStarted,
      startedAt: startedAt,
      pendingHostTransferUserId: pendingHostTransferUserId,
      posterBytes: posterBytes,
    );
  }

  _StoredEvent copyWithDetails({
    String? hostId,
    String? hostDisplayName,
    String? title,
    String? description,
    double? radiusMeters,
    bool? isEnded,
    Set<String>? participantIds,
    EventSchedule? schedule,
    DateTime? startsAt,
    Duration? duration,
    DateTime? expiresAt,
    bool? isStarted,
    DateTime? startedAt,
    String? pendingHostTransferUserId,
    bool clearPendingHostTransfer = false,
    Uint8List? posterBytes,
    bool clearPoster = false,
  }) {
    return _StoredEvent(
      id: id,
      hostId: hostId ?? this.hostId,
      hostDisplayName: hostDisplayName ?? this.hostDisplayName,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryTag: categoryTag,
      location: location,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      startsAt: startsAt ?? this.startsAt,
      duration: duration ?? this.duration,
      expiresAt: expiresAt ?? this.expiresAt,
      accessType: accessType,
      schedule: schedule ?? this.schedule,
      joinCodeHash: joinCodeHash,
      invitedUserIds: invitedUserIds,
      participantIds: participantIds ?? this.participantIds,
      isEnded: isEnded ?? this.isEnded,
      locationMoveCount: locationMoveCount,
      lastMovedNotice: lastMovedNotice,
      isStarted: isStarted ?? this.isStarted,
      startedAt: startedAt ?? this.startedAt,
      pendingHostTransferUserId: clearPendingHostTransfer
          ? null
          : (pendingHostTransferUserId ?? this.pendingHostTransferUserId),
      posterBytes: clearPoster ? null : (posterBytes ?? this.posterBytes),
    );
  }
}

@immutable
class _StoredEventAlert {
  const _StoredEventAlert({
    required this.eventId,
    required this.hostId,
    required this.message,
  });

  final String eventId;
  final String hostId;
  final String message;
}

@immutable
class _StoredLandmark {
  const _StoredLandmark({
    required this.id,
    required this.name,
    required this.areaName,
    required this.center,
    required this.radiusMeters,
    this.category = LandmarkCategory.pointOfInterest,
    this.parentLandmarkId,
  });

  final String id;
  final String name;
  final String areaName;
  final GeoPoint center;
  final double radiusMeters;
  final LandmarkCategory category;
  final String? parentLandmarkId;
}

@immutable
class _LandmarkVisitSession {
  const _LandmarkVisitSession({
    required this.sessionId,
    required this.landmarkId,
    required this.enteredAt,
    required this.lastHeartbeatAt,
    required this.minMessageSequence,
  });

  final String sessionId;
  final String landmarkId;
  final DateTime enteredAt;
  final DateTime lastHeartbeatAt;
  final int minMessageSequence;

  _LandmarkVisitSession copyWithHeartbeat(DateTime heartbeatAt) {
    return _LandmarkVisitSession(
      sessionId: sessionId,
      landmarkId: landmarkId,
      enteredAt: enteredAt,
      lastHeartbeatAt: heartbeatAt,
      minMessageSequence: minMessageSequence,
    );
  }
}

enum _MediaChannelKind { landmark, event, dm }

@immutable
class _StoredPrivateMediaObject {
  const _StoredPrivateMediaObject({
    required this.attachment,
    required this.sanitizedBytes,
    required this.channelKind,
    required this.channelId,
    required this.senderId,
    required this.createdAt,
    required this.expiresAt,
    required this.sequence,
  });

  final ChatImageAttachment attachment;
  final Uint8List sanitizedBytes;
  final _MediaChannelKind channelKind;
  final String channelId;
  final String senderId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int sequence;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

@immutable
class _StagedImageUpload {
  const _StagedImageUpload({
    required this.uploadId,
    required this.channelId,
    required this.sanitizedResult,
    required this.state,
    this.errorMessage,
  });

  final String uploadId;
  final String channelId;
  final SanitizedImageResult sanitizedResult;
  final UploadLifecycleState state;
  final String? errorMessage;

  _StagedImageUpload copyWith({
    UploadLifecycleState? state,
    String? errorMessage,
  }) {
    return _StagedImageUpload(
      uploadId: uploadId,
      channelId: channelId,
      sanitizedResult: sanitizedResult,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Coordinates nearby discovery, temporary events, attendance privacy, and safety rules.
/// shortcut: in-memory store for Milestone 1, back with local Supabase + RLS in Milestone 2.
class AppController extends ChangeNotifier {
  AppController({
    DateTime Function()? clock,
    String? persistedAnonymousHandle,
    int? handleSeed,
    Map<String, String>? handleStorage,
    this.locationService,
    this.maxImageBytes = 5 * 1024 * 1024,
    AuthSessionStore? sessionStore,
    this.apiClient,
  }) : _clock = clock ?? DateTime.now,
       _handleStorage = handleStorage,
       sessionStore = sessionStore ?? LocalDemoSessionStore() {
    final storedHandle =
        persistedAnonymousHandle ?? handleStorage?['anonymous_handle'];
    _seedInitialData(
      persistedAnonymousHandle: storedHandle,
      handleSeed: handleSeed,
    );
    if (handleStorage != null) {
      handleStorage['anonymous_handle'] = _profile.anonymousHandle;
    }
    final savedTheme = handleStorage?['app_theme_mode'];
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    }
  }

  final Map<String, String>? _handleStorage;
  final LocationService? locationService;
  final int maxImageBytes;
  final AuthSessionStore sessionStore;
  final ApiClient? apiClient;

  bool get isConnectedToBackend => apiClient != null && apiClient!.isAuthenticated;

  static const String generalChannelId = 'lm-staller';

  static const Duration maxLocationAge = Duration(seconds: 30);
  static const double maxGpsAccuracyMeters = 50.0;

  static const LandmarkCreationPolicy landmarkCreationPolicy =
      LandmarkCreationPolicy.curatedSystemOnly;

  static const String redactedJoinCodeDescription =
      'Join-code protected event. Enter the join code to unlock event details and chat.';
  static const String redactedInviteOnlyDescription =
      'Invite-only event. Only invited attendees can view event details and chat.';

  static const List<double> supportedNearbyRadiiMeters = <double>[
    250,
    500,
    1000,
    2500,
  ];

  /// shortcut: in-memory per-event join-code attempt limit for Milestone 1, enforce server-side rate limiting in Milestone 2.
  static const int maxJoinCodeAttempts = 5;

  static final Uint8List demoAvatarBytes = Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  static const List<GeoPoint> presetLocations = <GeoPoint>[
    GeoPoint(
      latitude: 40.9148,
      longitude: -73.1235,
      areaName: 'Staller Steps & Academic Mall',
    ),
    GeoPoint(
      latitude: 40.9162,
      longitude: -73.1208,
      areaName: 'East Side Dining Commons',
    ),
    GeoPoint(
      latitude: 40.9126,
      longitude: -73.1264,
      areaName: 'Old Computer Science Quad',
    ),
    GeoPoint(
      latitude: 40.9465,
      longitude: -73.0691,
      areaName: 'Port Jefferson Harbor',
    ),
  ];

  static const List<_StoredLandmark> _defaultCuratedLandmarks =
      <_StoredLandmark>[
        _StoredLandmark(
          id: 'lm-sbu-campus',
          name: 'Stony Brook University Campus',
          areaName: 'Staller Steps & Academic Mall',
          center: GeoPoint(
            latitude: 40.9150,
            longitude: -73.1230,
            areaName: 'Stony Brook Campus',
          ),
          radiusMeters: 800,
          category: LandmarkCategory.complex,
        ),
        _StoredLandmark(
          id: 'lm-staller',
          name: 'Staller Steps',
          areaName: 'Staller Steps & Academic Mall',
          center: GeoPoint(
            latitude: 40.9154,
            longitude: -73.1225,
            areaName: 'Staller Steps',
          ),
          radiusMeters: 180,
          category: LandmarkCategory.pointOfInterest,
          parentLandmarkId: 'lm-sbu-campus',
        ),
        _StoredLandmark(
          id: 'lm-library',
          name: 'Library North Reading Room',
          areaName: 'Staller Steps & Academic Mall',
          center: GeoPoint(
            latitude: 40.9148,
            longitude: -73.1235,
            areaName: 'Library North Reading Room',
          ),
          radiusMeters: 160,
          category: LandmarkCategory.venue,
          parentLandmarkId: 'lm-sbu-campus',
        ),
        _StoredLandmark(
          id: 'lm-dining',
          name: 'East Side Dining Patio',
          areaName: 'East Side Dining Commons',
          center: GeoPoint(
            latitude: 40.9162,
            longitude: -73.1208,
            areaName: 'East Side Dining Patio',
          ),
          radiusMeters: 160,
          category: LandmarkCategory.venue,
          parentLandmarkId: 'lm-sbu-campus',
        ),
        _StoredLandmark(
          id: 'lm-harbor',
          name: 'Port Jefferson Harbor Pier',
          areaName: 'Port Jefferson Harbor',
          center: GeoPoint(
            latitude: 40.9465,
            longitude: -73.0691,
            areaName: 'Port Jefferson Harbor Pier',
          ),
          radiusMeters: 220,
          category: LandmarkCategory.pointOfInterest,
        ),
      ];

  final List<_StoredLandmark> _curatedLandmarks = List<_StoredLandmark>.of(
    _defaultCuratedLandmarks,
  );

  @visibleForTesting
  void addLandmarkForTest({
    required String id,
    required String name,
    required String areaName,
    required GeoPoint center,
    required double radiusMeters,
    LandmarkCategory category = LandmarkCategory.pointOfInterest,
    String? parentLandmarkId,
  }) {
    _curatedLandmarks.add(
      _StoredLandmark(
        id: id,
        name: name,
        areaName: areaName,
        center: center,
        radiusMeters: radiusMeters,
        category: category,
        parentLandmarkId: parentLandmarkId,
      ),
    );
    _syncLandmarkVisitSessions(now);
    notifyListeners();
  }

  final DateTime Function() _clock;
  DateTime? _manualNowOverride;
  DateTime get now => _manualNowOverride ?? _clock();

  void setMockNow(DateTime mockNow) {
    _manualNowOverride = mockNow;
    notifyListeners();
  }

  LocationPermissionState _permissionState = LocationPermissionState.simulated;
  LocationPermissionState get permissionState => _permissionState;

  GeoPoint _currentLocation = presetLocations.first;
  GeoPoint get currentLocation => _currentLocation;

  LocationFix? _latestLocationFix;
  LocationFix? get latestLocationFix => _latestLocationFix;
  bool _enforceFixFreshness = false;
  bool _isAppLifecycleActive = true;
  bool get isAppLifecycleActive => _isAppLifecycleActive;

  int _visitCounter = 0;
  int _messageSeqCounter = 0;
  final Map<String, _LandmarkVisitSession> _activeLandmarkVisits =
      <String, _LandmarkVisitSession>{};
  final Map<String, DateTime> _lastReadLandmarkAt = <String, DateTime>{};
  String _selectedLandmarkId = 'lm-staller';
  String get selectedLandmarkId => _selectedLandmarkId;
  String? activeVisitSessionIdFor(String landmarkId) =>
      _activeLandmarkVisits[landmarkId]?.sessionId;

  late UserProfile _profile;
  UserProfile get profile => _profile;

  final List<_StoredNearbyParticipant> _otherParticipants =
      <_StoredNearbyParticipant>[];
  final List<_StoredChatMessage> _messages = <_StoredChatMessage>[];
  final List<_StoredEvent> _events = <_StoredEvent>[];
  final List<DmRequest> _dmRequests = <DmRequest>[];
  final Set<String> _blockedUserIds = <String>{};
  final Map<String, String> _blockedUserLabels = <String, String>{};
  final List<SafetyReport> _reports = <SafetyReport>[];
  final List<_StoredEventAlert> _eventAlerts = <_StoredEventAlert>[];
  final Map<String, int> _failedJoinCodeAttempts = <String, int>{};
  String? _pendingHostMovementEventId;
  String? get pendingHostMovementEventId => _pendingHostMovementEventId;
  final Set<String> _dismissedHostMovementEvents = <String>{};

  void dismissHostMovementPrompt(String eventId) {
    if (_pendingHostMovementEventId == eventId) {
      _pendingHostMovementEventId = null;
    }
    _dismissedHostMovementEvents.add(eventId);
    notifyListeners();
  }

  bool _isOnboardingActive = false;
  bool get isOnboardingActive => _isOnboardingActive;
  final Set<String> _onboardedUserIds = <String>{'user-me'};

  bool shouldShowOnboardingFor(String userId) =>
      !_onboardedUserIds.contains(userId);

  void startOnboarding() {
    _isOnboardingActive = true;
    notifyListeners();
  }

  void completeOnboarding() {
    _isOnboardingActive = false;
    _onboardedUserIds.add(_profile.id);
    notifyListeners();
  }

  void skipOnboarding() => completeOnboarding();

  int _mediaCounter = 0;
  final EphemeralMediaCache _mediaCache = EphemeralMediaCache();
  final Map<String, _StoredPrivateMediaObject> _privateMediaObjects =
      <String, _StoredPrivateMediaObject>{};
  final Map<String, _StagedImageUpload> _stagedUploads =
      <String, _StagedImageUpload>{};
  final Map<String, MediaDownloadToken> _issuedDownloadTokens =
      <String, MediaDownloadToken>{};

  Set<String> get blockedUserIds => Set<String>.unmodifiable(_blockedUserIds);
  Map<String, String> get blockedUserLabels =>
      Map<String, String>.unmodifiable(_blockedUserLabels);
  List<SafetyReport> get reports => List<SafetyReport>.unmodifiable(_reports);
  List<String> get eventAlerts {
    if (!hasLocationAccess) return const <String>[];
    return List<String>.unmodifiable(
      _eventAlerts
          .where(
            (a) =>
                !_blockedUserIds.contains(a.hostId) &&
                isAuthorizedForEvent(a.eventId),
          )
          .map((a) => a.message),
    );
  }

  bool get hasLocationAccess =>
      _permissionState == LocationPermissionState.granted ||
      _permissionState == LocationPermissionState.simulated;

  /// Enforces permission, foreground lifecycle, GPS horizontal accuracy <= 50m,
  /// and location fix freshness <= 30s.
  bool get hasFreshAccurateLocation {
    if (!hasLocationAccess || !_isAppLifecycleActive) return false;
    final fix = _latestLocationFix;
    if (fix == null) return false;
    if (fix.accuracyMeters < 0 || fix.accuracyMeters > maxGpsAccuracyMeters) {
      return false;
    }
    if (_enforceFixFreshness) {
      final age = now.difference(fix.recordedAt);
      if (age.isNegative || age > maxLocationAge) {
        return false;
      }
    }
    return true;
  }

  bool get canParticipateInNearby =>
      hasFreshAccurateLocation &&
      !_profile.isGhostMode &&
      (_profile.visibleInNearby || _profile.ghostBrowseNearby);

  bool _isAuthenticated = true;
  bool get isAuthenticated => _isAuthenticated;
  int _userCounter = 0;

  final Map<String, UserProfile> _mockAccounts = <String, UserProfile>{};

  void _seedInitialData({String? persistedAnonymousHandle, int? handleSeed}) {
    final t0 = now;
    final takenHandles = <String>{
      'CosmicOtter',
      'PineOwl',
      'SilentLynx',
      'TidalHeron',
    };
    final assignedHandle =
        (persistedAnonymousHandle != null &&
            AnonymousNameGenerator.isValidHandle(persistedAnonymousHandle) &&
            !takenHandles.contains(persistedAnonymousHandle))
        ? persistedAnonymousHandle
        : AnonymousNameGenerator.generate(
            existingHandles: takenHandles,
            seed: handleSeed ?? 101,
          );

    _profile = UserProfile(
      id: 'user-me',
      anonymousHandle: assignedHandle,
      username: 'Alex',
      identityMode: IdentityMode.anonymous,
      visibleInNearby: false, // Default privacy-first: ghost browse on
      ghostBrowseNearby: true,
      nearbyRadiusMeters: 500,
      messageRetentionHours: 24,
    );
    _mockAccounts['alex'] = _profile;

    _latestLocationFix = LocationFix(
      latitude: _currentLocation.latitude,
      longitude: _currentLocation.longitude,
      accuracyMeters: 8.0,
      recordedAt: t0,
      areaName: _currentLocation.areaName,
    );

    final initialVisitEnteredAt = t0.subtract(const Duration(minutes: 20));
    for (final lm in _curatedLandmarks) {
      final dist = _currentLocation.distanceMetersTo(lm.center);
      if (dist <= lm.radiusMeters) {
        _activeLandmarkVisits[lm.id] = _LandmarkVisitSession(
          sessionId: 'visit-${++_visitCounter}',
          landmarkId: lm.id,
          enteredAt: initialVisitEnteredAt,
          lastHeartbeatAt: t0,
          minMessageSequence: 1,
        );
      }
    }

    _otherParticipants.addAll(<_StoredNearbyParticipant>[
      _StoredNearbyParticipant(
        userId: 'user-hana',
        displayName: '@hana_k',
        isAnonymous: false,
        location: const GeoPoint(
          latitude: 40.9151,
          longitude: -73.1231,
          areaName: 'Staller Steps',
        ),
        visibleInNearby: true,
        avatarBytes: demoAvatarBytes,
      ),
      const _StoredNearbyParticipant(
        userId: 'user-pine',
        displayName: 'PineOwl#109',
        isAnonymous: true,
        location: GeoPoint(
          latitude: 40.9160,
          longitude: -73.1212,
          areaName: 'East Side Commons',
        ),
        visibleInNearby: true,
      ),
      const _StoredNearbyParticipant(
        userId: 'user-ghost',
        displayName: 'SilentLynx#881',
        isAnonymous: true,
        location: GeoPoint(
          latitude: 40.9149,
          longitude: -73.1234,
          areaName: 'Staller Steps',
        ),
        visibleInNearby: false, // Ghost browser: never exposed in nearby list
      ),
      const _StoredNearbyParticipant(
        userId: 'user-harbor',
        displayName: '@sailor_dan',
        isAnonymous: false,
        location: GeoPoint(
          latitude: 40.9462,
          longitude: -73.0695,
          areaName: 'Port Jefferson Harbor',
        ),
        visibleInNearby: true,
      ),
    ]);

    _messages.addAll(<_StoredChatMessage>[
      // Pre-entry historical message (created before initialVisitEnteredAt) — never revealed!
      _StoredChatMessage(
        id: 'msg-pre-entry',
        channelId: 'lm-staller',
        senderId: 'user-hana',
        senderDisplayName: '@hana_k',
        isAnonymous: false,
        body: 'Earlier morning note before you entered Staller Steps.',
        createdAt: t0.subtract(const Duration(minutes: 45)),
        expiresAt: t0.add(const Duration(hours: 23, minutes: 15)),
        originPoint: const GeoPoint(
          latitude: 40.9154,
          longitude: -73.1225,
          areaName: 'Staller Steps',
        ),
        sequence: 0,
      ),
      _StoredChatMessage(
        id: 'msg-1',
        channelId: 'lm-staller',
        senderId: 'user-hana',
        senderDisplayName: '@hana_k',
        isAnonymous: false,
        body: 'Acoustic guitar pop-up on the Staller grass right now — bring a blanket!',
        createdAt: t0.subtract(const Duration(minutes: 18)),
        expiresAt: t0.add(const Duration(hours: 23, minutes: 42)),
        originPoint: const GeoPoint(
          latitude: 40.9151,
          longitude: -73.1231,
          areaName: 'Staller Steps',
        ),
        sequence: ++_messageSeqCounter,
      ),
      _StoredChatMessage(
        id: 'msg-2',
        channelId: 'lm-staller',
        senderId: 'user-pine',
        senderDisplayName: 'PineOwl#109',
        isAnonymous: true,
        body: 'Line at the espresso cart near the library is zero people right now.',
        createdAt: t0.subtract(const Duration(minutes: 14)),
        expiresAt: t0.add(const Duration(hours: 11, minutes: 46)),
        originPoint: const GeoPoint(
          latitude: 40.9160,
          longitude: -73.1212,
          areaName: 'East Side Commons',
        ),
        sequence: ++_messageSeqCounter,
      ),
      _StoredChatMessage(
        id: 'msg-expired',
        channelId: 'lm-staller',
        senderId: 'user-pine',
        senderDisplayName: 'PineOwl#109',
        isAnonymous: true,
        body: 'Yesterday coffee run — this message is already expired.',
        createdAt: t0.subtract(const Duration(hours: 26)),
        expiresAt: t0.subtract(const Duration(hours: 2)),
        originPoint: presetLocations.first,
        sequence: ++_messageSeqCounter,
      ),
    ]);

    const openJamId = 'evt-open-jam';
    const studyGroupId = 'evt-study-code';
    const rooftopInviteId = 'evt-rooftop-invite';
    const chessCodeId = 'evt-chess-code';

    _events.addAll(<_StoredEvent>[
      _StoredEvent(
        id: openJamId,
        hostId: 'user-hana',
        hostDisplayName: '@hana_k',
        title: 'Twilight Lawn Acoustic Jam',
        description: 'Open circle for acoustic instruments and listeners. Bring chord sheets or just hang out.',
        categoryTag: 'Live Music',
        location: const GeoPoint(
          latitude: 40.9151,
          longitude: -73.1231,
          areaName: 'Staller Steps & Academic Mall',
        ),
        radiusMeters: 400,
        startsAt: t0.subtract(const Duration(minutes: 30)),
        duration: const Duration(hours: 3),
        expiresAt: t0.add(const Duration(hours: 2, minutes: 30)),
        accessType: EventAccessType.public,
        participantIds: const <String>{'user-hana', 'user-pine'},
        isStarted: true,
        startedAt: t0.subtract(const Duration(minutes: 30)),
      ),
      _StoredEvent(
        id: studyGroupId,
        hostId: 'user-me',
        hostDisplayName: _profile.activeDisplayName,
        title: 'Systems & PostGIS Late-Night Sprint',
        description: 'Quiet table near the courtyard outlets. Ask the host for today\'s whiteboard code.',
        categoryTag: 'Study Sprint',
        location: const GeoPoint(
          latitude: 40.9126,
          longitude: -73.1264,
          areaName: 'Old Computer Science Quad',
        ),
        radiusMeters: 600,
        startsAt: t0.subtract(const Duration(minutes: 20)),
        duration: const Duration(hours: 4),
        expiresAt: t0.add(const Duration(hours: 3, minutes: 40)),
        accessType: EventAccessType.joinCode,
        joinCodeHash: hashSecretCode('2468', salt: studyGroupId),
        participantIds: const <String>{'user-me', 'user-pine'},
        isStarted: true,
        startedAt: t0.subtract(const Duration(minutes: 20)),
      ),
      _StoredEvent(
        id: rooftopInviteId,
        hostId: 'user-hana',
        hostDisplayName: '@hana_k',
        title: 'Founders Rooftop Tea Circle',
        description:
            'Small invite-only gathering for pre-registered attendees.',
        categoryTag: 'Private Gathering',
        location: const GeoPoint(
          latitude: 40.9162,
          longitude: -73.1208,
          areaName: 'East Side Dining Commons',
        ),
        radiusMeters: 500,
        startsAt: t0.add(const Duration(minutes: 15)),
        duration: const Duration(hours: 2),
        expiresAt: t0.add(const Duration(hours: 2, minutes: 15)),
        accessType: EventAccessType.inviteOnly,
        invitedUserIds: const <String>{'user-hana'}, // user-me not invited
        participantIds: const <String>{'user-hana'},
        isStarted: false,
      ),
      _StoredEvent(
        id: chessCodeId,
        hostId: 'user-pine',
        hostDisplayName: 'PineOwl#109',
        title: 'Courtyard Blitz Chess Club',
        description: 'Bring a board or clock by the third stone bench. Ask PineOwl for the join code.',
        categoryTag: 'Board Games',
        location: const GeoPoint(
          latitude: 40.9160,
          longitude: -73.1212,
          areaName: 'East Side Dining Commons',
        ),
        radiusMeters: 500,
        startsAt: t0.subtract(const Duration(minutes: 10)),
        duration: const Duration(hours: 2),
        expiresAt: t0.add(const Duration(hours: 1, minutes: 50)),
        accessType: EventAccessType.joinCode,
        joinCodeHash: hashSecretCode('1357', salt: chessCodeId),
        participantIds: const <String>{'user-pine'},
        isStarted: true,
        startedAt: t0.subtract(const Duration(minutes: 10)),
        locationMoveCount: 1,
        lastMovedNotice: 'Host moved "Courtyard Blitz Chess Club" to East Side Dining Commons. Expiration timer unchanged.',
      ),
    ]);

    _eventAlerts.add(
      const _StoredEventAlert(
        eventId: chessCodeId,
        hostId: 'user-pine',
        message: 'Host moved "Courtyard Blitz Chess Club" to East Side Dining Commons. Expiration timer unchanged.',
      ),
    );

    _messages.addAll(<_StoredChatMessage>[
      _StoredChatMessage(
        id: 'evt-msg-1',
        channelId: openJamId,
        senderId: 'user-hana',
        senderDisplayName: '@hana_k',
        isAnonymous: false,
        body: 'We are set up by the second terrace step!',
        createdAt: t0.subtract(const Duration(minutes: 25)),
        expiresAt: t0.add(const Duration(hours: 2, minutes: 30)),
        originPoint: presetLocations.first,
      ),
      _StoredChatMessage(
        id: 'evt-msg-2',
        channelId: studyGroupId,
        senderId: 'user-pine',
        senderDisplayName: 'PineOwl#109',
        isAnonymous: true,
        body: 'Grabbed the corner table with the power strip.',
        createdAt: t0.subtract(const Duration(minutes: 12)),
        expiresAt: t0.add(const Duration(hours: 3, minutes: 40)),
        originPoint: presetLocations[2],
      ),
    ]);

    _dmRequests.addAll(<DmRequest>[
      DmRequest(
        id: 'dm-1',
        fromUserId: 'user-hana',
        fromDisplayName: '@hana_k',
        fromIsAnonymous: false,
        toUserId: 'user-me',
        toDisplayName: _profile.publicDisplayName,
        introMessage: 'Hey! Saw your comment in nearby — do you play rhythm guitar or keys?',
        createdAt: t0.subtract(const Duration(minutes: 18)),
        status: DmRequestStatus.pending,
      ),
      DmRequest(
        id: 'dm-2',
        fromUserId: 'user-pine',
        fromDisplayName: '@pine_owl',
        fromIsAnonymous: false,
        toUserId: 'user-me',
        toDisplayName: _profile.publicDisplayName,
        introMessage: 'Sharing the SQL spatial index notes from the sprint.',
        createdAt: t0.subtract(const Duration(hours: 1)),
        status: DmRequestStatus.accepted,
        messages: <DirectMessage>[
          DirectMessage(
            id: 'dmsg-1',
            senderId: 'user-pine',
            senderDisplayName: '@pine_owl',
            body: 'Use ST_DWithin on geography(Point, 4326) with a GiST index!',
            createdAt: t0.subtract(const Duration(minutes: 50)),
          ),
        ],
      ),
    ]);
  }

  // --- Projections (Privacy Boundary) ---

  ChatMessage _projectMessage(_StoredChatMessage m) {
    return ChatMessage(
      id: m.id,
      channelId: m.channelId,
      senderId: m.senderId,
      senderDisplayName: m.senderDisplayName,
      isAnonymous: m.isAnonymous,
      body: m.body,
      createdAt: m.createdAt,
      expiresAt: m.expiresAt,
      areaName: m.originPoint.areaName,
      distanceLabel: _currentLocation.privacyDistanceLabelTo(m.originPoint),
      isSystemNotice: m.isSystemNotice,
      attachment: m.attachment,
    );
  }

  bool _isAuthorizedForStoredEvent(_StoredEvent event) {
    return event.hostId == _profile.id ||
        event.participantIds.contains(_profile.id);
  }

  ProximityEvent _projectEvent(_StoredEvent event) {
    final isHost = event.hostId == _profile.id;
    final isJoined = event.participantIds.contains(_profile.id);
    final isAuthorized = isHost || isJoined;
    final isRestricted = event.accessType != EventAccessType.public;
    final redactPrivateDetails = isRestricted && !isAuthorized;

    final visibleParticipants = event.participantIds
        .where((id) => !_blockedUserIds.contains(id))
        .length;

    final coarseVenuePoint = presetLocations
        .where((p) => p.areaName == event.location.areaName)
        .firstOrNull;

    return ProximityEvent(
      id: event.id,
      hostId: event.hostId,
      hostDisplayName: event.hostDisplayName,
      title: event.title,
      description: redactPrivateDetails
          ? (event.accessType == EventAccessType.joinCode
                ? redactedJoinCodeDescription
                : redactedInviteOnlyDescription)
          : event.description,
      categoryTag: event.categoryTag,
      areaName: event.location.areaName,
      distanceLabel: _currentLocation.privacyDistanceLabelTo(event.location),
      radiusMeters: event.radiusMeters,
      startsAt: event.startsAt,
      duration: event.duration,
      expiresAt: event.expiresAt,
      accessType: event.accessType,
      schedule: event.schedule,
      dateRangeLabel: event.schedule?.dateRangeLabel ?? 'Today',
      dailyHoursLabel:
          event.schedule?.dailyHoursLabel ??
          '${event.duration.inHours}h session',
      venuePoint: redactPrivateDetails
          ? (coarseVenuePoint ?? presetLocations.first)
          : event.location,
      isAuthorized: isAuthorized,
      isJoined: isJoined,
      isHost: isHost,
      participantCount: redactPrivateDetails ? null : visibleParticipants,
      isDetailsRedacted: redactPrivateDetails,
      isEnded: event.isEnded,
      locationMoveCount: event.locationMoveCount,
      lastMovedNotice: redactPrivateDetails ? null : event.lastMovedNotice,
      isStarted: event.isStarted,
      startedAt: event.startedAt,
      pendingHostTransferUserId: event.pendingHostTransferUserId,
      isPendingHostTransferForMe:
          event.pendingHostTransferUserId == _profile.id,
      posterBytes: event.posterBytes,
    );
  }

  // --- Location & Permissions ---

  String _resolveAreaName(double lat, double lon, {String? explicitAreaName}) {
    if (explicitAreaName != null && explicitAreaName.trim().isNotEmpty) {
      return explicitAreaName.trim();
    }
    final probe = GeoPoint(latitude: lat, longitude: lon, areaName: '');
    _StoredLandmark? closestLandmark;
    var minDist = double.infinity;
    for (final lm in _curatedLandmarks) {
      final d = probe.distanceMetersTo(lm.center);
      if (d < minDist) {
        minDist = d;
        closestLandmark = lm;
      }
    }
    if (closestLandmark != null && minDist <= 500) {
      return closestLandmark.areaName;
    }
    for (final preset in presetLocations) {
      if (probe.distanceMetersTo(preset) <= 600) {
        return preset.areaName;
      }
    }
    return 'Local Area';
  }

  void _purgeStagedUploadsForChannel(String channelId) {
    final toRemove = <String>[];
    for (final entry in _stagedUploads.entries) {
      if (entry.value.channelId == channelId) {
        final bytes = entry.value.sanitizedResult.sanitizedBytes;
        if (bytes != null) {
          bytes.fillRange(0, bytes.length, 0);
        }
        toRemove.add(entry.key);
      }
    }
    for (final id in toRemove) {
      _stagedUploads.remove(id);
    }
  }

  void _terminateLandmarkVisit(String landmarkId) {
    final removed = _activeLandmarkVisits.remove(landmarkId);
    _lastReadLandmarkAt.remove(landmarkId);
    _mediaCache.evictByChannel(landmarkId);
    _purgeStagedUploadsForChannel(landmarkId);
    if (removed != null) {
      _issuedDownloadTokens.removeWhere(
        (_, token) =>
            token.channelId == landmarkId ||
            token.visitSessionId == removed.sessionId,
      );
    }
  }

  void _terminateAllLandmarkVisits() {
    final ids = _activeLandmarkVisits.keys.toList();
    for (final id in ids) {
      _terminateLandmarkVisit(id);
    }
  }

  void _syncLandmarkVisitSessions(DateTime currentNow) {
    if (!hasFreshAccurateLocation) {
      _terminateAllLandmarkVisits();
      return;
    }

    for (final lm in _curatedLandmarks) {
      final dist = _currentLocation.distanceMetersTo(lm.center);
      if (dist <= lm.radiusMeters) {
        final existing = _activeLandmarkVisits[lm.id];
        final isStaleSession =
            existing != null &&
            _enforceFixFreshness &&
            currentNow.difference(existing.lastHeartbeatAt) > maxLocationAge;
        if (existing != null && !isStaleSession) {
          _activeLandmarkVisits[lm.id] = existing.copyWithHeartbeat(currentNow);
        } else if (!_profile.isGhostMode && canParticipateInNearby) {
          if (existing != null) {
            _terminateLandmarkVisit(lm.id);
          }
          _activeLandmarkVisits[lm.id] = _LandmarkVisitSession(
            sessionId: 'visit-${++_visitCounter}',
            landmarkId: lm.id,
            enteredAt: currentNow,
            lastHeartbeatAt: currentNow,
            minMessageSequence: _messageSeqCounter + 1,
          );
        } else if (existing != null) {
          _terminateLandmarkVisit(lm.id);
        }
      } else {
        if (_activeLandmarkVisits.containsKey(lm.id)) {
          _terminateLandmarkVisit(lm.id);
        }
      }
    }

    if (!_activeLandmarkVisits.containsKey(_selectedLandmarkId) &&
        _activeLandmarkVisits.isNotEmpty) {
      _selectedLandmarkId = _activeLandmarkVisits.keys.first;
    }
  }

  void _checkHostMovement(DateTime currentNow) {
    if (!hasFreshAccurateLocation) return;
    for (final event in _events) {
      if (event.hostId == _profile.id && event.isActiveAt(currentNow)) {
        final dist = _currentLocation.distanceMetersTo(event.location);
        if (dist > event.radiusMeters) {
          if (_pendingHostMovementEventId == null &&
              !_dismissedHostMovementEvents.contains(event.id)) {
            _pendingHostMovementEventId = event.id;
          }
        } else {
          _dismissedHostMovementEvents.remove(event.id);
          if (_pendingHostMovementEventId == event.id) {
            _pendingHostMovementEventId = null;
          }
        }
      }
    }
  }

  _LandmarkVisitSession? _activeValidVisitFor(
    String landmarkId,
    DateTime currentNow,
  ) {
    if (!hasFreshAccurateLocation) {
      _terminateAllLandmarkVisits();
      return null;
    }
    if (!canParticipateInNearby) {
      return null;
    }
    final session = _activeLandmarkVisits[landmarkId];
    if (session == null) return null;
    if (_enforceFixFreshness &&
        currentNow.difference(session.lastHeartbeatAt) > maxLocationAge) {
      _terminateLandmarkVisit(landmarkId);
      return null;
    }
    final landmark = _curatedLandmarks
        .where((l) => l.id == landmarkId)
        .firstOrNull;
    if (landmark == null) return null;
    if (_currentLocation.distanceMetersTo(landmark.center) >
        landmark.radiusMeters) {
      _terminateLandmarkVisit(landmarkId);
      return null;
    }
    return session;
  }

  void setPermissionState(LocationPermissionState state) {
    _permissionState = state;
    final currentNow = now;
    if (hasLocationAccess) {
      _latestLocationFix = LocationFix(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        accuracyMeters: _latestLocationFix?.accuracyMeters ?? 8.0,
        recordedAt: currentNow,
        areaName: _currentLocation.areaName,
      );
    }
    _syncLandmarkVisitSessions(currentNow);
    notifyListeners();
  }

  void setAppLifecycleActive(bool isActive) {
    _isAppLifecycleActive = isActive;
    if (!isActive) {
      _terminateAllLandmarkVisits();
    } else {
      _syncLandmarkVisitSessions(now);
    }
    notifyListeners();
  }

  /// Queries the configured `LocationService` (if attached) for permission and
  /// a live GPS fix, feeding it through `ingestLocationFix`.
  Future<bool> refreshFromLocationService() async {
    final svc = locationService;
    if (svc == null) return false;
    final perm = await svc.checkAndRequestPermission();
    setPermissionState(perm);
    if (perm != LocationPermissionState.granted &&
        perm != LocationPermissionState.simulated) {
      return false;
    }
    final fix = await svc.getCurrentFix();
    if (fix == null) return false;
    ingestLocationFix(fix);
    return hasFreshAccurateLocation;
  }

  /// Ingests a real or simulated GPS fix, enforcing freshness (<= 30s) and
  /// horizontal accuracy (<= 50m) before updating landmark visit sessions.
  void ingestLocationFix(LocationFix fix) {
    _enforceFixFreshness = true;
    _latestLocationFix = fix;
    final currentNow = now;
    final age = currentNow.difference(fix.recordedAt);
    final isValidFix =
        fix.accuracyMeters >= 0 &&
        fix.accuracyMeters <= maxGpsAccuracyMeters &&
        !age.isNegative &&
        age <= maxLocationAge;

    if (!isValidFix) {
      _terminateAllLandmarkVisits();
      notifyListeners();
      return;
    }

    final resolvedArea = _resolveAreaName(
      fix.latitude,
      fix.longitude,
      explicitAreaName: fix.areaName,
    );
    _currentLocation = GeoPoint(
      latitude: fix.latitude,
      longitude: fix.longitude,
      areaName: resolvedArea,
    );
    _syncLandmarkVisitSessions(currentNow);
    _checkHostMovement(currentNow);
    _checkForEventDiscoveryNotifications(currentNow);
    notifyListeners();
  }

  bool setSimulatedLocation(GeoPoint point) {
    final isSupportedPreset = presetLocations.any(
      (p) =>
          p.latitude == point.latitude &&
          p.longitude == point.longitude &&
          p.areaName == point.areaName,
    );
    if (!isSupportedPreset) return false;
    final currentNow = now;
    _currentLocation = point;
    _latestLocationFix = LocationFix(
      latitude: point.latitude,
      longitude: point.longitude,
      accuracyMeters: 8.0,
      recordedAt: currentNow,
      areaName: point.areaName,
    );
    if (_permissionState == LocationPermissionState.prompt ||
        _permissionState == LocationPermissionState.denied) {
      _permissionState = LocationPermissionState.simulated;
    }
    _syncLandmarkVisitSessions(currentNow);
    _checkHostMovement(currentNow);
    _checkForEventDiscoveryNotifications(currentNow);
    notifyListeners();
    return true;
  }

  bool setNearbyRadiusMeters(double meters) {
    if (!supportedNearbyRadiiMeters.contains(meters)) return false;
    _profile = _profile.copyWith(nearbyRadiusMeters: meters);
    notifyListeners();
    return true;
  }

  // --- Profile & Attendance Privacy ---

  PublicIdentityProjection publicProjectionForUser(String userId) {
    if (userId == _profile.id) {
      return PublicIdentityProjection.fromProfile(_profile);
    }
    final other = _otherParticipants
        .where((p) => p.userId == userId)
        .firstOrNull;
    if (other != null) {
      return PublicIdentityProjection(
        userId: other.userId,
        displayName: other.displayName,
        bio: other.isAnonymous ? "I'm anonymous." : '',
        avatarBytes: other.isAnonymous ? null : other.avatarBytes,
        isAnonymous: other.isAnonymous,
      );
    }
    final mock = _mockAccounts.values.where((u) => u.id == userId).firstOrNull;
    if (mock != null) {
      return PublicIdentityProjection.fromProfile(mock);
    }
    return PublicIdentityProjection(
      userId: userId,
      displayName: '@unknown',
      bio: '',
      isAnonymous: false,
    );
  }

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _handleStorage?['app_theme_mode'] = mode.name;
    notifyListeners();
  }

  // --- Notifications & Preferences ---
  final List<AppNotification> _notifications = <AppNotification>[];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  final Set<String> _notifiedEventIds = <String>{};

  String? _currentlyActiveChannelId;
  String? get currentlyActiveChannelId => _currentlyActiveChannelId;
  void setCurrentlyActiveChannelId(String? channelId) {
    _currentlyActiveChannelId = channelId;
  }

  void setNotifyNearbyEvents(bool enabled) {
    _profile = _profile.copyWith(notifyNearbyEvents: enabled);
    notifyListeners();
  }

  void setNotifyNearbyChat(bool enabled) {
    _profile = _profile.copyWith(notifyNearbyChat: enabled);
    notifyListeners();
  }

  void setNotifyJoinedEventChat(bool enabled) {
    _profile = _profile.copyWith(notifyJoinedEventChat: enabled);
    notifyListeners();
  }

  void markNotificationAsRead(String notificationId) {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  void _checkForEventDiscoveryNotifications(DateTime currentNow) {
    if (!_profile.notifyNearbyEvents) return;
    for (final event in _events) {
      if (event.hostId == _profile.id) continue;
      if (event.isEnded || event.schedule?.isCancelled == true) continue;
      if (!event.isAvailableForDiscoveryAt(currentNow)) continue;
      if (_notifiedEventIds.contains(event.id)) continue;

      final dist = _currentLocation.distanceMetersTo(event.location);
      if (dist <= _profile.nearbyRadiusMeters || dist <= event.radiusMeters) {
        _notifiedEventIds.add(event.id);
        _notifications.insert(
          0,
          AppNotification(
            id: 'notif-${currentNow.microsecondsSinceEpoch}-${event.id}',
            title: 'Nearby Event Discovered',
            body:
                '${event.title} is now active nearby in ${event.location.areaName}.',
            createdAt: currentNow,
            targetEventId: event.id,
          ),
        );
      }
    }
  }

  void _deliverChatMessageNotification({
    required String channelId,
    required String senderId,
    required String senderName,
    required String messageText,
    required bool isEvent,
    required DateTime currentNow,
  }) {
    if (senderId == _profile.id) return;
    if (_currentlyActiveChannelId == channelId) return;

    if (isEvent) {
      if (!_profile.notifyJoinedEventChat) return;
      final event = _events.where((e) => e.id == channelId).firstOrNull;
      if (event == null || !event.participantIds.contains(_profile.id)) return;

      _notifications.insert(
        0,
        AppNotification(
          id: 'notif-${currentNow.microsecondsSinceEpoch}',
          title: event.title,
          body: '$senderName: $messageText',
          createdAt: currentNow,
          targetEventId: event.id,
        ),
      );
      notifyListeners();
    } else {
      if (_profile.isGhostMode) return;
      if (!_profile.notifyNearbyChat) return;
      if (!canParticipateInNearby) return;

      final lm = _curatedLandmarks.where((l) => l.id == channelId).firstOrNull;
      final landmarkName = lm?.name ?? 'Nearby Chat';

      _notifications.insert(
        0,
        AppNotification(
          id: 'notif-${currentNow.microsecondsSinceEpoch}',
          title: landmarkName,
          body: '$senderName: $messageText',
          createdAt: currentNow,
          targetLandmarkId: channelId,
        ),
      );
      notifyListeners();
    }
  }

  /// Ingests an incoming chat message (e.g. from peer, simulator, or network).
  void receiveIncomingMessage({
    required String channelId,
    required String senderId,
    required String senderDisplayName,
    required String body,
    bool isAnonymous = false,
    bool isEvent = false,
  }) {
    final currentNow = now;
    final seq = ++_messageSeqCounter;
    final newMsg = _StoredChatMessage(
      id: 'in-${currentNow.microsecondsSinceEpoch}',
      channelId: channelId,
      senderId: senderId,
      senderDisplayName: senderDisplayName,
      isAnonymous: isAnonymous,
      body: body,
      createdAt: currentNow,
      expiresAt: currentNow.add(
        Duration(hours: _profile.messageRetentionHours),
      ),
      originPoint: _currentLocation,
      sequence: seq,
    );
    _messages.add(newMsg);
    _deliverChatMessageNotification(
      channelId: channelId,
      senderId: senderId,
      senderName: senderDisplayName,
      messageText: body,
      isEvent: isEvent,
      currentNow: currentNow,
    );
    notifyListeners();
  }

  // --- Navigation & Deep Links ---
  int? _requestedTabIndex;
  int? get requestedTabIndex => _requestedTabIndex;
  int? consumeRequestedTabIndex() {
    final idx = _requestedTabIndex;
    _requestedTabIndex = null;
    return idx;
  }

  bool _requestedNearbyIsEvent = false;
  bool get requestedNearbyIsEvent => _requestedNearbyIsEvent;

  String? _requestedNearbyTargetId;
  String? get requestedNearbyTargetId => _requestedNearbyTargetId;

  void navigateToNearbyLandmark(String landmarkId) {
    selectLandmark(landmarkId);
    _requestedNearbyIsEvent = false;
    _requestedNearbyTargetId = landmarkId;
    _requestedTabIndex = 0;
    notifyListeners();
  }

  void navigateToNearbyEvent(String eventId) {
    _requestedNearbyIsEvent = true;
    _requestedNearbyTargetId = eventId;
    _requestedTabIndex = 0;
    notifyListeners();
  }

  String? _pendingDeepLinkEventId;
  String? get pendingDeepLinkEventId => _pendingDeepLinkEventId;
  void clearPendingDeepLinkEvent() {
    _pendingDeepLinkEventId = null;
    notifyListeners();
  }

  bool handleDeepLink(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      if (uri.scheme == 'proximity' && uri.host == 'event') {
        final segments = uri.pathSegments;
        final eventId = segments.isNotEmpty ? segments.first : null;
        if (eventId != null && eventId.isNotEmpty) {
          _pendingDeepLinkEventId = eventId;
          _requestedTabIndex = 1; // Explore tab
          notifyListeners();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static const String demo2FACode = '123456';

  String? updateEmailDemo(String newEmail, String verificationCode) {
    final cleanEmail = newEmail.trim();
    if (!RegExp(r'^.+@.+\..+$').hasMatch(cleanEmail)) {
      return 'Please enter a valid email address.';
    }
    if (verificationCode.trim() != demo2FACode) {
      return 'Invalid 2FA code. For demo purposes, enter 123456.';
    }
    notifyListeners();
    return null;
  }

  String? updatePasswordDemo(String newPassword, String verificationCode) {
    if (newPassword.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (verificationCode.trim() != demo2FACode) {
      return 'Invalid 2FA code. For demo purposes, enter 123456.';
    }
    notifyListeners();
    return null;
  }

  void updateRealProfile({
    String? username,
    String? bio,
    Uint8List? avatarBytes,
    bool clearAvatar = false,
  }) {
    _profile = _profile.copyWith(
      username: username,
      bio: bio,
      avatarBytes: avatarBytes,
      clearAvatar: clearAvatar,
    );
    if (username != null && username.trim().isNotEmpty) {
      _mockAccounts[username.trim().toLowerCase()] = _profile;
    }
    notifyListeners();
  }

  Future<bool> restoreSavedSession() async {
    final client = apiClient;
    if (client != null) {
      final savedRefreshToken = await sessionStore.getRefreshToken();
      final savedAccessToken = await sessionStore.getAccessToken();
      if (savedRefreshToken != null || savedAccessToken != null) {
        client.setTokens(accessToken: savedAccessToken, refreshToken: savedRefreshToken);
        try {
          final me = await client.getMe();
          _profile = UserProfile(
            id: me.id,
            username: me.username,
            anonymousHandle: me.anonymousHandle,
            identityMode: me.identityMode == 'anonymous' ? IdentityMode.anonymous : IdentityMode.real,
            visibleInNearby: me.visibleInNearby,
            ghostBrowseNearby: me.ghostBrowseNearby,
            isGhostMode: me.isGhostMode,
            nearbyRadiusMeters: me.nearbyRadiusMeters,
            messageRetentionHours: me.messageRetentionHours,
            bio: me.bio,
          );
          _isAuthenticated = true;
          await syncFromBackend();
          notifyListeners();
          return true;
        } catch (_) {
          client.clearTokens();
          await sessionStore.clearTokens();
        }
      }
    }

    final username = await sessionStore.getSavedSessionUsername();
    if (username != null && username.isNotEmpty) {
      final clean = username.trim().toLowerCase();
      if (_mockAccounts.containsKey(clean)) {
        _profile = _mockAccounts[clean]!;
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
    }
    _isAuthenticated = false;
    notifyListeners();
    return false;
  }

  /// Asynchronous login supporting real FastAPI Cloud backend with demo fallback.
  Future<String?> loginAsync({
    required String username,
    required String password,
  }) async {
    final client = apiClient;
    if (client != null) {
      try {
        final tokens = await client.login(username: username, password: password);
        await sessionStore.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        final me = await client.getMe();
        _profile = UserProfile(
          id: me.id,
          username: me.username,
          anonymousHandle: me.anonymousHandle,
          identityMode: me.identityMode == 'anonymous' ? IdentityMode.anonymous : IdentityMode.real,
          visibleInNearby: me.visibleInNearby,
          ghostBrowseNearby: me.ghostBrowseNearby,
          isGhostMode: me.isGhostMode,
          nearbyRadiusMeters: me.nearbyRadiusMeters,
          messageRetentionHours: me.messageRetentionHours,
          bio: me.bio,
        );
        _isAuthenticated = true;
        await sessionStore.saveSessionUsername(me.username);
        await syncFromBackend();
        notifyListeners();
        return null;
      } on ApiException catch (e) {
        return e.message;
      } catch (e) {
        return 'Connection error: unable to reach Proximity API';
      }
    }
    return login(username);
  }

  /// Asynchronous registration supporting real FastAPI Cloud backend with demo fallback.
  Future<String?> registerAsync({
    required String username,
    required String email,
    required String password,
  }) async {
    final client = apiClient;
    if (client != null) {
      try {
        final tokens = await client.register(
          username: username,
          email: email,
          password: password,
        );
        await sessionStore.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        final me = await client.getMe();
        _profile = UserProfile(
          id: me.id,
          username: me.username,
          anonymousHandle: me.anonymousHandle,
          identityMode: me.identityMode == 'anonymous' ? IdentityMode.anonymous : IdentityMode.real,
          visibleInNearby: me.visibleInNearby,
          ghostBrowseNearby: me.ghostBrowseNearby,
          isGhostMode: me.isGhostMode,
          nearbyRadiusMeters: me.nearbyRadiusMeters,
          messageRetentionHours: me.messageRetentionHours,
          bio: me.bio,
        );
        _isAuthenticated = true;
        await sessionStore.saveSessionUsername(me.username);
        if (shouldShowOnboardingFor(me.id)) {
          _isOnboardingActive = true;
        }
        await syncFromBackend();
        notifyListeners();
        return null;
      } on ApiException catch (e) {
        return e.message;
      } catch (e) {
        return 'Connection error: unable to reach Proximity API';
      }
    }
    return register(username: username, email: email, password: password);
  }

  /// Synchronizes live landmarks, nearby participants, and events from the backend.
  Future<void> syncFromBackend() async {
    final client = apiClient;
    if (client == null || !client.isAuthenticated) return;
    try {
      final fix = latestLocationFix;
      final lmList = await client.getLandmarks(
        latitude: fix?.latitude ?? _currentLocation.latitude,
        longitude: fix?.longitude ?? _currentLocation.longitude,
      );
      if (lmList.isNotEmpty) {
        _curatedLandmarks.clear();
        for (final l in lmList) {
          LandmarkCategory cat = LandmarkCategory.pointOfInterest;
          for (final c in LandmarkCategory.values) {
            if (c.name.toLowerCase() == l.category.toLowerCase()) {
              cat = c;
              break;
            }
          }
          _curatedLandmarks.add(
            _StoredLandmark(
              id: l.id,
              name: l.name,
              areaName: l.areaName,
              center: GeoPoint(latitude: l.latitude, longitude: l.longitude, areaName: l.areaName),
              radiusMeters: l.radiusMeters,
              category: cat,
            ),
          );
        }
      }

      if (fix != null) {
        final nearby = await client.discoverNearby(
          LocationFixRequest(
            latitude: fix.latitude,
            longitude: fix.longitude,
            accuracyMeters: fix.accuracyMeters,
            recordedAt: fix.recordedAt,
            areaName: fix.areaName,
          ),
        );
        if (nearby.isNotEmpty) {
          _otherParticipants.clear();
          for (final p in nearby) {
            if (p.userId != _profile.id && !p.displayName.contains('(You)')) {
              _otherParticipants.add(
                _StoredNearbyParticipant(
                  userId: p.userId,
                  displayName: p.displayName,
                  isAnonymous: p.isAnonymous,
                  location: _currentLocation,
                  visibleInNearby: p.visibleInNearby,
                ),
              );
            }
          }
        }
      }
    } catch (_) {
      // Gracefully handle background sync errors
    }
  }

  /// Demonstration login. Checks mock registry case-insensitively.
  /// Passwords are never checked or stored.
  String? login(String username) {
    final clean = username.trim().toLowerCase();
    if (_mockAccounts.containsKey(clean)) {
      _profile = _mockAccounts[clean]!;
      _isAuthenticated = true;
      sessionStore.saveSessionUsername(_profile.username);
      notifyListeners();
      return null;
    }
    return 'Demonstration mode: user "$username" not found. Enter "Alex" or register a new account.';
  }

  /// Demonstration registration. Creates in-memory mock account with collision-resistant ID.
  /// Validates format, clears password immediately; passwords are never persisted.
  String? register({
    required String username,
    required String email,
    required String password,
  }) {
    final cleanUsername = username.trim();
    if (cleanUsername.length < 3 || cleanUsername.length > 20) {
      return 'Username must be 3-20 characters long.';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername)) {
      return 'Username must contain only letters, numbers, and underscores.';
    }
    if (_mockAccounts.containsKey(cleanUsername.toLowerCase())) {
      return 'Username is already taken.';
    }
    final cleanEmail = email.trim();
    if (!RegExp(r'^.+@.+\..+$').hasMatch(cleanEmail)) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }

    final newUserId = 'user-${now.microsecondsSinceEpoch}-${++_userCounter}';
    final takenHandles = _otherParticipants
        .where((p) => p.isAnonymous)
        .map((p) => p.displayName)
        .toSet();
    takenHandles.add(_profile.anonymousHandle);
    final anonHandle = AnonymousNameGenerator.generate(
      existingHandles: takenHandles,
      seed: now.microsecondsSinceEpoch % 10000,
    );
    final newProfile = UserProfile(
      id: newUserId,
      anonymousHandle: anonHandle,
      username: cleanUsername,
      identityMode: IdentityMode.real,
      visibleInNearby: true,
      ghostBrowseNearby: false,
      nearbyRadiusMeters: 500,
      messageRetentionHours: 24,
    );

    _mockAccounts[cleanUsername.toLowerCase()] = newProfile;
    _profile = newProfile;
    _isAuthenticated = true;
    sessionStore.saveSessionUsername(cleanUsername);
    if (shouldShowOnboardingFor(newUserId)) {
      _isOnboardingActive = true;
    }
    notifyListeners();
    return null;
  }

  /// Logs out of the current session.
  void logout() {
    _isAuthenticated = false;
    apiClient?.logout();
    sessionStore.clearSession();
    notifyListeners();
  }

  /// Anonymous handles are system-assigned and immutable; manual switching is disabled.
  bool setIdentityMode(IdentityMode mode) {
    return false;
  }

  /// Whether the user owns or handles any event that has not ended or been cancelled.
  bool get isHostingActiveEvent {
    return _events.any(
      (e) =>
          e.hostId == _profile.id &&
          !e.isEnded &&
          e.schedule?.isCancelled != true,
    );
  }

  /// Toggles or sets anonymous mode.
  /// Transition from OFF -> ON generates a fresh random anonymous handle.
  /// A user hosting an active event cannot enable Anonymous Mode.
  bool setAnonymousMode(bool enabled) {
    if (enabled && isHostingActiveEvent) return false;
    if (_profile.isAnonymous == enabled) return false;
    if (enabled) {
      final takenHandles = _otherParticipants
          .where((p) => p.isAnonymous)
          .map((p) => p.displayName)
          .toSet();
      takenHandles.add(_profile.anonymousHandle);
      final newHandle = AnonymousNameGenerator.generate(
        existingHandles: takenHandles,
        seed: now.microsecondsSinceEpoch % 10000,
      );
      _profile = _profile.copyWith(
        identityMode: IdentityMode.anonymous,
        anonymousHandle: newHandle,
      );
    } else {
      _profile = _profile.copyWith(identityMode: IdentityMode.username);
    }
    notifyListeners();
    return true;
  }

  bool toggleAnonymousMode() => setAnonymousMode(!_profile.isAnonymous);

  /// Anonymous handles are system-assigned and immutable; manual editing is disabled.
  bool updateProfileHandles({String? anonymousHandle, String? username}) {
    return false;
  }

  void _evictLandmarkMediaIfNearbyPaused() {
    if (!canParticipateInNearby) {
      for (final lm in _curatedLandmarks) {
        _mediaCache.evictByChannel(lm.id);
        _purgeStagedUploadsForChannel(lm.id);
        _issuedDownloadTokens.removeWhere((_, t) => t.channelId == lm.id);
      }
    }
  }

  /// Coherent Ghost Mode toggle: when enabled, nearby proximity chats remain unavailable
  /// regardless of location, while joined event chats remain available. Disabling Ghost Mode
  /// does not restore an expired visit without fresh eligibility checks.
  void setGhostMode(bool enabled) {
    if (_profile.isGhostMode == enabled) return;
    final currentNow = now;
    if (enabled) {
      _profile = _profile.copyWith(
        isGhostMode: true,
        visibleInNearby: false,
        ghostBrowseNearby: false,
      );
      _evictLandmarkMediaIfNearbyPaused();
    } else {
      _profile = _profile.copyWith(
        isGhostMode: false,
        visibleInNearby: false,
        ghostBrowseNearby: true,
      );
      if (hasFreshAccurateLocation) {
        _syncLandmarkVisitSessions(currentNow);
      } else {
        _terminateAllLandmarkVisits();
      }
    }
    notifyListeners();
  }

  void toggleGhostMode() => setGhostMode(!_profile.isGhostMode);

  void setVisibleInNearby(bool visible) {
    _profile = _profile.copyWith(
      visibleInNearby: visible,
      isGhostMode: !visible && !_profile.ghostBrowseNearby,
    );
    _evictLandmarkMediaIfNearbyPaused();
    notifyListeners();
  }

  void setGhostBrowseNearby(bool ghostBrowse) {
    _profile = _profile.copyWith(
      ghostBrowseNearby: ghostBrowse,
      isGhostMode: !_profile.visibleInNearby && !ghostBrowse,
    );
    _evictLandmarkMediaIfNearbyPaused();
    notifyListeners();
  }

  void setMessageRetentionHours(int hours) {
    _profile = _profile.copyWith(messageRetentionHours: hours);
    notifyListeners();
  }

  // --- Strict Location-Bound Landmark Chats & Nearby Discovery ---

  LandmarkChat _projectLandmark(
    _StoredLandmark lm,
    _LandmarkVisitSession visit,
    DateTime currentNow,
  ) {
    final distMeters = _currentLocation.distanceMetersTo(lm.center);
    final roundedMeters = distMeters.round();
    final currentVisitMessages = _rawLandmarkMessagesForVisit(
      lm.id,
      visit,
      currentNow,
    );
    final lastRead = _lastReadLandmarkAt[lm.id];
    final unread = currentVisitMessages
        .where(
          (m) =>
              m.senderId != _profile.id &&
              (lastRead == null || m.createdAt.isAfter(lastRead)),
        )
        .length;

    return LandmarkChat(
      id: lm.id,
      name: lm.name,
      areaName: lm.areaName,
      center: lm.center,
      radiusMeters: lm.radiusMeters,
      distanceMeters: distMeters,
      distanceLabel: _currentLocation.privacyDistanceLabelTo(lm.center),
      headerDistanceLabel: '${lm.name} · $roundedMeters m away',
      visitSessionId: visit.sessionId,
      visitEnteredAt: visit.enteredAt,
      activeMessageCount: currentVisitMessages.length,
      unreadCount: unread,
    );
  }

  List<_StoredChatMessage> _rawLandmarkMessagesForVisit(
    String landmarkId,
    _LandmarkVisitSession visit,
    DateTime currentNow,
  ) {
    return _messages.where((m) {
      if (m.channelId != landmarkId) return false;
      if (m.isExpiredAt(currentNow)) return false;
      if (_blockedUserIds.contains(m.senderId)) return false;
      // Strict current-visit-only window: never reveal messages from before entry or prior visits!
      if (m.createdAt.isBefore(visit.enteredAt)) return false;
      if (m.sequence < visit.minMessageSequence) return false;
      return true;
    }).toList();
  }

  /// Returns all discoverable landmarks projected with category, parent, and distance.
  List<LandmarkDiscovery> get discoverableLandmarks {
    final hasFresh = hasFreshAccurateLocation;
    return _curatedLandmarks.map((lm) {
      final dist = _currentLocation.distanceMetersTo(lm.center);
      final isInside = hasFresh && dist <= lm.radiusMeters;
      return LandmarkDiscovery(
        id: lm.id,
        name: lm.name,
        areaName: lm.areaName,
        center: lm.center,
        radiusMeters: lm.radiusMeters,
        distanceMeters: dist,
        distanceLabel: _currentLocation.privacyDistanceLabelTo(lm.center),
        isUserInside: isInside,
        category: lm.category,
        parentLandmarkId: lm.parentLandmarkId,
      );
    }).toList();
  }

  /// Returns only landmarks where the user is currently inside the permitted
  /// radius with a valid, fresh, accurate location fix.
  List<LandmarkChat> get activeLandmarkChats {
    final currentNow = now;
    if (!hasFreshAccurateLocation) {
      _terminateAllLandmarkVisits();
      return const <LandmarkChat>[];
    }
    if (!canParticipateInNearby) {
      return const <LandmarkChat>[];
    }
    final result = <LandmarkChat>[];
    for (final lm in _curatedLandmarks) {
      final visit = _activeValidVisitFor(lm.id, currentNow);
      if (visit != null) {
        result.add(_projectLandmark(lm, visit, currentNow));
      }
    }
    return result;
  }

  LandmarkChat? landmarkById(String landmarkId) {
    final currentNow = now;
    final visit = _activeValidVisitFor(landmarkId, currentNow);
    if (visit == null) return null;
    final lm = _curatedLandmarks.where((l) => l.id == landmarkId).firstOrNull;
    if (lm == null) return null;
    return _projectLandmark(lm, visit, currentNow);
  }

  bool selectLandmark(String landmarkId) {
    if (!canParticipateInNearby ||
        _activeValidVisitFor(landmarkId, now) == null) {
      return false;
    }
    _selectedLandmarkId = landmarkId;
    _lastReadLandmarkAt[landmarkId] = now;
    notifyListeners();
    return true;
  }

  /// Returns current-visit-only messages for `landmarkId`.
  /// Returns empty if outside the landmark radius, without fresh/accurate GPS,
  /// or when nearby participation is disabled.
  List<ChatMessage> landmarkMessagesFor(String landmarkId) {
    if (!canParticipateInNearby) return const <ChatMessage>[];
    final currentNow = now;
    final visit = _activeValidVisitFor(landmarkId, currentNow);
    if (visit == null) return const <ChatMessage>[];
    return _rawLandmarkMessagesForVisit(
      landmarkId,
      visit,
      currentNow,
    ).map(_projectMessage).toList();
  }

  int landmarkUnreadCountFor(String landmarkId) {
    if (!canParticipateInNearby) return 0;
    final chat = landmarkById(landmarkId);
    return chat?.unreadCount ?? 0;
  }

  List<ChatMessage> searchLandmarkMessages(String query, {String? landmarkId}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || !canParticipateInNearby) return const <ChatMessage>[];
    final targetIds = landmarkId != null
        ? <String>[landmarkId]
        : activeLandmarkChats.map((c) => c.id).toList();
    final matches = <ChatMessage>[];
    for (final id in targetIds) {
      for (final msg in landmarkMessagesFor(id)) {
        if (msg.body.toLowerCase().contains(q)) {
          matches.add(msg);
        }
      }
    }
    return matches;
  }

  bool sendLandmarkMessage(
    String landmarkId,
    String rawText, {
    Uint8List? rawImageBytes,
    String? stagedUploadId,
  }) {
    final body = rawText.trim();
    if (!canParticipateInNearby) return false;
    final currentNow = now;
    final visit = _activeValidVisitFor(landmarkId, currentNow);
    if (visit == null) return false;
    final lm = _curatedLandmarks.where((l) => l.id == landmarkId).firstOrNull;
    if (lm == null) return false;

    final seq = _messageSeqCounter + 1;
    ChatImageAttachment? attachment;
    if (rawImageBytes != null || stagedUploadId != null) {
      attachment = _commitPrivateMediaAttachment(
        channelKind: _MediaChannelKind.landmark,
        channelId: landmarkId,
        createdAt: currentNow,
        expiresAt: currentNow.add(
          Duration(hours: _profile.messageRetentionHours),
        ),
        sequence: seq,
        rawImageBytes: rawImageBytes,
        stagedUploadId: stagedUploadId,
      );
      if (attachment == null) return false;
    }

    if (body.isEmpty && attachment == null) return false;
    _messageSeqCounter = seq;

    _messages.add(
      _StoredChatMessage(
        id: 'msg-${currentNow.microsecondsSinceEpoch}',
        channelId: landmarkId,
        senderId: _profile.id,
        senderDisplayName: _profile.activeDisplayName,
        isAnonymous: _profile.isAnonymous,
        body: body,
        createdAt: currentNow,
        expiresAt: currentNow.add(
          Duration(hours: _profile.messageRetentionHours),
        ),
        originPoint: lm.center,
        sequence: seq,
        attachment: attachment,
      ),
    );
    _lastReadLandmarkAt[landmarkId] = currentNow;
    notifyListeners();
    return true;
  }

  /// Coarse reference point snapped to the nearest preset area center to
  /// prevent trilateration of participant positions via arbitrary GPS fixes.
  GeoPoint get _coarseParticipantReferencePoint {
    GeoPoint closest = presetLocations.first;
    var minDist = double.infinity;
    for (final p in presetLocations) {
      final d = _currentLocation.distanceMetersTo(p);
      if (d < minDist) {
        minDist = d;
        closest = p;
      }
    }
    return closest;
  }

  /// Enforces visibility server-equivalent rule: only users who opted into
  /// `visibleInNearby` within the configured radius are returned, with coarse
  /// distance labels instead of raw coordinates.
  List<NearbyParticipant> get visibleNearbyParticipants {
    if (!hasFreshAccurateLocation) return const <NearbyParticipant>[];
    final refPoint = _coarseParticipantReferencePoint;
    final list = <NearbyParticipant>[];
    if (_profile.visibleInNearby) {
      list.add(
        NearbyParticipant(
          userId: _profile.id,
          displayName: '${_profile.activeDisplayName} (You)',
          isAnonymous: _profile.isAnonymous,
          areaName: _currentLocation.areaName,
          distanceLabel: '< 100m away',
          visibleInNearby: true,
        ),
      );
    }
    for (final p in _otherParticipants) {
      if (!p.visibleInNearby) continue;
      if (_blockedUserIds.contains(p.userId)) continue;
      final dist = refPoint.distanceMetersTo(p.location);
      if (dist <= _profile.nearbyRadiusMeters) {
        list.add(
          NearbyParticipant(
            userId: p.userId,
            displayName: p.displayName,
            isAnonymous: p.isAnonymous,
            areaName: p.location.areaName,
            distanceLabel: refPoint.privacyDistanceLabelTo(p.location),
            visibleInNearby: p.visibleInNearby,
          ),
        );
      }
    }
    return list;
  }

  /// Returns current-visit messages for the active selected Landmark Chat.
  List<ChatMessage> get nearbyMessages {
    if (!canParticipateInNearby) return const <ChatMessage>[];
    final active = activeLandmarkChats;
    if (active.isEmpty) return const <ChatMessage>[];
    final targetId = active.any((c) => c.id == _selectedLandmarkId)
        ? _selectedLandmarkId
        : active.first.id;
    return landmarkMessagesFor(targetId);
  }

  /// Sends a message to the active selected Landmark Chat only when inside
  /// its radius with fresh/accurate location and nearby participation enabled.
  bool sendNearbyMessage(String rawText) {
    if (!canParticipateInNearby) return false;
    final active = activeLandmarkChats;
    if (active.isEmpty) return false;
    final targetId = active.any((c) => c.id == _selectedLandmarkId)
        ? _selectedLandmarkId
        : active.first.id;
    return sendLandmarkMessage(targetId, rawText);
  }

  // --- Events, Access Control & Movement ---

  _StoredEvent? _storedEventById(String eventId) {
    final currentNow = now;
    for (final e in _events) {
      if (e.id == eventId && e.isAvailableForDiscoveryAt(currentNow)) return e;
    }
    return null;
  }

  bool _isWithinEventDiscoveryRadius(_StoredEvent event) {
    final dist = _currentLocation.distanceMetersTo(event.location);
    final maxRadius = event.radiusMeters > _profile.nearbyRadiusMeters
        ? event.radiusMeters
        : _profile.nearbyRadiusMeters;
    return dist <= maxRadius;
  }

  bool _isEligibleForEventDiscovery(_StoredEvent event) {
    if (!hasFreshAccurateLocation) return false;
    if (!event.isAvailableForDiscoveryAt(now)) return false;
    if (_blockedUserIds.contains(event.hostId)) return false;
    if (_isAuthorizedForStoredEvent(event)) return true;
    return _isWithinEventDiscoveryRadius(event);
  }

  /// Returns active (non-expired, non-ended) events whose discovery radius or
  /// user's nearby radius covers the current distance, plus joined events.
  /// Unjoined restricted events have private descriptions and attendance redacted.
  List<ProximityEvent> get discoverableEvents {
    if (!hasFreshAccurateLocation) return const <ProximityEvent>[];
    return _events
        .where(_isEligibleForEventDiscovery)
        .map(_projectEvent)
        .toList();
  }

  /// Joined events within discoverable radius for the current user.
  List<ProximityEvent> get joinedEvents {
    if (!hasFreshAccurateLocation) return const <ProximityEvent>[];
    return discoverableEvents.where((e) => e.isJoined).toList();
  }

  /// Calendar query: returns eligible events occurring on `localDate`, enforcing
  /// the same visibility, membership, blocking, and redaction rules as map queries.
  List<ProximityEvent> eventsForLocalDate(DateTime localDate) {
    if (!hasFreshAccurateLocation) return const <ProximityEvent>[];
    return _events
        .where(
          (e) =>
              _isEligibleForEventDiscovery(e) && e.occursOnLocalDate(localDate),
        )
        .map(_projectEvent)
        .toList();
  }

  ProximityEvent? eventById(String eventId) {
    final stored = _storedEventById(eventId);
    if (stored == null || !_isEligibleForEventDiscovery(stored)) return null;
    return _projectEvent(stored);
  }

  bool isAuthorizedForEvent(String eventId) {
    if (!hasFreshAccurateLocation) return false;
    final stored = _storedEventById(eventId);
    if (stored == null || _blockedUserIds.contains(stored.hostId)) return false;
    return _isAuthorizedForStoredEvent(stored);
  }

  /// Returns joined participant IDs for authorized participants/hosts, filtering blocked users.
  List<String> eventParticipantIds(String eventId) {
    if (!isAuthorizedForEvent(eventId)) return const <String>[];
    final stored = _storedEventById(eventId);
    if (stored == null) return const <String>[];
    return stored.participantIds
        .where((id) => !_blockedUserIds.contains(id))
        .toList();
  }

  /// Verifies an event's join code without exposing the stored hash on `ProximityEvent`.
  bool verifyEventJoinCode(String eventId, String candidate) {
    final stored = _storedEventById(eventId);
    if (stored == null || !_isEligibleForEventDiscovery(stored)) return false;
    if (stored.accessType != EventAccessType.joinCode) return false;
    final attempts = _failedJoinCodeAttempts[eventId] ?? 0;
    if (attempts >= maxJoinCodeAttempts) return false;
    final ok = stored.verifyJoinCode(candidate);
    if (!ok) {
      _failedJoinCodeAttempts[eventId] = attempts + 1;
    } else {
      _failedJoinCodeAttempts.remove(eventId);
    }
    return ok;
  }

  /// Joins an event if access rules pass.
  /// Attendance privacy rule: joining an event NEVER exposes the user in general nearby discovery.
  String? joinEvent(String eventId, {String? joinCode}) {
    if (!hasFreshAccurateLocation) {
      return 'Fresh, accurate location permission required.';
    }
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return 'Event not found.';
    final event = _events[idx];
    if (!event.isActiveAt(now)) return 'This event has expired or ended.';
    if (_blockedUserIds.contains(event.hostId)) return 'Host is blocked.';
    if (!_isAuthorizedForStoredEvent(event) &&
        !_isWithinEventDiscoveryRadius(event)) {
      return 'Event is outside your discovery area.';
    }

    switch (event.accessType) {
      case EventAccessType.public:
        break;
      case EventAccessType.joinCode:
        final attempts = _failedJoinCodeAttempts[eventId] ?? 0;
        if (attempts >= maxJoinCodeAttempts) {
          return 'Too many failed join code attempts.';
        }
        if (joinCode == null || !event.verifyJoinCode(joinCode)) {
          _failedJoinCodeAttempts[eventId] = attempts + 1;
          return 'Invalid join code.';
        }
        _failedJoinCodeAttempts.remove(eventId);
      case EventAccessType.inviteOnly:
        if (!event.invitedUserIds.contains(_profile.id) &&
            event.hostId != _profile.id) {
          return 'This event is invite-only.';
        }
    }

    final updatedParticipants = <String>{...event.participantIds, _profile.id};
    _events[idx] = event.copyWithDetails(participantIds: updatedParticipants);
    notifyListeners();
    return null;
  }

  String? leaveEvent(String eventId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return 'Event not found.';
    final event = _events[idx];
    if (event.hostId == _profile.id && !event.isEnded) {
      return 'As the host, you must either transfer ownership or end the event before leaving.';
    }
    final updated = Set<String>.from(event.participantIds)..remove(_profile.id);
    _events[idx] = event.copyWithDetails(participantIds: updated);
    _mediaCache.evictByChannel(eventId);
    _purgeStagedUploadsForChannel(eventId);
    _issuedDownloadTokens.removeWhere((_, t) => t.channelId == eventId);
    notifyListeners();
    return null;
  }

  ProximityEvent createEvent({
    required String title,
    required String description,
    required String categoryTag,
    required GeoPoint location,
    required double radiusMeters,
    required Duration duration,
    required EventAccessType accessType,
    String? rawJoinCode,
    EventSchedule? schedule,
    Uint8List? posterBytes,
  }) {
    final currentNow = now;
    final id = 'evt-${currentNow.microsecondsSinceEpoch}';
    final codeHash =
        accessType == EventAccessType.joinCode &&
            rawJoinCode != null &&
            rawJoinCode.trim().isNotEmpty
        ? hashSecretCode(rawJoinCode, salt: id)
        : null;

    if (schedule != null) {
      final scheduleErr = schedule.validateScheduleAgainst(now: currentNow);
      if (scheduleErr != null) {
        throw ArgumentError(scheduleErr);
      }
    }

    final validSchedule = schedule != null && schedule.isValid
        ? schedule
        : null;
    final effectiveStartsAt = validSchedule?.startsAtInstant ?? currentNow;
    final effectiveExpiresAt =
        validSchedule?.expiresAtInstant ?? currentNow.add(duration);
    final effectiveDuration = effectiveExpiresAt.difference(effectiveStartsAt);

    final created = _StoredEvent(
      id: id,
      hostId: _profile.id,
      hostDisplayName: _profile.publicDisplayName,
      title: title.trim(),
      description: description.trim(),
      categoryTag: categoryTag.trim().isEmpty ? 'Local Hangout' : categoryTag,
      location: location,
      radiusMeters: radiusMeters,
      startsAt: effectiveStartsAt,
      duration: effectiveDuration,
      expiresAt: effectiveExpiresAt,
      accessType: accessType,
      schedule: validSchedule,
      joinCodeHash: codeHash,
      invitedUserIds: <String>{_profile.id},
      participantIds: <String>{_profile.id},
      isStarted: false,
      startedAt: null,
      pendingHostTransferUserId: null,
      posterBytes: posterBytes,
    );
    _events.insert(0, created);
    notifyListeners();
    return _projectEvent(created);
  }

  bool rescheduleEvent(String eventId, EventSchedule newSchedule) {
    if (!newSchedule.isValid || newSchedule.isStartInPast(now)) return false;
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return false;
    final event = _events[idx];
    if (event.hostId != _profile.id || event.isEnded) return false;

    final newStart = newSchedule.startsAtInstant;
    final newEnd = newSchedule.expiresAtInstant;
    _events[idx] = event.copyWithDetails(
      schedule: newSchedule,
      startsAt: newStart,
      expiresAt: newEnd,
      duration: newEnd.difference(newStart),
    );
    notifyListeners();
    return true;
  }

  bool cancelEvent(String eventId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return false;
    final event = _events[idx];
    if (event.hostId != _profile.id) return false;
    final updatedSchedule = event.schedule?.copyWith(isCancelled: true);
    _events[idx] = event.copyWithDetails(
      isEnded: true,
      schedule: updatedSchedule,
    );
    _mediaCache.evictByChannel(eventId);
    _purgeStagedUploadsForChannel(eventId);
    _issuedDownloadTokens.removeWhere((_, t) => t.channelId == eventId);
    notifyListeners();
    return true;
  }

  /// Host control: update title, description, or discovery radius without resetting expiration.
  bool updateEventDetails(
    String eventId, {
    required String title,
    required String description,
    required double radiusMeters,
  }) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return false;
    final event = _events[idx];
    if (event.hostId != _profile.id || !event.isActiveAt(now)) return false;

    _events[idx] = event.copyWithDetails(
      title: title.trim(),
      description: description.trim(),
      radiusMeters: radiusMeters,
    );
    notifyListeners();
    return true;
  }

  /// Host control: move event location.
  /// Preserves event ID, chat history, and original expiration time, and notifies participants.
  bool moveEventLocation(String eventId, GeoPoint newLocation) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return false;
    final event = _events[idx];
    if (event.hostId != _profile.id || !event.isActiveAt(now)) return false;

    final notice =
        'Host moved "${event.title}" to ${newLocation.areaName}. Expiration timer unchanged.';
    final moved = event.moveLocation(newLocation, notice: notice);
    _events[idx] = moved;
    if (_pendingHostMovementEventId == eventId) {
      _pendingHostMovementEventId = null;
    }
    _dismissedHostMovementEvents.remove(eventId);

    final currentNow = now;
    _messages.add(
      _StoredChatMessage(
        id: 'sys-${currentNow.microsecondsSinceEpoch}',
        channelId: event.id,
        senderId: _profile.id,
        senderDisplayName: 'Event Notice',
        isAnonymous: false,
        body: notice,
        createdAt: currentNow,
        expiresAt: event.expiresAt, // Tied to original event expiration
        originPoint: newLocation,
        isSystemNotice: true,
      ),
    );

    if (event.participantIds.isNotEmpty) {
      _eventAlerts.insert(
        0,
        _StoredEventAlert(
          eventId: event.id,
          hostId: event.hostId,
          message: notice,
        ),
      );
    }
    notifyListeners();
    return true;
  }

  bool endEvent(String eventId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return false;
    final event = _events[idx];
    if (event.hostId != _profile.id) return false;
    _events[idx] = event.copyWithDetails(isEnded: true);
    if (_pendingHostMovementEventId == eventId) {
      _pendingHostMovementEventId = null;
    }
    _dismissedHostMovementEvents.remove(eventId);
    _mediaCache.evictByChannel(eventId);
    _purgeStagedUploadsForChannel(eventId);
    _issuedDownloadTokens.removeWhere((_, t) => t.channelId == eventId);
    notifyListeners();
    return true;
  }

  /// Host starts the event.
  /// Requires physical presence inside the event radius with a fresh, accurate GPS fix
  /// and validates that the scheduled operating window is currently open.
  String? startEvent(String eventId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return 'Event not found.';
    final event = _events[idx];

    if (event.hostId != _profile.id) {
      return 'Only the event host can start this event.';
    }
    if (event.isEnded) {
      return 'Cannot start an event that has already ended.';
    }
    if (event.schedule != null && event.schedule!.isCancelled) {
      return 'Cannot start a cancelled event.';
    }
    if (event.isStarted) {
      return 'Event has already started.';
    }

    final currentNow = now;

    // Validate scheduled operating window
    if (event.schedule != null) {
      final windowErr = event.schedule!.validateStartWindow(now: currentNow);
      if (windowErr != null) {
        return windowErr;
      }
    } else {
      if (currentNow.isBefore(event.startsAt)) {
        return 'Event cannot be started before its scheduled start time.';
      }
      if (!currentNow.isBefore(event.expiresAt)) {
        return 'Event cannot be started after its scheduled operating window has ended.';
      }
    }

    // Host physical presence checks
    if (!hasLocationAccess) {
      return 'Location permission is required to verify host presence and start the event.';
    }
    if (!hasFreshAccurateLocation) {
      return 'A fresh, accurate GPS fix is required to verify host presence.';
    }

    final dist = _currentLocation.distanceMetersTo(event.location);
    if (dist > event.radiusMeters) {
      return 'Host presence required: you are ${dist.round()}m away from "${event.title}", but must be within ${event.radiusMeters.round()}m of the venue to start this event.';
    }

    _events[idx] = event.copyWithDetails(
      isStarted: true,
      startedAt: currentNow,
    );

    final notice = 'Host started the event.';
    _messages.add(
      _StoredChatMessage(
        id: 'sys-${currentNow.microsecondsSinceEpoch}',
        channelId: event.id,
        senderId: _profile.id,
        senderDisplayName: 'Event Notice',
        isAnonymous: false,
        body: notice,
        createdAt: currentNow,
        expiresAt: event.expiresAt,
        originPoint: event.location,
        isSystemNotice: true,
      ),
    );

    notifyListeners();
    return null;
  }

  /// Initiates host ownership transfer to an eligible event participant.
  /// Host client designates the participant without probing live coordinates.
  String? initiateEventHostTransfer(String eventId, String targetUserId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return 'Event not found.';
    final event = _events[idx];

    if (event.hostId != _profile.id) {
      return 'Only the event host can initiate ownership transfer.';
    }
    if (event.isEnded) {
      return 'Cannot transfer ownership of an ended event.';
    }
    if (targetUserId == _profile.id) {
      return 'Cannot transfer ownership to yourself.';
    }
    if (!event.participantIds.contains(targetUserId)) {
      return 'Designated recipient must be an existing participant of the event.';
    }
    if (_blockedUserIds.contains(targetUserId)) {
      return 'Cannot transfer ownership to a blocked user.';
    }

    _events[idx] = event.copyWithDetails(
      pendingHostTransferUserId: targetUserId,
    );
    if (_pendingHostMovementEventId == eventId) {
      _pendingHostMovementEventId = null;
    }
    _dismissedHostMovementEvents.remove(eventId);

    final currentNow = now;
    final notice = 'Host initiated ownership transfer.';
    _messages.add(
      _StoredChatMessage(
        id: 'sys-${currentNow.microsecondsSinceEpoch}',
        channelId: event.id,
        senderId: _profile.id,
        senderDisplayName: 'Event Notice',
        isAnonymous: false,
        body: notice,
        createdAt: currentNow,
        expiresAt: event.expiresAt,
        originPoint: event.location,
        isSystemNotice: true,
      ),
    );

    notifyListeners();
    return null;
  }

  bool initiateHostTransfer(String eventId, String newHostUserId) {
    return initiateEventHostTransfer(eventId, newHostUserId) == null;
  }

  /// Recipient accepts host ownership transfer.
  /// Recipient client independently validates location permission, accuracy, freshness,
  /// and venue radius presence before atomically updating ownership.
  String? acceptEventHostTransfer(String eventId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return 'Event not found.';
    final event = _events[idx];

    if (event.pendingHostTransferUserId != _profile.id) {
      return 'You are not the designated recipient of this transfer.';
    }
    if (event.isEnded) {
      return 'Cannot accept transfer for an ended event.';
    }
    if (!event.participantIds.contains(_profile.id)) {
      return 'You must be a joined participant of the event to accept ownership.';
    }
    if (_blockedUserIds.contains(event.hostId)) {
      return 'Cannot accept transfer from a blocked user.';
    }

    // Independent recipient location verification
    if (!hasLocationAccess) {
      return 'Location permission is required to verify recipient presence.';
    }
    if (!hasFreshAccurateLocation) {
      return 'A fresh, accurate GPS fix is required to verify recipient presence.';
    }

    final dist = _currentLocation.distanceMetersTo(event.location);
    if (dist > event.radiusMeters) {
      return 'Recipient presence required: you must be within ${event.radiusMeters.round()}m of the venue to accept host transfer.';
    }

    // Atomic handoff: update host and revoke pending transfer
    _events[idx] = event.copyWithDetails(
      hostId: _profile.id,
      hostDisplayName: _profile.publicDisplayName,
      clearPendingHostTransfer: true,
    );

    final currentNow = now;
    final notice =
        'Event ownership transferred to ${_profile.publicDisplayName}.';
    _messages.add(
      _StoredChatMessage(
        id: 'sys-${currentNow.microsecondsSinceEpoch}',
        channelId: event.id,
        senderId: _profile.id,
        senderDisplayName: 'Event Notice',
        isAnonymous: false,
        body: notice,
        createdAt: currentNow,
        expiresAt: event.expiresAt,
        originPoint: event.location,
        isSystemNotice: true,
      ),
    );

    notifyListeners();
    return null;
  }

  /// Cancels or rejects a pending host transfer.
  String? cancelOrRejectEventHostTransfer(String eventId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return 'Event not found.';
    final event = _events[idx];

    final isHost = event.hostId == _profile.id;
    final isRecipient = event.pendingHostTransferUserId == _profile.id;
    if (!isHost && !isRecipient) {
      return 'Unauthorized to cancel or reject this transfer.';
    }

    _events[idx] = event.copyWithDetails(clearPendingHostTransfer: true);
    notifyListeners();
    return null;
  }

  /// Test simulation helper to set incoming pending transfer from another host.
  void simulateIncomingHostTransfer({
    required String eventId,
    required String designatedRecipientUserId,
  }) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;
    _events[idx] = _events[idx].copyWithDetails(
      pendingHostTransferUserId: designatedRecipientUserId,
    );
    notifyListeners();
  }

  /// Test simulation helper to add a participant to an event.
  void addParticipantForTest(String eventId, String userId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;
    _events[idx] = _events[idx].copyWithDetails(
      participantIds: <String>{..._events[idx].participantIds, userId},
    );
    notifyListeners();
  }

  /// Server-equivalent access gate: returns empty list if caller is not a member of the event.
  List<ChatMessage> eventMessagesFor(String eventId) {
    if (!hasLocationAccess || !isAuthorizedForEvent(eventId)) {
      return const <ChatMessage>[];
    }
    final currentNow = now;
    return _messages
        .where((m) {
          if (m.channelId != eventId) return false;
          if (m.isExpiredAt(currentNow)) return false;
          if (_blockedUserIds.contains(m.senderId)) return false;
          return true;
        })
        .map(_projectMessage)
        .toList();
  }

  bool sendEventMessage(
    String eventId,
    String rawText, {
    Uint8List? rawImageBytes,
    String? stagedUploadId,
  }) {
    final body = rawText.trim();
    if (!hasLocationAccess || !isAuthorizedForEvent(eventId)) {
      return false;
    }
    final stored = _storedEventById(eventId);
    if (stored == null) return false;

    final currentNow = now;
    final seq = _messageSeqCounter + 1;
    ChatImageAttachment? attachment;
    if (rawImageBytes != null || stagedUploadId != null) {
      attachment = _commitPrivateMediaAttachment(
        channelKind: _MediaChannelKind.event,
        channelId: eventId,
        createdAt: currentNow,
        expiresAt: stored.expiresAt,
        sequence: seq,
        rawImageBytes: rawImageBytes,
        stagedUploadId: stagedUploadId,
      );
      if (attachment == null) return false;
    }
    if (body.isEmpty && attachment == null) return false;
    _messageSeqCounter = seq;

    _messages.add(
      _StoredChatMessage(
        id: 'emsg-${currentNow.microsecondsSinceEpoch}',
        channelId: eventId,
        senderId: _profile.id,
        senderDisplayName: _profile.activeDisplayName,
        isAnonymous: _profile.isAnonymous,
        body: body,
        createdAt: currentNow,
        expiresAt: stored.expiresAt,
        originPoint: stored.location,
        sequence: seq,
        attachment: attachment,
      ),
    );
    notifyListeners();
    return true;
  }

  // --- Direct Message Requests & Safety ---

  List<DmRequest> get pendingDmRequests => _dmRequests
      .where(
        (r) =>
            (r.fromUserId == _profile.id || r.toUserId == _profile.id) &&
            r.status == DmRequestStatus.pending &&
            !_blockedUserIds.contains(r.fromUserId) &&
            !_blockedUserIds.contains(r.toUserId),
      )
      .map(
        (r) =>
            r.copyWith(messages: List<DirectMessage>.unmodifiable(r.messages)),
      )
      .toList();

  List<DmRequest> get allDmRequestsRaw =>
      List<DmRequest>.unmodifiable(_dmRequests);

  List<DmRequest> get acceptedDmThreads {
    final list = _dmRequests
        .where(
          (r) =>
              (r.fromUserId == _profile.id || r.toUserId == _profile.id) &&
              r.status == DmRequestStatus.accepted &&
              !r.deletedByUserIds.contains(_profile.id) &&
              !_blockedUserIds.contains(r.fromUserId) &&
              !_blockedUserIds.contains(r.toUserId),
        )
        .map(
          (r) => r.copyWith(
            messages: List<DirectMessage>.unmodifiable(r.messages),
          ),
        )
        .toList();

    list.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      final aTime = a.messages.isNotEmpty
          ? a.messages.last.createdAt
          : a.createdAt;
      final bTime = b.messages.isNotEmpty
          ? b.messages.last.createdAt
          : b.createdAt;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  void injectMockDmRequest(DmRequest request) {
    _dmRequests.add(request);
    notifyListeners();
  }

  void pinConversation(String threadId, bool isPinned) {
    final idx = _dmRequests.indexWhere((r) => r.id == threadId);
    if (idx != -1) {
      _dmRequests[idx] = _dmRequests[idx].copyWith(isPinned: isPinned);
      notifyListeners();
    }
  }

  void archiveConversation(String threadId, bool isArchived) {
    final idx = _dmRequests.indexWhere((r) => r.id == threadId);
    if (idx != -1) {
      _dmRequests[idx] = _dmRequests[idx].copyWith(isArchived: isArchived);
      notifyListeners();
    }
  }

  void deleteConversationLocally(String threadId) {
    final idx = _dmRequests.indexWhere((r) => r.id == threadId);
    if (idx != -1) {
      final updated = Set<String>.from(_dmRequests[idx].deletedByUserIds)
        ..add(_profile.id);
      _dmRequests[idx] = _dmRequests[idx].copyWith(deletedByUserIds: updated);
      notifyListeners();
    }
  }

  String? sendDmRequest({
    required String toUserId,
    String? toDisplayName,
    required String introMessage,
  }) {
    final body = introMessage.trim();
    if (body.isEmpty) return 'Write a short intro message.';
    if (toUserId == _profile.id) return 'Cannot message yourself.';
    if (_blockedUserIds.contains(toUserId)) return 'This user is blocked.';

    final existing = _dmRequests.any(
      (r) =>
          ((r.fromUserId == _profile.id && r.toUserId == toUserId) ||
              (r.fromUserId == toUserId && r.toUserId == _profile.id)) &&
          r.status != DmRequestStatus.declined,
    );
    if (existing) return 'A request or conversation already exists.';

    final resolvedToDisplayName =
        toDisplayName ??
        _otherParticipants
            .where((p) => p.userId == toUserId)
            .firstOrNull
            ?.displayName ??
        _mockAccounts.values
            .where((u) => u.id == toUserId)
            .firstOrNull
            ?.activeDisplayName ??
        '@user';

    _dmRequests.insert(
      0,
      DmRequest(
        id: 'dm-${now.microsecondsSinceEpoch}',
        fromUserId: _profile.id,
        fromDisplayName: _profile.publicDisplayName,
        fromIsAnonymous: false,
        toUserId: toUserId,
        toDisplayName: resolvedToDisplayName,
        introMessage: body,
        createdAt: now,
        status: DmRequestStatus.pending,
      ),
    );
    notifyListeners();
    return null;
  }

  /// Only the intended recipient (`toUserId == profile.id`) may accept or decline
  /// a DM request, and only while it is `pending` and neither party is blocked.
  bool respondToDmRequest(String requestId, {required bool accept}) {
    final idx = _dmRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;
    final request = _dmRequests[idx];
    if (request.toUserId != _profile.id) return false;
    if (request.status != DmRequestStatus.pending) return false;
    if (_blockedUserIds.contains(request.fromUserId) ||
        _blockedUserIds.contains(request.toUserId)) {
      return false;
    }

    _dmRequests[idx] = request.copyWith(
      status: accept ? DmRequestStatus.accepted : DmRequestStatus.declined,
    );
    notifyListeners();
    return true;
  }

  bool sendDirectMessage(
    String requestId,
    String rawText, {
    Uint8List? rawImageBytes,
    String? stagedUploadId,
  }) {
    final body = rawText.trim();
    final idx = _dmRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;
    final thread = _dmRequests[idx];
    // Security rule: only accepted DM participants can exchange direct messages.
    if (thread.fromUserId != _profile.id && thread.toUserId != _profile.id) {
      return false;
    }
    if (thread.status != DmRequestStatus.accepted) return false;
    if (_blockedUserIds.contains(thread.fromUserId) ||
        _blockedUserIds.contains(thread.toUserId)) {
      return false;
    }

    final currentNow = now;
    final seq = _messageSeqCounter + 1;
    ChatImageAttachment? attachment;
    if (rawImageBytes != null || stagedUploadId != null) {
      attachment = _commitPrivateMediaAttachment(
        channelKind: _MediaChannelKind.dm,
        channelId: requestId,
        createdAt: currentNow,
        expiresAt: currentNow.add(
          Duration(hours: _profile.messageRetentionHours),
        ),
        sequence: seq,
        rawImageBytes: rawImageBytes,
        stagedUploadId: stagedUploadId,
      );
      if (attachment == null) return false;
    }
    if (body.isEmpty && attachment == null) return false;
    _messageSeqCounter = seq;

    final updated = <DirectMessage>[
      ...thread.messages,
      DirectMessage(
        id: 'dmsg-${currentNow.microsecondsSinceEpoch}',
        senderId: _profile.id,
        senderDisplayName: _profile.publicDisplayName,
        body: body,
        createdAt: currentNow,
        attachment: attachment,
      ),
    ];
    _dmRequests[idx] = thread.copyWith(messages: updated);
    notifyListeners();
    return true;
  }

  void simulateAcceptedDmThreadForTest(String requestId) {
    final idx = _dmRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      _dmRequests[idx] = _dmRequests[idx].copyWith(
        status: DmRequestStatus.accepted,
      );
      notifyListeners();
    }
  }

  // --- Image Sharing, Private Storage Authorization & Cache ---

  bool _canUploadToChannel(String channelId, DateTime currentNow) {
    if (_curatedLandmarks.any((l) => l.id == channelId)) {
      if (!canParticipateInNearby) return false;
      return _activeValidVisitFor(channelId, currentNow) != null;
    }
    if (_events.any((e) => e.id == channelId)) {
      return hasFreshAccurateLocation && isAuthorizedForEvent(channelId);
    }
    final thread = _dmRequests.where((r) => r.id == channelId).firstOrNull;
    if (thread != null) {
      if (thread.fromUserId != _profile.id && thread.toUserId != _profile.id) {
        return false;
      }
      if (thread.status != DmRequestStatus.accepted) return false;
      if (_blockedUserIds.contains(thread.fromUserId) ||
          _blockedUserIds.contains(thread.toUserId)) {
        return false;
      }
      return true;
    }
    return false;
  }

  String? stageImageUpload({
    required String channelId,
    required Uint8List rawBytes,
  }) {
    final currentNow = now;
    if (!_canUploadToChannel(channelId, currentNow)) return null;
    final sanitized = MediaSanitizer.sanitizeAndValidate(
      rawBytes,
      maxBytes: maxImageBytes,
    );
    if (!sanitized.isValid) return null;
    final uploadId =
        'up-${++_mediaCounter}-${currentNow.microsecondsSinceEpoch}';
    _stagedUploads[uploadId] = _StagedImageUpload(
      uploadId: uploadId,
      channelId: channelId,
      sanitizedResult: sanitized,
      state: UploadLifecycleState.uploading,
    );
    notifyListeners();
    return uploadId;
  }

  bool cancelStagedUpload(String uploadId) {
    final removed = _stagedUploads.remove(uploadId);
    if (removed == null) return false;
    final bytes = removed.sanitizedResult.sanitizedBytes;
    if (bytes != null) {
      bytes.fillRange(0, bytes.length, 0);
    }
    notifyListeners();
    return true;
  }

  List<PendingImageUpload> pendingUploadsForChannel(String channelId) {
    return _stagedUploads.values
        .where((u) => u.channelId == channelId)
        .map(
          (u) => PendingImageUpload(
            uploadId: u.uploadId,
            channelId: u.channelId,
            mimeType: u.sanitizedResult.mimeType ?? 'image/jpeg',
            sizeBytes: u.sanitizedResult.sanitizedBytes?.length ?? 0,
            width: u.sanitizedResult.width,
            height: u.sanitizedResult.height,
            state: u.state,
            errorMessage: u.errorMessage,
          ),
        )
        .toList();
  }

  ChatImageAttachment? _commitPrivateMediaAttachment({
    required _MediaChannelKind channelKind,
    required String channelId,
    required DateTime createdAt,
    required DateTime expiresAt,
    required int sequence,
    Uint8List? rawImageBytes,
    String? stagedUploadId,
  }) {
    SanitizedImageResult? sanitized;
    if (stagedUploadId != null) {
      final staged = _stagedUploads.remove(stagedUploadId);
      if (staged == null || staged.channelId != channelId) return null;
      sanitized = staged.sanitizedResult;
    } else if (rawImageBytes != null) {
      final res = MediaSanitizer.sanitizeAndValidate(
        rawImageBytes,
        maxBytes: maxImageBytes,
      );
      if (!res.isValid) return null;
      sanitized = res;
    }
    if (sanitized == null || sanitized.sanitizedBytes == null) return null;

    final mediaId =
        'med-${++_mediaCounter}-${createdAt.microsecondsSinceEpoch}';
    final ext = sanitized.extension ?? 'jpg';
    final objectKey = 'chat-media/$channelId/$mediaId.$ext';
    final attachment = ChatImageAttachment(
      mediaId: mediaId,
      storageObjectKey: objectKey,
      mimeType: sanitized.mimeType!,
      sizeBytes: sanitized.sanitizedBytes!.length,
      width: sanitized.width,
      height: sanitized.height,
    );

    final bytesCopy = Uint8List.fromList(sanitized.sanitizedBytes!);
    _privateMediaObjects[mediaId] = _StoredPrivateMediaObject(
      attachment: attachment,
      sanitizedBytes: bytesCopy,
      channelKind: channelKind,
      channelId: channelId,
      senderId: _profile.id,
      createdAt: createdAt,
      expiresAt: expiresAt,
      sequence: sequence,
    );
    return attachment;
  }

  bool _isAuthorizedForMediaObject(
    _StoredPrivateMediaObject obj,
    DateTime currentNow, {
    String? requiredVisitSessionId,
  }) {
    if (obj.isExpiredAt(currentNow)) return false;
    if (_blockedUserIds.contains(obj.senderId)) return false;

    switch (obj.channelKind) {
      case _MediaChannelKind.landmark:
        if (!canParticipateInNearby) return false;
        final visit = _activeValidVisitFor(obj.channelId, currentNow);
        if (visit == null) return false;
        if (requiredVisitSessionId != null &&
            visit.sessionId != requiredVisitSessionId) {
          return false;
        }
        // Strict current-visit-only window: never reveal media from before entry or prior visits!
        if (obj.createdAt.isBefore(visit.enteredAt)) return false;
        if (obj.sequence < visit.minMessageSequence) return false;
        return true;
      case _MediaChannelKind.event:
        return hasFreshAccurateLocation && isAuthorizedForEvent(obj.channelId);
      case _MediaChannelKind.dm:
        final thread = _dmRequests
            .where((r) => r.id == obj.channelId)
            .firstOrNull;
        if (thread == null) return false;
        if (thread.fromUserId != _profile.id &&
            thread.toUserId != _profile.id) {
          return false;
        }
        if (thread.status != DmRequestStatus.accepted) return false;
        if (_blockedUserIds.contains(thread.fromUserId) ||
            _blockedUserIds.contains(thread.toUserId)) {
          return false;
        }
        return true;
    }
  }

  /// Issues a short-lived signed download token only if the caller currently
  /// satisfies the channel's visit/event/DM authorization and block rules.
  MediaDownloadToken? issueMediaDownloadToken(String mediaId) {
    final currentNow = now;
    final obj = _privateMediaObjects[mediaId];
    if (obj == null) return null;
    if (!_isAuthorizedForMediaObject(obj, currentNow)) return null;

    String? visitSessionId;
    if (obj.channelKind == _MediaChannelKind.landmark) {
      visitSessionId = _activeValidVisitFor(
        obj.channelId,
        currentNow,
      )?.sessionId;
    }

    final tokenValue = hashSecretCode(
      '$mediaId:${currentNow.microsecondsSinceEpoch}:${++_mediaCounter}',
      salt: obj.channelId,
    );
    final issued = MediaDownloadToken(
      token: tokenValue,
      mediaId: mediaId,
      channelId: obj.channelId,
      expiresAt: currentNow.add(const Duration(seconds: 60)),
      visitSessionId: visitSessionId,
    );
    _issuedDownloadTokens[tokenValue] = issued;
    return issued;
  }

  /// Downloads media bytes using a previously issued short-lived token,
  /// re-verifying token expiration and current visit/event/DM authorization.
  Uint8List? downloadMediaWithToken(String tokenValue) {
    final currentNow = now;
    final token = _issuedDownloadTokens[tokenValue];
    if (token == null || token.isExpiredAt(currentNow)) {
      _issuedDownloadTokens.remove(tokenValue);
      return null;
    }
    final obj = _privateMediaObjects[token.mediaId];
    if (obj == null) return null;
    if (!_isAuthorizedForMediaObject(
      obj,
      currentNow,
      requiredVisitSessionId: token.visitSessionId,
    )) {
      _issuedDownloadTokens.remove(tokenValue);
      _mediaCache.evictByChannel(obj.channelId);
      return null;
    }
    _mediaCache.put(
      mediaId: obj.attachment.mediaId,
      channelId: obj.channelId,
      senderId: obj.senderId,
      bytes: obj.sanitizedBytes,
      visitSessionId: token.visitSessionId,
    );
    return Uint8List.fromList(obj.sanitizedBytes);
  }

  /// Convenience helper for UI components: verifies current authorization,
  /// serves from `EphemeralMediaCache` if valid, or issues a short-lived token
  /// and caches the sanitized bytes.
  Uint8List? fetchAuthorizedImageBytes(String mediaId) {
    final currentNow = now;
    final obj = _privateMediaObjects[mediaId];
    if (obj == null) return null;
    if (!_isAuthorizedForMediaObject(obj, currentNow)) {
      _mediaCache.evictByChannel(obj.channelId);
      return null;
    }
    String? visitSessionId;
    if (obj.channelKind == _MediaChannelKind.landmark) {
      visitSessionId = _activeValidVisitFor(
        obj.channelId,
        currentNow,
      )?.sessionId;
    }
    final cached = _mediaCache.get(
      mediaId,
      requiredVisitSessionId: visitSessionId,
    );
    if (cached != null) return cached;
    final token = issueMediaDownloadToken(mediaId);
    if (token == null) return null;
    return downloadMediaWithToken(token.token);
  }

  bool isMediaCached(String mediaId) => _mediaCache.contains(mediaId);

  void clearAllMediaCache() {
    _mediaCache.clearAll();
    _issuedDownloadTokens.clear();
  }

  void blockUser(String userId, {required String label}) {
    if (userId == _profile.id) return;
    _blockedUserIds.add(userId);
    _blockedUserLabels[userId] = label;
    _mediaCache.evictBySender(userId);
    _issuedDownloadTokens.removeWhere((_, token) {
      final obj = _privateMediaObjects[token.mediaId];
      return obj != null && obj.senderId == userId;
    });
    for (final thread in _dmRequests) {
      if (thread.fromUserId == userId || thread.toUserId == userId) {
        _mediaCache.evictByChannel(thread.id);
        _purgeStagedUploadsForChannel(thread.id);
        _issuedDownloadTokens.removeWhere((_, t) => t.channelId == thread.id);
      }
    }
    notifyListeners();
  }

  void unblockUser(String userId) {
    _blockedUserIds.remove(userId);
    _blockedUserLabels.remove(userId);
    notifyListeners();
  }

  String? submitSafetyReport({
    required String targetId,
    required String targetLabel,
    required ReportReasonPreset preset,
    required String explanation,
  }) {
    final cleanExplanation = explanation.trim();
    if (cleanExplanation.isEmpty) {
      return 'Explanation is required.';
    }
    if (cleanExplanation.length < 5) {
      return 'Explanation must be at least 5 characters.';
    }

    final isDuplicate = _reports.any(
      (r) => r.targetId == targetId && r.preset == preset,
    );
    if (isDuplicate) {
      return 'A report for this user under "${preset.displayName}" has already been submitted.';
    }

    final ticket = SafetyReport(
      id: 'rep-${now.microsecondsSinceEpoch}',
      targetId: targetId,
      targetLabel: targetLabel,
      preset: preset,
      explanation: cleanExplanation,
      createdAt: now,
      status: 'Local Demo Ticket (Pending Review)',
    );

    _reports.insert(0, ticket);
    notifyListeners();
    return null;
  }

  void reportTarget({
    required String targetId,
    required String targetLabel,
    required String reason,
  }) {
    submitSafetyReport(
      targetId: targetId,
      targetLabel: targetLabel,
      preset: ReportReasonPreset.other,
      explanation: reason.trim().isNotEmpty ? reason.trim() : 'User reported',
    );
  }
}
