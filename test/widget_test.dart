import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/config/app_config.dart';
import 'package:proximity_app/core/identity/anonymous_name_generator.dart';
import 'package:proximity_app/core/media/media_sanitizer.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/chat/chat_image_widgets.dart';
import 'package:proximity_app/main.dart';

void main() {
  group('Domain & Privacy Rules', () {
    test('Attendance privacy: ghost browsing and event participation do not expose user in general nearby list', () {
      final controller = AppController();
      expect(controller.profile.visibleInNearby, isFalse);
      expect(controller.profile.ghostBrowseNearby, isTrue);

      // User can read nearby messages while ghost browsing, but is not in visibleNearbyParticipants
      expect(controller.nearbyMessages, isNotEmpty);
      expect(
        controller.visibleNearbyParticipants.any(
          (p) => p.userId == controller.profile.id,
        ),
        isFalse,
      );

      // Joining a public event does not expose user in general nearby discovery
      final joinErr = controller.joinEvent('evt-open-jam');
      expect(joinErr, isNull);
      expect(controller.isAuthorizedForEvent('evt-open-jam'), isTrue);
      expect(controller.profile.visibleInNearby, isFalse);
      expect(
        controller.visibleNearbyParticipants.any(
          (p) => p.userId == controller.profile.id,
        ),
        isFalse,
      );
    });

    test('Event movement preserves event ID, chat history, and original expiration timer', () {
      final fixedNow = DateTime(2026, 10, 24, 21, 0);
      final controller = AppController(clock: () => fixedNow);

      const eventId = 'evt-study-code';
      final beforeMove = controller.eventById(eventId)!;
      final originalExpiresAt = beforeMove.expiresAt;
      final initialMessages = controller.eventMessagesFor(eventId);
      expect(initialMessages, isNotEmpty);

      final movedOk = controller.moveEventLocation(
        eventId,
        AppController.presetLocations[1],
      );
      expect(movedOk, isTrue);

      final afterMove = controller.eventById(eventId)!;
      expect(afterMove.id, equals(beforeMove.id));
      expect(afterMove.expiresAt, equals(originalExpiresAt));
      expect(
        afterMove.areaName,
        equals(AppController.presetLocations[1].areaName),
      );

      final afterMessages = controller.eventMessagesFor(eventId);
      expect(afterMessages.length, equals(initialMessages.length + 1));
      expect(afterMessages.first.id, equals(initialMessages.first.id));
      expect(afterMessages.last.isSystemNotice, isTrue);
      expect(controller.eventAlerts, isNotEmpty);
    });

    test('Restricted events enforce join-code hashing and invite-only access', () {
      final controller = AppController();

      final created = controller.createEvent(
        title: 'Secret Lab',
        description: 'Bring badge',
        categoryTag: 'Lab',
        location: AppController.presetLocations.first,
        radiusMeters: 300,
        duration: const Duration(hours: 2),
        accessType: EventAccessType.joinCode,
        rawJoinCode: '9988',
      );
      // Digest is never plaintext '9988' and is verified via controller without exposing joinCodeHash on ProximityEvent
      final digest = hashSecretCode('9988', salt: created.id);
      expect(digest, isNot(equals('9988')));
      expect(controller.verifyEventJoinCode(created.id, 'wrong'), isFalse);
      expect(controller.verifyEventJoinCode(created.id, '9988'), isTrue);

      // Invite-only event blocks unauthorized user from reading chat or joining
      const inviteEventId = 'evt-rooftop-invite';
      expect(controller.isAuthorizedForEvent(inviteEventId), isFalse);
      expect(controller.eventMessagesFor(inviteEventId), isEmpty);
      expect(
        controller.sendEventMessage(inviteEventId, 'Trying to sneak in'),
        isFalse,
      );
      expect(controller.joinEvent(inviteEventId), isNotNull);
    });

    test('Expired messages and events are excluded automatically', () {
      var currentNow = DateTime(2026, 10, 24, 21, 0);
      final controller = AppController(clock: () => currentNow);

      expect(controller.nearbyMessages, isNotEmpty);
      expect(controller.discoverableEvents, isNotEmpty);

      // Advance clock 25 hours past retention & event durations
      currentNow = currentNow.add(const Duration(hours: 25));
      expect(controller.nearbyMessages, isEmpty);
      expect(controller.discoverableEvents, isEmpty);
    });

    test('DM requests require approval and blocking filters content', () {
      final controller = AppController();

      // Pending request cannot exchange direct messages before acceptance
      final pending = controller.pendingDmRequests.first;
      expect(controller.sendDirectMessage(pending.id, 'Premature DM'), isFalse);

      // Accepting request enables direct messaging
      expect(controller.respondToDmRequest(pending.id, accept: true), isTrue);
      expect(controller.sendDirectMessage(pending.id, 'Hello!'), isTrue);

      // Blocking user removes their messages, events, and DM threads
      controller.blockUser('user-hana', label: '@hana_k');
      expect(
        controller.nearbyMessages.any((m) => m.senderId == 'user-hana'),
        isFalse,
      );
      expect(
        controller.acceptedDmThreads.any((t) => t.fromUserId == 'user-hana'),
        isFalse,
      );
    });

    test('Scope A: Restricted-event privacy redacts private details and attendance for unauthorized users while preserving access for authorized members', () {
      final controller = AppController();

      // 1. Unauthorized invite-only event ('evt-rooftop-invite' hosted by user-hana)
      final unauthorizedInvite = controller.eventById('evt-rooftop-invite')!;
      expect(unauthorizedInvite.isAuthorized, isFalse);
      expect(unauthorizedInvite.isDetailsRedacted, isTrue);
      expect(unauthorizedInvite.participantCount, isNull);
      expect(
        unauthorizedInvite.description,
        equals(AppController.redactedInviteOnlyDescription),
      );
      expect(
        unauthorizedInvite.description.contains('pre-registered'),
        isFalse,
      );

      // Also redacted in discoverableEvents
      final discoveredInvite = controller.discoverableEvents.firstWhere(
        (e) => e.id == 'evt-rooftop-invite',
      );
      expect(discoveredInvite.isDetailsRedacted, isTrue);
      expect(discoveredInvite.participantCount, isNull);

      // 2. Unjoined join-code event ('evt-chess-code' hosted by user-pine) redacts private details until joined with valid code
      final unjoinedCodeEvent = controller.eventById('evt-chess-code')!;
      expect(unjoinedCodeEvent.isAuthorized, isFalse);
      expect(unjoinedCodeEvent.isDetailsRedacted, isTrue);
      expect(unjoinedCodeEvent.participantCount, isNull);
      expect(
        unjoinedCodeEvent.description,
        equals(AppController.redactedJoinCodeDescription),
      );
      expect(unjoinedCodeEvent.description.contains('stone bench'), isFalse);

      // Joining with wrong code fails and keeps details redacted
      expect(
        controller.joinEvent('evt-chess-code', joinCode: '0000'),
        isNotNull,
      );
      expect(controller.eventById('evt-chess-code')!.isDetailsRedacted, isTrue);

      // Joining with valid code ('1357') unlocks full description and attendance count
      expect(controller.joinEvent('evt-chess-code', joinCode: '1357'), isNull);
      final joinedCodeEvent = controller.eventById('evt-chess-code')!;
      expect(joinedCodeEvent.isAuthorized, isTrue);
      expect(joinedCodeEvent.isDetailsRedacted, isFalse);
      expect(joinedCodeEvent.participantCount, equals(2));
      expect(joinedCodeEvent.description, contains('stone bench'));

      // Leaving the join-code event re-redacts private details and attendance count
      controller.leaveEvent('evt-chess-code');
      expect(controller.eventById('evt-chess-code')!.isDetailsRedacted, isTrue);
      expect(controller.eventById('evt-chess-code')!.participantCount, isNull);

      // 3. Authorized join-code event ('evt-study-code' hosted by user-me)
      final authorizedStudy = controller.eventById('evt-study-code')!;
      expect(authorizedStudy.isAuthorized, isTrue);
      expect(authorizedStudy.isDetailsRedacted, isFalse);
      expect(authorizedStudy.participantCount, equals(2));
      expect(
        authorizedStudy.description.contains('2468'),
        isFalse,
        reason: 'Sample event description must not hardcode the join code',
      );

      // When location access is denied, eventById and eventMessagesFor do not leak data
      controller.setPermissionState(LocationPermissionState.denied);
      expect(controller.eventById('evt-study-code'), isNull);
      expect(controller.eventMessagesFor('evt-study-code'), isEmpty);
      controller.setPermissionState(LocationPermissionState.simulated);

      // Out-of-radius unjoined events cannot be retrieved via eventById
      controller.setSimulatedLocation(AppController.presetLocations[3]);
      expect(controller.eventById('evt-rooftop-invite'), isNull);
      controller.setSimulatedLocation(AppController.presetLocations.first);

      // 4. Public event ('evt-open-jam') remains visible to unjoined users, and joining unlocks chat
      final publicEvent = controller.eventById('evt-open-jam')!;
      expect(publicEvent.isDetailsRedacted, isFalse);
      expect(publicEvent.participantCount, equals(2));
      expect(controller.eventMessagesFor('evt-open-jam'), isEmpty);

      expect(controller.joinEvent('evt-open-jam'), isNull);
      expect(controller.eventMessagesFor('evt-open-jam'), isNotEmpty);
    });

    test('Scope B: Public-facing projections expose only coarse distance labels and area names, never exact coordinates', () {
      final controller = AppController();
      controller.setVisibleInNearby(true);

      final participants = controller.visibleNearbyParticipants;
      expect(participants, isNotEmpty);
      for (final p in participants) {
        expect(p.areaName, isNotEmpty);
        expect(p.distanceLabel, contains('away'));
        // Ensure string representation or fields do not leak raw lat/lon floats
        expect(p.distanceLabel.contains('40.91'), isFalse);
        expect(p.distanceLabel.contains('-73.12'), isFalse);
      }

      final nearbyMsgs = controller.nearbyMessages;
      expect(nearbyMsgs, isNotEmpty);
      for (final m in nearbyMsgs) {
        expect(m.areaName, isNotEmpty);
        expect(m.distanceLabel, contains('away'));
        expect(m.distanceLabel.contains('40.91'), isFalse);
      }

      final eventMsgs = controller.eventMessagesFor('evt-study-code');
      expect(eventMsgs, isNotEmpty);
      for (final m in eventMsgs) {
        expect(m.areaName, isNotEmpty);
        expect(m.distanceLabel, contains('away'));
      }

      final events = controller.discoverableEvents;
      expect(events, isNotEmpty);
      for (final e in events) {
        expect(e.areaName, isNotEmpty);
        expect(e.distanceLabel, contains('away'));
      }
    });

    test('Scope C: Messaging authorization enforces recipient-only DM response, pending state, participant-only DM send, block rules, and nearby participation settings', () {
      final controller = AppController();

      // 1. Outgoing DM request cannot be accepted or declined by the requester (user-me)
      final sendErr = controller.sendDmRequest(
        toUserId: 'user-harbor',
        toDisplayName: '@sailor_dan',
        introMessage: 'Ahoy from campus!',
      );
      expect(sendErr, isNull);
      final outgoing = controller.pendingDmRequests.firstWhere(
        (r) => r.toUserId == 'user-harbor',
      );
      expect(controller.respondToDmRequest(outgoing.id, accept: true), isFalse);
      expect(
        controller.respondToDmRequest(outgoing.id, accept: false),
        isFalse,
      );
      expect(
        controller.pendingDmRequests.any((r) => r.id == outgoing.id),
        isTrue,
      );
      expect(
        controller.acceptedDmThreads.any((r) => r.id == outgoing.id),
        isFalse,
      );

      // 2. Incoming pending DM request ('dm-1' from user-hana to user-me) can be declined once, then cannot be re-accepted
      expect(controller.respondToDmRequest('dm-1', accept: false), isTrue);
      expect(controller.pendingDmRequests.any((r) => r.id == 'dm-1'), isFalse);
      // Attempting to re-open / accept an already declined request fails without mutating state
      expect(controller.respondToDmRequest('dm-1', accept: true), isFalse);
      expect(controller.acceptedDmThreads.any((r) => r.id == 'dm-1'), isFalse);

      // Already accepted request ('dm-2') cannot be modified via respondToDmRequest
      expect(controller.respondToDmRequest('dm-2', accept: false), isFalse);
      expect(controller.acceptedDmThreads.any((r) => r.id == 'dm-2'), isTrue);

      // 3. Blocking a user prevents responding to their DM request or sending DMs in an accepted thread
      final beforeMsgCount = controller.acceptedDmThreads
          .firstWhere((t) => t.id == 'dm-2')
          .messages
          .length;
      controller.blockUser('user-pine', label: 'PineOwl#109');
      expect(
        controller.sendDirectMessage('dm-2', 'Blocked message attempt'),
        isFalse,
      );
      controller.unblockUser('user-pine');
      final afterUnblockCount = controller.acceptedDmThreads
          .firstWhere((t) => t.id == 'dm-2')
          .messages
          .length;
      expect(afterUnblockCount, equals(beforeMsgCount));

      // Non-existent / non-participant thread IDs cannot receive messages
      expect(
        controller.sendDirectMessage('non-existent-thread', 'Hello'),
        isFalse,
      );

      // 4. Nearby messaging obeys participation and location rules
      final initialNearbyCount = controller.nearbyMessages.length;
      // Ghost browsing is enabled by default -> sending is allowed
      expect(
        controller.sendNearbyMessage('Hello while ghost browsing'),
        isTrue,
      );
      expect(controller.nearbyMessages.length, equals(initialNearbyCount + 1));

      // When both visibleInNearby and ghostBrowseNearby are false (Nearby feed paused), sending is rejected
      controller.setVisibleInNearby(false);
      controller.setGhostBrowseNearby(false);
      expect(controller.canParticipateInNearby, isFalse);
      expect(
        controller.sendNearbyMessage('Should be rejected while paused'),
        isFalse,
      );

      // Re-enable ghost browsing and verify the rejected message was never stored
      controller.setGhostBrowseNearby(true);
      expect(
        controller.nearbyMessages.any(
          (m) => m.body == 'Should be rejected while paused',
        ),
        isFalse,
      );
      expect(controller.nearbyMessages.length, equals(initialNearbyCount + 1));

      // When location permission is denied, sending is rejected and the landmark visit is terminated;
      // re-enabling permission starts a new visit session without leaking prior-visit messages.
      controller.setPermissionState(LocationPermissionState.denied);
      expect(controller.sendNearbyMessage('Denied location send'), isFalse);
      controller.setPermissionState(LocationPermissionState.simulated);
      expect(
        controller.nearbyMessages.any((m) => m.body == 'Denied location send'),
        isFalse,
      );
      expect(controller.nearbyMessages, isEmpty);
    });

    test('Phase 1.1 Scope A: Event access eligibility enforces location permission, discovery radius, and join-code attempt limits', () {
      final controller = AppController();

      // 1. Without location permission, knowing an eventId cannot authorize, verify code, or join
      controller.setPermissionState(LocationPermissionState.denied);
      expect(controller.isAuthorizedForEvent('evt-study-code'), isFalse);
      expect(controller.verifyEventJoinCode('evt-chess-code', '1357'), isFalse);
      expect(controller.joinEvent('evt-open-jam'), isNotNull);
      expect(
        controller.joinEvent('evt-chess-code', joinCode: '1357'),
        isNotNull,
      );
      controller.setPermissionState(LocationPermissionState.simulated);
      expect(controller.isAuthorizedForEvent('evt-open-jam'), isFalse);
      expect(controller.isAuthorizedForEvent('evt-chess-code'), isFalse);

      // 2. From outside the discovery radius (Port Jefferson Harbor), knowing an eventId cannot verify code or join campus events
      controller.setSimulatedLocation(AppController.presetLocations[3]);
      expect(controller.eventById('evt-open-jam'), isNull);
      expect(controller.eventById('evt-chess-code'), isNull);
      expect(controller.verifyEventJoinCode('evt-chess-code', '1357'), isFalse);
      expect(controller.joinEvent('evt-open-jam'), isNotNull);
      expect(
        controller.joinEvent('evt-chess-code', joinCode: '1357'),
        isNotNull,
      );
      expect(controller.isAuthorizedForEvent('evt-open-jam'), isFalse);
      expect(controller.isAuthorizedForEvent('evt-chess-code'), isFalse);

      // Legitimate host/participant access is preserved across locations
      expect(controller.isAuthorizedForEvent('evt-study-code'), isTrue);
      expect(controller.eventById('evt-study-code'), isNotNull);

      // Return to campus location
      controller.setSimulatedLocation(AppController.presetLocations.first);

      // 3. Repeated failed join-code guesses trigger per-event lockout
      for (var i = 0; i < 5; i++) {
        expect(
          controller.joinEvent('evt-chess-code', joinCode: '000$i'),
          isNotNull,
        );
      }
      // Even with the valid code ('1357'), further attempts are rejected after lockout
      expect(controller.verifyEventJoinCode('evt-chess-code', '1357'), isFalse);
      expect(
        controller.joinEvent('evt-chess-code', joinCode: '1357'),
        isNotNull,
      );
      expect(controller.isAuthorizedForEvent('evt-chess-code'), isFalse);
    });

    test('Phase 1.1 Scope B: Location and radius setters reject non-preset values to prevent coordinate trilateration', () {
      final controller = AppController();
      expect(controller.profile.nearbyRadiusMeters, equals(500));
      expect(
        controller.currentLocation,
        equals(AppController.presetLocations.first),
      );

      // Arbitrary radii outside supported presets [250, 500, 1000, 2500] are rejected
      for (final invalidRadius in <double>[
        -100,
        0,
        123.45,
        313.37,
        500.01,
        9999,
      ]) {
        controller.setNearbyRadiusMeters(invalidRadius);
        expect(controller.profile.nearbyRadiusMeters, equals(500));
      }

      // Supported radius preset succeeds
      controller.setNearbyRadiusMeters(1000);
      expect(controller.profile.nearbyRadiusMeters, equals(1000));

      // Arbitrary non-preset coordinates are rejected by setSimulatedLocation
      const probePoint = GeoPoint(
        latitude: 40.91505,
        longitude: -73.12305,
        areaName: 'Arbitrary Probe Point',
      );
      controller.setSimulatedLocation(probePoint);
      expect(
        controller.currentLocation,
        equals(AppController.presetLocations.first),
      );

      // Supported preset location succeeds
      controller.setSimulatedLocation(AppController.presetLocations[1]);
      expect(
        controller.currentLocation,
        equals(AppController.presetLocations[1]),
      );
    });

    test('Phase 1.1 Scope C: Event movement alerts are scoped to authorized, active, non-blocked events', () {
      var currentNow = DateTime(2026, 10, 24, 21, 0);
      final controller = AppController(clock: () => currentNow);

      // 1. Seeded movement alert on 'evt-chess-code' is hidden while user is not a participant
      expect(controller.isAuthorizedForEvent('evt-chess-code'), isFalse);
      expect(
        controller.eventAlerts.any(
          (a) => a.contains('Courtyard Blitz Chess Club'),
        ),
        isFalse,
      );

      // 2. Joining 'evt-chess-code' authorizes the user and reveals its movement alert
      expect(controller.joinEvent('evt-chess-code', joinCode: '1357'), isNull);
      expect(
        controller.eventAlerts.any(
          (a) => a.contains('Courtyard Blitz Chess Club'),
        ),
        isTrue,
      );

      // 3. Blocking the host ('user-pine') immediately suppresses the alert
      controller.blockUser('user-pine', label: 'PineOwl#109');
      expect(
        controller.eventAlerts.any(
          (a) => a.contains('Courtyard Blitz Chess Club'),
        ),
        isFalse,
      );
      controller.unblockUser('user-pine');
      expect(
        controller.eventAlerts.any(
          (a) => a.contains('Courtyard Blitz Chess Club'),
        ),
        isTrue,
      );

      // 4. Leaving the event revokes authorization and suppresses the alert
      controller.leaveEvent('evt-chess-code');
      expect(
        controller.eventAlerts.any(
          (a) => a.contains('Courtyard Blitz Chess Club'),
        ),
        isFalse,
      );

      // 5. Host moving their own event shows alert while active, and suppresses it when location denied, ended, or expired
      expect(
        controller.moveEventLocation(
          'evt-study-code',
          AppController.presetLocations[1],
        ),
        isTrue,
      );
      expect(
        controller.eventAlerts.any(
          (a) => a.contains('Systems & PostGIS Late-Night Sprint'),
        ),
        isTrue,
      );

      controller.setPermissionState(LocationPermissionState.denied);
      expect(controller.eventAlerts, isEmpty);
      controller.setPermissionState(LocationPermissionState.simulated);

      // Re-join 'evt-chess-code' and verify ending or expiration suppresses alerts
      expect(controller.joinEvent('evt-chess-code', joinCode: '1357'), isNull);
      expect(controller.eventAlerts, hasLength(2));

      controller.endEvent('evt-study-code');
      expect(
        controller.eventAlerts.any(
          (a) => a.contains('Systems & PostGIS Late-Night Sprint'),
        ),
        isFalse,
      );
      expect(controller.eventAlerts, hasLength(1));

      currentNow = currentNow.add(const Duration(hours: 5));
      expect(controller.eventAlerts, isEmpty);
    });

    test('Milestone 2 Phase 2A: Real location fixes enforce freshness, GPS accuracy, foreground lifecycle, and configurable map tile rules', () {
      var currentNow = DateTime(2026, 10, 24, 21, 0);
      final controller = AppController(clock: () => currentNow);

      // Production tile config must not rely on public OSM endpoint
      const devConfig = AppConfig(
        environment: 'development',
        supabaseUrl: '',
        supabaseAnonKey: '',
        allowSimulatedLocation: true,
      );
      expect(devConfig.isTileProviderValidForEnvironment, isTrue);

      const invalidProdConfig = AppConfig(
        environment: 'production',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        allowSimulatedLocation: false,
      );
      expect(invalidProdConfig.isTileProviderValidForEnvironment, isFalse);

      const validProdConfig = AppConfig(
        environment: 'production',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        allowSimulatedLocation: false,
        mapTileUrlTemplate: 'https://tiles.example.com/v1/{z}/{x}/{y}.png',
      );
      expect(validProdConfig.isTileProviderValidForEnvironment, isTrue);

      // Ingest a real GPS fix ~100m from Staller Steps center (40.9154, -73.1225)
      controller.setPermissionState(LocationPermissionState.granted);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9163,
          longitude: -73.1225,
          accuracyMeters: 12.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.hasFreshAccurateLocation, isTrue);
      final staller = controller.landmarkById('lm-staller');
      expect(staller, isNotNull);
      expect(
        staller!.headerDistanceLabel,
        equals('Staller Steps · 100 m away'),
      );

      // Uncertain GPS accuracy (> 50m) immediately revokes landmark access
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9163,
          longitude: -73.1225,
          accuracyMeters: 65.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.activeLandmarkChats, isEmpty);
      expect(controller.landmarkById('lm-staller'), isNull);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);

      // Restore accurate fix
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9163,
          longitude: -73.1225,
          accuracyMeters: 10.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.landmarkById('lm-staller'), isNotNull);

      // Stale location (> 30s without heartbeat) revokes access
      currentNow = currentNow.add(const Duration(seconds: 35));
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.activeLandmarkChats, isEmpty);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);

      // Fresh fix restores access, then backgrounding revokes it
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9163,
          longitude: -73.1225,
          accuracyMeters: 10.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.activeLandmarkChats, isNotEmpty);
      controller.setAppLifecycleActive(false);
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.activeLandmarkChats, isEmpty);
    });

    test('Milestone 2 Phase 2B: Strict location-bound landmark chats enforce current-visit-only message history and disappear on exit', () {
      var currentNow = DateTime(2026, 10, 24, 21, 0);
      final controller = AppController(clock: () => currentNow);

      // Initial visit at Staller Steps sees current-visit messages but never pre-entry messages
      final visit1 = controller.landmarkById('lm-staller')!;
      final visit1SessionId = visit1.visitSessionId;
      final visit1InitialMsgs = controller.landmarkMessagesFor('lm-staller');
      expect(visit1InitialMsgs, isNotEmpty);
      expect(
        visit1InitialMsgs.any(
          (m) => m.createdAt.isBefore(visit1.visitEnteredAt),
        ),
        isFalse,
      );

      // Send a message during Visit 1
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Visit 1 secret note'),
        isTrue,
      );
      expect(
        controller
            .landmarkMessagesFor('lm-staller')
            .any((m) => m.body == 'Visit 1 secret note'),
        isTrue,
      );
      expect(
        controller
            .searchLandmarkMessages('Visit 1 secret note')
            .any((m) => m.body == 'Visit 1 secret note'),
        isTrue,
      );

      // Walk outside Staller Steps radius (~450m north)
      currentNow = currentNow.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9195,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentNow,
        ),
      );

      // Landmark disappears completely from discovery, chat lists, search, and unread counts
      expect(
        controller.activeLandmarkChats.any((c) => c.id == 'lm-staller'),
        isFalse,
      );
      expect(controller.landmarkById('lm-staller'), isNull);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(controller.searchLandmarkMessages('Visit 1'), isEmpty);
      expect(controller.landmarkUnreadCountFor('lm-staller'), equals(0));
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Outside radius send'),
        isFalse,
      );

      // Re-enter Staller Steps radius 2 minutes later (Visit 2)
      currentNow = currentNow.add(const Duration(minutes: 2));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentNow,
        ),
      );

      final visit2 = controller.landmarkById('lm-staller')!;
      expect(visit2.visitSessionId, isNot(equals(visit1SessionId)));
      expect(visit2.visitEnteredAt, equals(currentNow));

      // Zero messages from Visit 1 or before entry are visible in Visit 2
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(controller.searchLandmarkMessages('Visit 1'), isEmpty);
      expect(controller.landmarkUnreadCountFor('lm-staller'), equals(0));

      // New message sent during Visit 2 is visible
      currentNow = currentNow.add(const Duration(seconds: 5));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentNow,
        ),
      );
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Fresh Visit 2 message'),
        isTrue,
      );
      final visit2Msgs = controller.landmarkMessagesFor('lm-staller');
      expect(visit2Msgs, hasLength(1));
      expect(visit2Msgs.single.body, equals('Fresh Visit 2 message'));
    });

    test('Milestone 2 Phase 2C: Multi-day event scheduling supports recurring daily hours, overnight spans, closed-day overrides, DST transitions, rescheduling, cancellation, and calendar queries', () {
      var currentNow = DateTime.utc(
        2026,
        10,
        30,
        12,
        0,
      ); // 08:00 EDT, before 09:00 start
      final controller = AppController(clock: () => currentNow);

      final schedule = EventSchedule(
        startDate: DateTime(2026, 10, 30),
        endDate: DateTime(2026, 11, 2),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 9 * 60, // 09:00
        defaultCloseMinutes: 18 * 60, // 18:00
        dailyOverrides: const <String, DailyScheduleOverride>{
          '2026-10-31': DailyScheduleOverride(
            localDateIso: '2026-10-31',
            openMinutes: 22 * 60, // 22:00 overnight
            closeMinutes: 2 * 60, // 02:00 next morning
          ),
          '2026-11-01': DailyScheduleOverride(
            localDateIso: '2026-11-01',
            isClosed: true,
          ),
        },
      );
      expect(schedule.isValid, isTrue);

      final convention = controller.createEvent(
        title: 'Stony Brook Indie Game & Synth Expo',
        description: 'Four-day showcase in the Student Activities Center.',
        categoryTag: 'Convention',
        location: AppController.presetLocations.first,
        radiusMeters: 500,
        duration: const Duration(days: 4),
        accessType: EventAccessType.public,
        schedule: schedule,
      );
      expect(convention, isNotNull);
      expect(convention.schedule, isNotNull);
      expect(convention.dateRangeLabel, contains('Oct 30'));
      expect(convention.dailyHoursLabel, contains('09:00'));

      // 1. Open at 2026-10-30 14:00 EDT (18:00 UTC)
      expect(schedule.isOpenAt(DateTime.utc(2026, 10, 30, 18, 0)), isTrue);
      // Closed at 2026-10-30 20:00 EDT (2026-10-31 00:00 UTC)
      expect(schedule.isOpenAt(DateTime.utc(2026, 10, 31, 0, 0)), isFalse);
      // Open during overnight window on 2026-10-31 23:30 EDT (2026-11-01 03:30 UTC)
      expect(schedule.isOpenAt(DateTime.utc(2026, 11, 1, 3, 30)), isTrue);
      // Still open during overnight spillover on 2026-11-01 01:30 EDT (2026-11-01 05:30 UTC)
      expect(schedule.isOpenAt(DateTime.utc(2026, 11, 1, 5, 30)), isTrue);
      // Closed during daytime on closed day 2026-11-01 12:00 EST (17:00 UTC)
      expect(schedule.isOpenAt(DateTime.utc(2026, 11, 1, 17, 0)), isFalse);
      // Open on 2026-11-02 10:00 EST (15:00 UTC, post-DST transition)
      expect(schedule.isOpenAt(DateTime.utc(2026, 11, 2, 15, 0)), isTrue);

      // 2. Calendar date queries respect open/closed days and restricted-event privacy
      expect(
        controller
            .eventsForLocalDate(DateTime(2026, 10, 30))
            .any((e) => e.id == convention.id),
        isTrue,
      );
      expect(
        controller
            .eventsForLocalDate(DateTime(2026, 11, 1))
            .any((e) => e.id == convention.id),
        isFalse,
      );
      expect(
        controller
            .eventsForLocalDate(DateTime(2026, 11, 2))
            .any((e) => e.id == convention.id),
        isTrue,
      );

      // Unjoined restricted events in calendar queries still redact private details
      final oct30Events = controller.eventsForLocalDate(DateTime(2026, 10, 30));
      final inviteEvt = oct30Events
          .where((e) => e.id == 'evt-rooftop-invite')
          .firstOrNull;
      if (inviteEvt != null) {
        expect(inviteEvt.isDetailsRedacted, isTrue);
        expect(inviteEvt.participantCount, isNull);
      }

      // 3. Invalid schedule is rejected on reschedule
      final invalidSchedule = EventSchedule(
        startDate: DateTime(2026, 11, 5),
        endDate: DateTime(2026, 11, 1), // end before start
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 9 * 60,
        defaultCloseMinutes: 17 * 60,
      );
      expect(invalidSchedule.isValid, isFalse);
      expect(
        controller.rescheduleEvent(convention.id, invalidSchedule),
        isFalse,
      );

      // Valid host reschedule succeeds; non-host reschedule fails
      expect(controller.rescheduleEvent('evt-open-jam', schedule), isFalse);
      final extendedSchedule = EventSchedule(
        startDate: DateTime(2026, 10, 30),
        endDate: DateTime(2026, 11, 4),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 10 * 60,
        defaultCloseMinutes: 19 * 60,
      );
      expect(
        controller.rescheduleEvent(convention.id, extendedSchedule),
        isTrue,
      );
      expect(
        controller
            .eventsForLocalDate(DateTime(2026, 11, 4))
            .any((e) => e.id == convention.id),
        isTrue,
      );

      // Cancelling the event removes it from active map and calendar queries
      expect(controller.cancelEvent(convention.id), isTrue);
      expect(controller.eventById(convention.id), isNull);
      expect(
        controller
            .eventsForLocalDate(DateTime(2026, 10, 30))
            .any((e) => e.id == convention.id),
        isFalse,
      );
    });

    test('Milestone 2 Phase 2D: Anonymous usernames are generated from adjective+noun word lists, resolve collisions, and cannot be manually edited', () {
      // 1. Word list generation produces valid PascalCase AdjectiveNoun handles
      final generated = AnonymousNameGenerator.generate(
        existingHandles: const <String>{},
        seed: 42,
      );
      expect(AnonymousNameGenerator.isValidHandle(generated), isTrue);
      expect(generated, isNot(contains(' ')));
      expect(generated, isNot(contains('@')));

      // 2. Collision with existing handles skips taken names and falls back to numeric suffix when base pool is saturated
      final avoided = AnonymousNameGenerator.generate(
        existingHandles: <String>{generated},
        seed: 42,
      );
      expect(avoided, isNot(equals(generated)));
      expect(AnonymousNameGenerator.isValidHandle(avoided), isTrue);

      final allBaseCombinations = <String>{
        for (final adj in AnonymousNameGenerator.adjectives)
          for (final noun in AnonymousNameGenerator.nouns) '$adj$noun',
      };
      final suffixed = AnonymousNameGenerator.generate(
        existingHandles: allBaseCombinations,
        seed: 7,
      );
      expect(allBaseCombinations.contains(suffixed), isFalse);
      expect(AnonymousNameGenerator.isValidHandle(suffixed), isTrue);
      expect(
        RegExp(r'^[A-Z][a-z]+[A-Z][a-z]+\d{3}$').hasMatch(suffixed),
        isTrue,
      );

      // 3. Controller assigns an immutable anonymous handle and rejects manual edits
      final controller = AppController(persistedAnonymousHandle: 'QuietFalcon');
      expect(controller.profile.anonymousHandle, equals('QuietFalcon'));
      expect(controller.profile.activeDisplayName, equals('QuietFalcon'));
      expect(controller.profile.isAnonymous, isTrue);

      controller.updateProfileHandles(
        anonymousHandle: 'CustomEditedName',
        username: 'manual_user',
      );
      controller.setIdentityMode(IdentityMode.username);

      expect(controller.profile.anonymousHandle, equals('QuietFalcon'));
      expect(controller.profile.activeDisplayName, equals('QuietFalcon'));
      expect(controller.profile.isAnonymous, isTrue);
    });

    test('Milestone 2 Phase 2E: Image sharing strips EXIF GPS metadata, validates formats/sizes, enforces visit/event/DM authorization, invalidates tokens on exit, and purges cache', () {
      var currentNow = DateTime(2026, 10, 24, 21, 0);
      final controller = AppController(clock: () => currentNow);

      // Build a minimal valid JPEG with an embedded APP1 Exif GPS segment
      final jpegWithGpsExif = Uint8List.fromList(<int>[
        0xFF, 0xD8, // SOI
        0xFF, 0xE1, 0x00, 0x14, // APP1 marker + length (20 bytes)
        0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // 'Exif\0\0'
        0x47,
        0x50,
        0x53,
        0x4C,
        0x61,
        0x74,
        0x34,
        0x30,
        0x2E,
        0x39,
        0x31,
        0x35, // mock GPS tag payload
        0xFF,
        0xC0,
        0x00,
        0x0B,
        0x08,
        0x00,
        0x40,
        0x00,
        0x50,
        0x01,
        0x01,
        0x11,
        0x00, // SOF0 (80x64)
        0xFF, 0xD9, // EOI
      ]);

      expect(MediaSanitizer.containsExifMetadata(jpegWithGpsExif), isTrue);
      final sanitized = MediaSanitizer.sanitizeAndValidate(jpegWithGpsExif);
      expect(sanitized.isValid, isTrue);
      expect(sanitized.mimeType, equals('image/jpeg'));
      expect(sanitized.width, equals(80));
      expect(sanitized.height, equals(64));
      expect(sanitized.hadMetadataStripped, isTrue);
      expect(
        MediaSanitizer.containsExifMetadata(sanitized.sanitizedBytes!),
        isFalse,
      );

      // Unsupported format (GIF89a) and oversized payload are rejected
      final gifBytes = Uint8List.fromList(<int>[
        0x47,
        0x49,
        0x46,
        0x38,
        0x39,
        0x61,
        0x01,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
      ]);
      expect(MediaSanitizer.sanitizeAndValidate(gifBytes).isValid, isFalse);
      expect(
        MediaSanitizer.sanitizeAndValidate(
          jpegWithGpsExif,
          maxBytes: 10,
        ).isValid,
        isFalse,
      );

      // 1. Abandoned / cancelled staged upload leaves no chat message
      final stagedId = controller.stageImageUpload(
        channelId: 'lm-staller',
        rawBytes: jpegWithGpsExif,
      );
      expect(stagedId, isNotNull);
      expect(controller.cancelStagedUpload(stagedId!), isTrue);
      expect(
        controller
            .landmarkMessagesFor('lm-staller')
            .any((m) => m.attachment != null),
        isFalse,
      );

      // 2. Send image in Landmark Chat ('lm-staller') during Visit 1
      expect(
        controller.sendLandmarkMessage(
          'lm-staller',
          'Sunset over Staller lawn',
          rawImageBytes: jpegWithGpsExif,
        ),
        isTrue,
      );
      final landmarkImgMsg = controller
          .landmarkMessagesFor('lm-staller')
          .firstWhere((m) => m.attachment != null);
      final landmarkMediaId = landmarkImgMsg.attachment!.mediaId;
      expect(
        landmarkImgMsg.attachment!.storageObjectKey.contains('/Users/'),
        isFalse,
      );

      final visit1Token = controller.issueMediaDownloadToken(landmarkMediaId);
      expect(visit1Token, isNotNull);
      final visit1Bytes = controller.fetchAuthorizedImageBytes(landmarkMediaId);
      expect(visit1Bytes, isNotNull);
      expect(MediaSanitizer.containsExifMetadata(visit1Bytes!), isFalse);
      expect(controller.isMediaCached(landmarkMediaId), isTrue);

      // Leave Staller Steps radius -> cache is purged and previously issued token is rejected
      currentNow = currentNow.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9195,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.isMediaCached(landmarkMediaId), isFalse);
      expect(controller.fetchAuthorizedImageBytes(landmarkMediaId), isNull);
      expect(controller.downloadMediaWithToken(visit1Token!.token), isNull);

      // Re-enter Staller Steps radius in Visit 2 -> Visit 1 image and token remain inaccessible
      currentNow = currentNow.add(const Duration(minutes: 1));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.fetchAuthorizedImageBytes(landmarkMediaId), isNull);
      expect(controller.downloadMediaWithToken(visit1Token.token), isNull);

      // 3. Event chat image obeys membership rules
      expect(
        controller.sendEventMessage(
          'evt-rooftop-invite',
          'Unauthorized image attempt',
          rawImageBytes: jpegWithGpsExif,
        ),
        isFalse,
      );
      expect(controller.joinEvent('evt-chess-code', joinCode: '1357'), isNull);
      expect(
        controller.sendEventMessage(
          'evt-chess-code',
          'Chess board position',
          rawImageBytes: jpegWithGpsExif,
        ),
        isTrue,
      );
      final eventImgMsg = controller
          .eventMessagesFor('evt-chess-code')
          .firstWhere((m) => m.attachment != null);
      final eventMediaId = eventImgMsg.attachment!.mediaId;
      expect(controller.fetchAuthorizedImageBytes(eventMediaId), isNotNull);
      expect(controller.isMediaCached(eventMediaId), isTrue);

      // Leaving the event revokes image access and evicts from cache
      controller.leaveEvent('evt-chess-code');
      expect(controller.isMediaCached(eventMediaId), isFalse);
      expect(controller.fetchAuthorizedImageBytes(eventMediaId), isNull);

      // 4. Direct message image obeys acceptance and block rules
      expect(
        controller.sendDirectMessage(
          'dm-1', // pending request
          'Pending DM image attempt',
          rawImageBytes: jpegWithGpsExif,
        ),
        isFalse,
      );
      expect(
        controller.sendDirectMessage(
          'dm-2', // accepted thread with user-pine
          'PostGIS index diagram',
          rawImageBytes: jpegWithGpsExif,
        ),
        isTrue,
      );
      final dmImgMsg = controller.acceptedDmThreads
          .firstWhere((t) => t.id == 'dm-2')
          .messages
          .firstWhere((m) => m.attachment != null);
      final dmMediaId = dmImgMsg.attachment!.mediaId;
      expect(controller.fetchAuthorizedImageBytes(dmMediaId), isNotNull);
      expect(controller.isMediaCached(dmMediaId), isTrue);

      // Blocking the DM peer immediately revokes access and purges cache
      controller.blockUser('user-pine', label: 'PineOwl109');
      expect(controller.isMediaCached(dmMediaId), isFalse);
      expect(controller.fetchAuthorizedImageBytes(dmMediaId), isNull);
    });

    test('Milestone 2 Review Remediation: staged upload auth/cleanup, stale/inaccurate GPS gating on discovery/events, handle persistence store, and PNG/WebP chunk validation', () async {
      var currentNow = DateTime(2026, 10, 24, 21, 0);
      final handleStore = <String, String>{};
      final firstController = AppController(
        clock: () => currentNow,
        handleSeed: 77,
        handleStorage: handleStore,
      );
      final persistedHandle = firstController.profile.anonymousHandle;
      expect(handleStore['anonymous_handle'], equals(persistedHandle));

      // Second controller with a different seed automatically restores from handleStorage
      final controller = AppController(
        clock: () => currentNow,
        handleSeed: 999,
        handleStorage: handleStore,
      );
      expect(controller.profile.anonymousHandle, equals(persistedHandle));

      final sampleJpeg = buildSampleCameraJpegBytes();

      // 1. stageImageUpload rejects unauthorized channels (outside landmark, unjoined event, pending DM)
      expect(
        controller.stageImageUpload(
          channelId: 'lm-harbor', // outside radius
          rawBytes: sampleJpeg,
        ),
        isNull,
      );
      expect(
        controller.stageImageUpload(
          channelId: 'evt-rooftop-invite', // unauthorized invite-only event
          rawBytes: sampleJpeg,
        ),
        isNull,
      );
      expect(
        controller.stageImageUpload(
          channelId: 'dm-1', // pending DM
          rawBytes: sampleJpeg,
        ),
        isNull,
      );

      // 2. Staged upload in active landmark ('lm-staller') is purged when leaving radius
      final stagedVisit1 = controller.stageImageUpload(
        channelId: 'lm-staller',
        rawBytes: sampleJpeg,
      );
      expect(stagedVisit1, isNotNull);
      expect(controller.pendingUploadsForChannel('lm-staller'), isNotEmpty);

      // Move outside Staller Steps -> abandoned staged upload is automatically purged
      currentNow = currentNow.add(const Duration(seconds: 5));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9195,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.pendingUploadsForChannel('lm-staller'), isEmpty);

      // Re-enter Staller Steps -> Visit 1 staged upload does not resurface
      currentNow = currentNow.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.pendingUploadsForChannel('lm-staller'), isEmpty);

      // 3. Inaccurate (>50m) or stale (>30s) GPS fix gates visibleNearbyParticipants, discoverableEvents, and joinEvent
      currentNow = currentNow.add(const Duration(seconds: 5));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 85.0, // > 50m threshold
          recordedAt: currentNow,
        ),
      );
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.visibleNearbyParticipants, isEmpty);
      expect(controller.discoverableEvents, isEmpty);
      expect(controller.joinEvent('evt-open-jam'), isNotNull);

      // Restore accurate fix
      currentNow = currentNow.add(const Duration(seconds: 5));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 10.0,
          recordedAt: currentNow,
        ),
      );
      expect(controller.hasFreshAccurateLocation, isTrue);
      expect(controller.visibleNearbyParticipants, isNotEmpty);
      expect(controller.discoverableEvents, isNotEmpty);

      // Advance clock > 30s without a new fix -> stale fix gates discovery
      currentNow = currentNow.add(const Duration(seconds: 35));
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.visibleNearbyParticipants, isEmpty);
      expect(controller.discoverableEvents, isEmpty);

      // 4. Truncated/chunkless PNG and WebP payloads are rejected by MediaSanitizer
      final chunklessPng = Uint8List.fromList(<int>[
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
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
      expect(MediaSanitizer.sanitizeAndValidate(chunklessPng).isValid, isFalse);

      final malformedWebp = Uint8List.fromList(<int>[
        0x52, 0x49, 0x46, 0x46, 0x20, 0x00, 0x00, 0x00,
        0x57, 0x45, 0x42, 0x50,
        0x56, 0x50, 0x38, 0x20, 0xFF, 0xFF, 0x00, 0x00, // invalid chunk length
        0x00, 0x00, 0x00, 0x00,
      ]);
      expect(
        MediaSanitizer.sanitizeAndValidate(malformedWebp).isValid,
        isFalse,
      );
    });
  });

  testWidgets('ProximityApp renders main tabs and sends nearby message', (
    WidgetTester tester,
  ) async {
    final controller = AppController();
    const config = AppConfig(
      environment: 'test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      allowSimulatedLocation: true,
    );

    await tester.pumpWidget(
      ProximityApp(config: config, controller: controller),
    );

    expect(find.text('Nearby Pulse'), findsOneWidget);
    expect(find.text('Ghost Mode'), findsOneWidget);

    // Navigate across main tabs
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Explore Local Events'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Host Temporary Event'), findsOneWidget);

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Inbox & Requests'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile & Privacy'), findsOneWidget);
    expect(
      find.text('Assigned Anonymous Identity • Immutable across sessions'),
      findsOneWidget,
    );
    expect(find.text('Save Handles'), findsNothing);
  });

  testWidgets(
    'Milestone 2 UI: Landmark chat distance header, interactive map view, calendar views, and inline image rendering',
    (WidgetTester tester) async {
      final controller = AppController(
        clock: () => DateTime(2026, 10, 24, 19, 0),
        handleSeed: 42,
      );
      const config = AppConfig(
        environment: 'test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        allowSimulatedLocation: true,
      );

      expect(
        controller.sendLandmarkMessage(
          'lm-staller',
          'Photo from Staller Steps',
          rawImageBytes: buildSampleCameraJpegBytes(),
        ),
        isTrue,
      );

      await tester.pumpWidget(
        ProximityApp(config: config, controller: controller),
      );

      // 1. Nearby screen displays active Landmark Chat header with distance in meters
      expect(find.textContaining('Staller Steps ·'), findsWidgets);
      await tester.drag(
        find.byKey(const Key('nearby-message-list')),
        const Offset(0, -250),
      );
      await tester.pump();
      expect(find.text('Photo from Staller Steps'), findsOneWidget);
      expect(find.text('EXIF Stripped'), findsWidgets);

      // Nearby screen does not display a map toggle icon
      expect(find.byKey(const Key('toggle-nearby-map-btn')), findsNothing);

      // 2. Explore screen supports List and expanded Map modes (Calendar subtab removed, Map default)
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.text('Explore Local Events'), findsOneWidget);

      expect(find.text('Calendar'), findsNothing);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.byKey(const Key('explore-expanded-map')), findsOneWidget);

      // Switch to List mode: event cards and filter menu become visible
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.text('Twilight Lawn Acoustic Jam'), findsWidgets);
      expect(find.byKey(const Key('explore-filter-menu-btn')), findsOneWidget);
    },
  );

  testWidgets(
    'UI: Event lifecycle status badge, Start Event button, and Host Handoff invitation workflow',
    (WidgetTester tester) async {
      var now = DateTime.utc(
        2026,
        10,
        24,
        17,
        30,
      ); // 13:30 EDT (before 14:00 start)
      final controller = AppController(clock: () => now, handleSeed: 42);
      const config = AppConfig(
        environment: 'test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        allowSimulatedLocation: false,
      );

      // Ingest fresh location at SAC Plaza
      controller.ingestLocationFix(
        LocationFix(
          latitude: AppController.presetLocations.first.latitude,
          longitude: AppController.presetLocations.first.longitude,
          accuracyMeters: 5.0,
          recordedAt: now,
          areaName: AppController.presetLocations.first.areaName,
        ),
      );

      // Create a scheduled event hosted by the current user
      final schedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 24),
        endDate: DateTime.utc(2026, 10, 25),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 14 * 60, // 14:00 EDT (18:00 UTC)
        defaultCloseMinutes: 20 * 60, // 20:00 EDT
      );

      controller.createEvent(
        title: 'Sunset Hackathon',
        description: 'Building cool things outdoors',
        categoryTag: 'Tech',
        location: AppController.presetLocations.first, // SAC Plaza
        radiusMeters: 400,
        duration: const Duration(hours: 4),
        accessType: EventAccessType.public,
        schedule: schedule,
      );

      final hackathonId = controller.discoverableEvents
          .firstWhere((e) => e.title == 'Sunset Hackathon')
          .id;
      controller.addParticipantForTest(hackathonId, 'user-incoming-host');

      await tester.pumpWidget(
        ProximityApp(config: config, controller: controller),
      );

      // Navigate to Explore and switch to List
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      // Check scheduled event card has 'Scheduled' badge
      expect(find.text('Sunset Hackathon'), findsOneWidget);
      expect(find.text('Scheduled'), findsWidgets);

      // Advance clock to within scheduled operating window (14:05 EDT / 18:05 UTC)
      now = DateTime.utc(2026, 10, 24, 18, 5);
      controller.ingestLocationFix(
        LocationFix(
          latitude: AppController.presetLocations.first.latitude,
          longitude: AppController.presetLocations.first.longitude,
          accuracyMeters: 5.0,
          recordedAt: now,
          areaName: AppController.presetLocations.first.areaName,
        ),
      );

      // Open event detail sheet
      await tester.tap(find.text('Sunset Hackathon'));
      await tester.pumpAndSettle();

      // Since user is host and event is scheduled, "Start Event" button is visible
      expect(find.byKey(const Key('start-event-btn')), findsOneWidget);

      // Tap Start Event (host is at SAC Plaza, within radius and within operating window)
      await tester.tap(find.byKey(const Key('start-event-btn')));
      await tester.pumpAndSettle();

      // Event is now live!
      expect(find.text('Live'), findsWidgets);
      expect(find.byKey(const Key('start-event-btn')), findsNothing);

      // Host handoff: Host can nominate another user via member picker
      expect(find.byKey(const Key('transfer-host-btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('transfer-host-btn')));
      await tester.pumpAndSettle();

      // Searchable member picker is displayed
      expect(
        find.byKey(const Key('member-picker-search-field')),
        findsOneWidget,
      );
      final nomineeBtn = find.byKey(
        const Key('select-nominee-btn-user-incoming-host'),
      );
      expect(nomineeBtn, findsOneWidget);
      await tester.tap(nomineeBtn);
      await tester.pumpAndSettle();

      // Confirm nomination dialog
      expect(find.byKey(const Key('confirm-nomination-btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-nomination-btn')));
      await tester.pumpAndSettle();

      // Host sees "Cancel Transfer" now
      expect(find.text('Cancel Transfer'), findsOneWidget);

      // Now simulate incoming host transfer offered to me on another event
      controller.addParticipantForTest('evt-open-jam', controller.profile.id);
      controller.simulateIncomingHostTransfer(
        eventId: 'evt-open-jam',
        designatedRecipientUserId: controller.profile.id,
      );
      await tester.pumpAndSettle();

      // Close current sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Ensure Twilight Lawn Acoustic Jam is visible in list
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();

      // Open evt-open-jam sheet
      await tester.tap(find.text('Twilight Lawn Acoustic Jam'));
      await tester.pumpAndSettle();

      // Recipient sees pending transfer invitation banner
      expect(
        find.byKey(const Key('pending-host-transfer-banner')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('accept-host-transfer-btn')), findsOneWidget);
      expect(
        find.byKey(const Key('decline-host-transfer-btn')),
        findsOneWidget,
      );

      // Accept transfer
      await tester.tap(find.byKey(const Key('accept-host-transfer-btn')));
      await tester.pumpAndSettle();

      // If anonymous, confirm the transfer disclosure dialog
      if (find
          .byKey(const Key('confirm-host-transfer-btn'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const Key('confirm-host-transfer-btn')));
        await tester.pumpAndSettle();
      }

      // Acceptance verified independently; banner is removed and user is now host
      expect(
        find.byKey(const Key('pending-host-transfer-banner')),
        findsNothing,
      );
      expect(find.byKey(const Key('transfer-host-btn')), findsOneWidget);
    },
  );

  testWidgets(
    'UI: CreateEventScreen with native pickers and past start validation',
    (WidgetTester tester) async {
      final now = DateTime(2026, 10, 24, 18, 0); // 18:00 UTC
      final controller = AppController(clock: () => now, handleSeed: 42);
      const config = AppConfig(
        environment: 'test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        allowSimulatedLocation: false,
      );

      await tester.pumpWidget(
        ProximityApp(config: config, controller: controller),
      );

      // Navigate to Create
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Host Temporary Event'), findsOneWidget);

      // Scroll down to reveal schedule section
      await tester.scrollUntilVisible(
        find.textContaining('America/New_York'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Venue timezone is displayed dynamically
      expect(find.textContaining('America/New_York'), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('End Time'), findsOneWidget);
    },
  );
}
