import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Coordinates nearby discovery, temporary events, attendance privacy, and safety rules.
/// shortcut: in-memory store for Milestone 1, back with local Supabase + RLS in Milestone 2.
class AppController extends ChangeNotifier {
  AppController({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _seedInitialData();
  }

  static const String generalChannelId = 'nearby-general';

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

  final DateTime Function() _clock;
  DateTime get now => _clock();

  LocationPermissionState _permissionState = LocationPermissionState.simulated;
  LocationPermissionState get permissionState => _permissionState;

  GeoPoint _currentLocation = presetLocations.first;
  GeoPoint get currentLocation => _currentLocation;

  late UserProfile _profile;
  UserProfile get profile => _profile;

  final List<NearbyParticipant> _otherParticipants = <NearbyParticipant>[];
  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<ProximityEvent> _events = <ProximityEvent>[];
  final List<DmRequest> _dmRequests = <DmRequest>[];
  final Set<String> _blockedUserIds = <String>{};
  final Map<String, String> _blockedUserLabels = <String, String>{};
  final List<SafetyReport> _reports = <SafetyReport>[];
  final List<String> _eventAlerts = <String>[];

  Set<String> get blockedUserIds => Set<String>.unmodifiable(_blockedUserIds);
  Map<String, String> get blockedUserLabels =>
      Map<String, String>.unmodifiable(_blockedUserLabels);
  List<SafetyReport> get reports => List<SafetyReport>.unmodifiable(_reports);
  List<String> get eventAlerts => List<String>.unmodifiable(_eventAlerts);

  bool get hasLocationAccess =>
      _permissionState == LocationPermissionState.granted ||
      _permissionState == LocationPermissionState.simulated;

  void _seedInitialData() {
    final t0 = now;
    _profile = const UserProfile(
      id: 'user-me',
      anonymousHandle: 'MistFox#482',
      username: 'river_walker',
      identityMode: IdentityMode.anonymous,
      visibleInNearby: false, // Default privacy-first: ghost browse on
      ghostBrowseNearby: true,
      nearbyRadiusMeters: 500,
      messageRetentionHours: 24,
    );

    _otherParticipants.addAll(<NearbyParticipant>[
      const NearbyParticipant(
        userId: 'user-hana',
        displayName: '@hana_k',
        isAnonymous: false,
        location: GeoPoint(
          latitude: 40.9151,
          longitude: -73.1231,
          areaName: 'Staller Steps',
        ),
        visibleInNearby: true,
      ),
      const NearbyParticipant(
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
      const NearbyParticipant(
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
      const NearbyParticipant(
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

    _messages.addAll(<ChatMessage>[
      ChatMessage(
        id: 'msg-1',
        channelId: generalChannelId,
        senderId: 'user-hana',
        senderDisplayName: '@hana_k',
        isAnonymous: false,
        body: 'Acoustic guitar pop-up on the Staller grass right now — bring a blanket!',
        createdAt: t0.subtract(const Duration(minutes: 42)),
        expiresAt: t0.add(const Duration(hours: 23, minutes: 18)),
        originPoint: const GeoPoint(
          latitude: 40.9151,
          longitude: -73.1231,
          areaName: 'Staller Steps',
        ),
      ),
      ChatMessage(
        id: 'msg-2',
        channelId: generalChannelId,
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
      ),
      ChatMessage(
        id: 'msg-expired',
        channelId: generalChannelId,
        senderId: 'user-pine',
        senderDisplayName: 'PineOwl#109',
        isAnonymous: true,
        body: 'Yesterday coffee run — this message is already expired.',
        createdAt: t0.subtract(const Duration(hours: 26)),
        expiresAt: t0.subtract(const Duration(hours: 2)),
        originPoint: presetLocations.first,
      ),
    ]);

    const openJamId = 'evt-open-jam';
    const studyGroupId = 'evt-study-code';
    const rooftopInviteId = 'evt-rooftop-invite';

    _events.addAll(<ProximityEvent>[
      ProximityEvent(
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
      ),
      ProximityEvent(
        id: studyGroupId,
        hostId: 'user-me',
        hostDisplayName: 'MistFox#482',
        title: 'Systems & PostGIS Late-Night Sprint',
        description: 'Quiet table near the courtyard outlets. Join code on the whiteboard: 2468.',
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
      ),
      ProximityEvent(
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
      ),
    ]);

    _messages.addAll(<ChatMessage>[
      ChatMessage(
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
      ChatMessage(
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
        toDisplayName: _profile.activeDisplayName,
        introMessage: 'Hey! Saw your comment in nearby — do you play rhythm guitar or keys?',
        createdAt: t0.subtract(const Duration(minutes: 18)),
        status: DmRequestStatus.pending,
      ),
      DmRequest(
        id: 'dm-2',
        fromUserId: 'user-pine',
        fromDisplayName: 'PineOwl#109',
        fromIsAnonymous: true,
        toUserId: 'user-me',
        toDisplayName: _profile.activeDisplayName,
        introMessage: 'Sharing the SQL spatial index notes from the sprint.',
        createdAt: t0.subtract(const Duration(hours: 1)),
        status: DmRequestStatus.accepted,
        messages: <DirectMessage>[
          DirectMessage(
            id: 'dmsg-1',
            senderId: 'user-pine',
            senderDisplayName: 'PineOwl#109',
            body: 'Use ST_DWithin on geography(Point, 4326) with a GiST index!',
            createdAt: t0.subtract(const Duration(minutes: 50)),
          ),
        ],
      ),
    ]);
  }

  // --- Location & Permissions ---

  void setPermissionState(LocationPermissionState state) {
    _permissionState = state;
    notifyListeners();
  }

  void setSimulatedLocation(GeoPoint point) {
    _currentLocation = point;
    if (_permissionState == LocationPermissionState.prompt ||
        _permissionState == LocationPermissionState.denied) {
      _permissionState = LocationPermissionState.simulated;
    }
    notifyListeners();
  }

  void setNearbyRadiusMeters(double meters) {
    _profile = _profile.copyWith(nearbyRadiusMeters: meters);
    notifyListeners();
  }

  // --- Profile & Attendance Privacy ---

  void setIdentityMode(IdentityMode mode) {
    _profile = _profile.copyWith(identityMode: mode);
    notifyListeners();
  }

  void updateProfileHandles({String? anonymousHandle, String? username}) {
    _profile = _profile.copyWith(
      anonymousHandle: anonymousHandle?.trim().isNotEmpty == true
          ? anonymousHandle!.trim()
          : null,
      username: username?.trim().isNotEmpty == true
          ? username!.trim().replaceAll('@', '')
          : null,
    );
    notifyListeners();
  }

  void setVisibleInNearby(bool visible) {
    _profile = _profile.copyWith(visibleInNearby: visible);
    notifyListeners();
  }

  void setGhostBrowseNearby(bool ghostBrowse) {
    _profile = _profile.copyWith(ghostBrowseNearby: ghostBrowse);
    notifyListeners();
  }

  void setMessageRetentionHours(int hours) {
    _profile = _profile.copyWith(messageRetentionHours: hours);
    notifyListeners();
  }

  // --- Nearby Discovery & General Chat ---

  /// Enforces visibility server-equivalent rule: only users who opted into
  /// `visibleInNearby` within the configured radius are returned.
  List<NearbyParticipant> get visibleNearbyParticipants {
    if (!hasLocationAccess) return const <NearbyParticipant>[];
    final list = <NearbyParticipant>[];
    if (_profile.visibleInNearby) {
      list.add(
        NearbyParticipant(
          userId: _profile.id,
          displayName: '${_profile.activeDisplayName} (You)',
          isAnonymous: _profile.isAnonymous,
          location: _currentLocation,
          visibleInNearby: true,
        ),
      );
    }
    for (final p in _otherParticipants) {
      if (!p.visibleInNearby) continue;
      if (_blockedUserIds.contains(p.userId)) continue;
      final dist = _currentLocation.distanceMetersTo(p.location);
      if (dist <= _profile.nearbyRadiusMeters) {
        list.add(p);
      }
    }
    return list;
  }

  /// Returns non-expired messages within the user's configured geographic radius.
  List<ChatMessage> get nearbyMessages {
    if (!hasLocationAccess) return const <ChatMessage>[];
    if (!_profile.visibleInNearby && !_profile.ghostBrowseNearby) {
      return const <ChatMessage>[];
    }
    final currentNow = now;
    return _messages.where((m) {
      if (m.channelId != generalChannelId) return false;
      if (m.isExpiredAt(currentNow)) return false;
      if (_blockedUserIds.contains(m.senderId)) return false;
      final dist = _currentLocation.distanceMetersTo(m.originPoint);
      return dist <= _profile.nearbyRadiusMeters;
    }).toList();
  }

  void sendNearbyMessage(String rawText) {
    final body = rawText.trim();
    if (body.isEmpty || !hasLocationAccess) return;
    final currentNow = now;
    _messages.add(
      ChatMessage(
        id: 'msg-${currentNow.microsecondsSinceEpoch}',
        channelId: generalChannelId,
        senderId: _profile.id,
        senderDisplayName: _profile.activeDisplayName,
        isAnonymous: _profile.isAnonymous,
        body: body,
        createdAt: currentNow,
        expiresAt: currentNow.add(
          Duration(hours: _profile.messageRetentionHours),
        ),
        originPoint: _currentLocation,
      ),
    );
    notifyListeners();
  }

  // --- Events, Access Control & Movement ---

  /// Returns active (non-expired, non-ended) events whose discovery radius or
  /// user's nearby radius covers the current distance, plus joined events.
  List<ProximityEvent> get discoverableEvents {
    if (!hasLocationAccess) return const <ProximityEvent>[];
    final currentNow = now;
    return _events.where((e) {
      if (!e.isActiveAt(currentNow)) return false;
      if (_blockedUserIds.contains(e.hostId)) return false;
      if (e.participantIds.contains(_profile.id)) return true;
      final dist = _currentLocation.distanceMetersTo(e.location);
      final maxRadius = e.radiusMeters > _profile.nearbyRadiusMeters
          ? e.radiusMeters
          : _profile.nearbyRadiusMeters;
      return dist <= maxRadius;
    }).toList();
  }

  ProximityEvent? eventById(String eventId) {
    final currentNow = now;
    for (final e in _events) {
      if (e.id == eventId && e.isActiveAt(currentNow)) return e;
    }
    return null;
  }

  bool isAuthorizedForEvent(String eventId) {
    final event = eventById(eventId);
    if (event == null) return false;
    if (event.hostId == _profile.id) return true;
    return event.participantIds.contains(_profile.id);
  }

  /// Joins an event if access rules pass.
  /// Attendance privacy rule: joining an event NEVER exposes the user in general nearby discovery.
  String? joinEvent(String eventId, {String? joinCode}) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return 'Event not found.';
    final event = _events[idx];
    if (!event.isActiveAt(now)) return 'This event has expired or ended.';

    switch (event.accessType) {
      case EventAccessType.public:
        break;
      case EventAccessType.joinCode:
        if (joinCode == null || !event.verifyJoinCode(joinCode)) {
          return 'Invalid join code.';
        }
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

  void leaveEvent(String eventId) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;
    final event = _events[idx];
    final updated = Set<String>.from(event.participantIds)..remove(_profile.id);
    _events[idx] = event.copyWithDetails(participantIds: updated);
    notifyListeners();
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
  }) {
    final currentNow = now;
    final id = 'evt-${currentNow.microsecondsSinceEpoch}';
    final codeHash =
        accessType == EventAccessType.joinCode &&
            rawJoinCode != null &&
            rawJoinCode.trim().isNotEmpty
        ? hashSecretCode(rawJoinCode, salt: id)
        : null;

    final created = ProximityEvent(
      id: id,
      hostId: _profile.id,
      hostDisplayName: _profile.activeDisplayName,
      title: title.trim(),
      description: description.trim(),
      categoryTag: categoryTag.trim().isEmpty ? 'Local Hangout' : categoryTag,
      location: location,
      radiusMeters: radiusMeters,
      startsAt: currentNow,
      duration: duration,
      expiresAt: currentNow.add(duration),
      accessType: accessType,
      joinCodeHash: codeHash,
      invitedUserIds: <String>{_profile.id},
      participantIds: <String>{_profile.id},
    );
    _events.insert(0, created);
    notifyListeners();
    return created;
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

    final currentNow = now;
    _messages.add(
      ChatMessage(
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
      _eventAlerts.insert(0, notice);
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
    notifyListeners();
    return true;
  }

  /// Server-equivalent access gate: returns empty list if caller is not a member of the event.
  List<ChatMessage> eventMessagesFor(String eventId) {
    if (!isAuthorizedForEvent(eventId)) return const <ChatMessage>[];
    final currentNow = now;
    return _messages.where((m) {
      if (m.channelId != eventId) return false;
      if (m.isExpiredAt(currentNow)) return false;
      if (_blockedUserIds.contains(m.senderId)) return false;
      return true;
    }).toList();
  }

  bool sendEventMessage(String eventId, String rawText) {
    final body = rawText.trim();
    if (body.isEmpty || !isAuthorizedForEvent(eventId)) return false;
    final event = eventById(eventId);
    if (event == null) return false;

    final currentNow = now;
    _messages.add(
      ChatMessage(
        id: 'emsg-${currentNow.microsecondsSinceEpoch}',
        channelId: eventId,
        senderId: _profile.id,
        senderDisplayName: _profile.activeDisplayName,
        isAnonymous: _profile.isAnonymous,
        body: body,
        createdAt: currentNow,
        expiresAt: event.expiresAt,
        originPoint: event.location,
      ),
    );
    notifyListeners();
    return true;
  }

  // --- Direct Message Requests & Safety ---

  List<DmRequest> get pendingDmRequests => _dmRequests
      .where(
        (r) =>
            r.status == DmRequestStatus.pending &&
            !_blockedUserIds.contains(r.fromUserId) &&
            !_blockedUserIds.contains(r.toUserId),
      )
      .toList();

  List<DmRequest> get acceptedDmThreads => _dmRequests
      .where(
        (r) =>
            r.status == DmRequestStatus.accepted &&
            !_blockedUserIds.contains(r.fromUserId) &&
            !_blockedUserIds.contains(r.toUserId),
      )
      .toList();

  String? sendDmRequest({
    required String toUserId,
    required String toDisplayName,
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

    _dmRequests.insert(
      0,
      DmRequest(
        id: 'dm-${now.microsecondsSinceEpoch}',
        fromUserId: _profile.id,
        fromDisplayName: _profile.activeDisplayName,
        fromIsAnonymous: _profile.isAnonymous,
        toUserId: toUserId,
        toDisplayName: toDisplayName,
        introMessage: body,
        createdAt: now,
        status: DmRequestStatus.pending,
      ),
    );
    notifyListeners();
    return null;
  }

  void respondToDmRequest(String requestId, {required bool accept}) {
    final idx = _dmRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;
    _dmRequests[idx] = _dmRequests[idx].copyWith(
      status: accept ? DmRequestStatus.accepted : DmRequestStatus.declined,
    );
    notifyListeners();
  }

  bool sendDirectMessage(String requestId, String rawText) {
    final body = rawText.trim();
    if (body.isEmpty) return false;
    final idx = _dmRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;
    final thread = _dmRequests[idx];
    // Security rule: only accepted DM requests can exchange direct messages.
    if (thread.status != DmRequestStatus.accepted) return false;
    if (_blockedUserIds.contains(thread.fromUserId) ||
        _blockedUserIds.contains(thread.toUserId)) {
      return false;
    }

    final updated = <DirectMessage>[
      ...thread.messages,
      DirectMessage(
        id: 'dmsg-${now.microsecondsSinceEpoch}',
        senderId: _profile.id,
        senderDisplayName: _profile.activeDisplayName,
        body: body,
        createdAt: now,
      ),
    ];
    _dmRequests[idx] = thread.copyWith(messages: updated);
    notifyListeners();
    return true;
  }

  void blockUser(String userId, {required String label}) {
    if (userId == _profile.id) return;
    _blockedUserIds.add(userId);
    _blockedUserLabels[userId] = label;
    notifyListeners();
  }

  void unblockUser(String userId) {
    _blockedUserIds.remove(userId);
    _blockedUserLabels.remove(userId);
    notifyListeners();
  }

  void reportTarget({
    required String targetId,
    required String targetLabel,
    required String reason,
  }) {
    _reports.insert(
      0,
      SafetyReport(
        id: 'rep-${now.microsecondsSinceEpoch}',
        targetId: targetId,
        targetLabel: targetLabel,
        reason: reason.trim(),
        createdAt: now,
      ),
    );
    notifyListeners();
  }
}
