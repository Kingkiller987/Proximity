import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';

void main() {
  group('Phase 1: Core Models & Formatting', () {
    test('UserProfile supports real bio, avatarBytes, and copyWith without breaking defaults', () {
      const profile = UserProfile(
        id: 'user-test',
        anonymousHandle: 'SilentLynx#881',
        username: 'AlexRider',
        identityMode: IdentityMode.anonymous,
        visibleInNearby: true,
        ghostBrowseNearby: false,
        nearbyRadiusMeters: 500,
        messageRetentionHours: 24,
      );

      expect(profile.bio, equals(''));
      expect(profile.avatarBytes, isNull);

      final avatarData = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final updated = profile.copyWith(
        bio: 'Explorer & Coffee Enthusiast',
        avatarBytes: avatarData,
      );

      expect(updated.bio, equals('Explorer & Coffee Enthusiast'));
      expect(updated.avatarBytes, equals(avatarData));
      expect(updated.username, equals('AlexRider'));
      expect(updated.anonymousHandle, equals('SilentLynx#881'));
    });

    test('PublicIdentityProjection structurally isolates private identity for anonymous users', () {
      final avatarData = Uint8List.fromList(<int>[10, 20, 30]);
      final anonProfile = UserProfile(
        id: 'user-anon',
        anonymousHandle: 'PineOwl#109',
        username: 'SecretAgent',
        bio: 'Top secret bio that must never leak',
        avatarBytes: avatarData,
        identityMode: IdentityMode.anonymous,
        visibleInNearby: true,
        ghostBrowseNearby: false,
        nearbyRadiusMeters: 500,
        messageRetentionHours: 24,
      );

      final anonProjection = PublicIdentityProjection.fromProfile(anonProfile);
      expect(anonProjection.userId, equals('user-anon'));
      expect(anonProjection.displayName, equals('PineOwl#109'));
      expect(anonProjection.bio, equals("I'm anonymous."));
      expect(anonProjection.avatarBytes, isNull);
      expect(anonProjection.isAnonymous, isTrue);

      // Verify real identity mode projection
      final realProfile = anonProfile.copyWith(identityMode: IdentityMode.real);
      final realProjection = PublicIdentityProjection.fromProfile(realProfile);
      expect(realProjection.userId, equals('user-anon'));
      expect(realProjection.displayName, equals('@SecretAgent'));
      expect(realProjection.bio, equals('Top secret bio that must never leak'));
      expect(realProjection.avatarBytes, equals(avatarData));
      expect(realProjection.isAnonymous, isFalse);
    });

    test('formatMessageTimestamp formats sent times cleanly for today vs prior dates', () {
      final now = DateTime(2026, 10, 25, 22, 42); // 10:42 PM
      final earlierToday = DateTime(2026, 10, 25, 9, 15);
      expect(formatMessageTimestamp(earlierToday, now), equals('9:15 AM'));

      final yesterday = DateTime(2026, 10, 24, 22, 42);
      expect(
        formatMessageTimestamp(yesterday, now),
        equals('Oct 24, 10:42 PM'),
      );

      final earlierMonth = DateTime(2026, 9, 12, 14, 5);
      expect(
        formatMessageTimestamp(earlierMonth, now),
        equals('Sep 12, 2:05 PM'),
      );
    });
  });

  group('Phase 1: Anonymous Mode Transitions & DM Unmasking Boundary', () {
    test(
      'Anonymous toggle regenerates handle only on actual OFF -> ON transition',
      () {
        final controller = AppController();
        // Clear active hosted event so anonymous mode transitions can be exercised
        controller.endEvent('evt-study-code');

        // Initially anonymous
        final initialHandle = controller.profile.anonymousHandle;
        expect(controller.profile.isAnonymous, isTrue);

        // Calling setAnonymousMode(true) while already anonymous must NOT change handle
        final changedSame = controller.setAnonymousMode(true);
        expect(changedSame, isFalse);
        expect(controller.profile.anonymousHandle, equals(initialHandle));

        // Toggle to real (OFF)
        final turnedReal = controller.setAnonymousMode(false);
        expect(turnedReal, isTrue);
        expect(controller.profile.isAnonymous, isFalse);

        // Toggle back to anonymous (OFF -> ON transition) -> generates a fresh random handle
        final turnedAnon = controller.setAnonymousMode(true);
        expect(turnedAnon, isTrue);
        expect(controller.profile.isAnonymous, isTrue);
        expect(controller.profile.anonymousHandle, isNotEmpty);
        expect(
          controller.profile.anonymousHandle,
          isNot(equals(initialHandle)),
        );
      },
    );

    test('Asymmetric DM unmasking: anonymous sender real profile attached ONLY to request for recipient', () {
      final controller = AppController();
      // Ensure sender is anonymous with real profile info populated
      final avatarData = Uint8List.fromList(<int>[99, 100, 101]);
      controller.updateRealProfile(
        username: 'AlexTheReal',
        bio: 'Real Alex Bio',
        avatarBytes: avatarData,
      );
      controller.setIdentityMode(IdentityMode.anonymous);

      final sendErr = controller.sendDmRequest(
        toUserId: 'user-harbor',
        introMessage: 'Ahoy Sailor Dan, it is Alex!',
      );
      expect(sendErr, isNull);

      final request = controller.pendingDmRequests.firstWhere(
        (r) => r.toUserId == 'user-harbor',
      );
      // DM requests always use the sender's public identity
      expect(request.fromIsAnonymous, isFalse);
      expect(request.fromDisplayName, equals('@AlexTheReal'));

      // Public projection of the sender in nearby/general discovery preserves their anonymous setting
      final publicSender = controller.publicProjectionForUser(
        controller.profile.id,
      );
      expect(
        publicSender.displayName,
        equals(controller.profile.anonymousHandle),
      );
      expect(publicSender.bio, equals("I'm anonymous."));
      expect(publicSender.avatarBytes, isNull);
      expect(publicSender.isAnonymous, isTrue);
    });

    test('DM senders use public identity; recipient public projection preserves profile privacy', () {
      final controller = AppController();
      // Inspect pre-seeded accepted request 'dm-2' from user 'user-pine' to 'user-me'
      final request = controller.acceptedDmThreads.firstWhere(
        (r) => r.id == 'dm-2',
      );
      expect(request.fromDisplayName, equals('@pine_owl'));
      expect(request.fromIsAnonymous, isFalse);
      // No real identity fields exist on public projection of user-pine
      final recipientPublic = controller.publicProjectionForUser('user-pine');
      expect(recipientPublic.displayName, equals('PineOwl#109'));
      expect(recipientPublic.bio, equals("I'm anonymous."));
      expect(recipientPublic.avatarBytes, isNull);
      expect(recipientPublic.isAnonymous, isTrue);
    });
  });

  group(
    'Phase 1: Deterministic Landmark Hierarchy & Radius Isolation Fixtures',
    () {
      test('Internal landmark hierarchy categories and independent radius evaluation', () {
        final controller = AppController();
        final landmarks = controller.discoverableLandmarks;

        expect(
          landmarks.any((l) => l.category == LandmarkCategory.complex),
          isTrue,
        );
        expect(
          landmarks.any((l) => l.category == LandmarkCategory.venue),
          isTrue,
        );
        expect(
          landmarks.any((l) => l.category == LandmarkCategory.pointOfInterest),
          isTrue,
        );

        final campus = landmarks.firstWhere((l) => l.id == 'lm-sbu-campus');
        expect(campus.radiusMeters, equals(800.0));
        expect(campus.category, equals(LandmarkCategory.complex));

        final staller = landmarks.firstWhere((l) => l.id == 'lm-staller');
        expect(staller.radiusMeters, equals(180.0));
        expect(staller.parentLandmarkId, equals('lm-sbu-campus'));

        final library = landmarks.firstWhere((l) => l.id == 'lm-library');
        expect(library.radiusMeters, equals(160.0));
        expect(library.parentLandmarkId, equals('lm-sbu-campus'));
      });

      test('Deterministic radius isolation: campus presence never confers chat access to child landmarks', () {
        final controller = AppController();

        // Probe position: (40.9175, -73.1230)
        // Campus center: (40.9150, -73.1230) -> distance ~278m (<= 800m -> INSIDE)
        // Staller Steps center: (40.9154, -73.1225) -> distance ~237m (> 180m -> OUTSIDE)
        // Melville Library center: (40.9148, -73.1235) -> distance ~303m (> 160m -> OUTSIDE)
        final probePoint = const GeoPoint(
          latitude: 40.9175,
          longitude: -73.1230,
          areaName: 'Campus North Probe',
        );

        controller.ingestLocationFix(
          LocationFix(
            latitude: probePoint.latitude,
            longitude: probePoint.longitude,
            accuracyMeters: 10.0,
            recordedAt: controller.now,
            areaName: probePoint.areaName,
          ),
        );

        // Eligible chats in activeLandmarkChats
        final eligible = controller.activeLandmarkChats;
        final eligibleIds = eligible.map((c) => c.id).toSet();

        expect(
          eligibleIds.contains('lm-sbu-campus'),
          isTrue,
          reason: 'Probe is within 278m of campus center (<= 800m)',
        );
        expect(
          eligibleIds.contains('lm-staller'),
          isFalse,
          reason: 'Probe is ~237m from Staller Steps (> 180m radius)',
        );
        expect(
          eligibleIds.contains('lm-library'),
          isFalse,
          reason: 'Probe is ~303m from Library (> 160m radius)',
        );

        // Landmark chat access check
        expect(controller.landmarkMessagesFor('lm-sbu-campus'), isNotNull);
        expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
        expect(controller.landmarkMessagesFor('lm-library'), isEmpty);

        // Sending message to child landmark must fail
        final sendSucceeded = controller.sendLandmarkMessage(
          'lm-staller',
          'Should fail: outside radius',
        );
        expect(sendSucceeded, isFalse);
      });
    },
  );

  group('Phase 1: Location Freshness & Current-Visit Isolation', () {
    test('On-demand location freshness terminates active visits after 30s without new GPS fix', () {
      final controller = AppController();
      // Seed location inside Staller Steps (40.9154, -73.1225)
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      controller.setMockNow(t0);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 10.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      expect(
        controller.activeLandmarkChats.any((c) => c.id == 'lm-staller'),
        isTrue,
      );

      // Advance clock 31 seconds past last fix without new GPS update
      controller.setMockNow(t0.add(const Duration(seconds: 31)));

      // Next query revalidates freshness on demand
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.activeLandmarkChats, isEmpty);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Stale send attempt'),
        isFalse,
      );
    });

    test('Re-entering a landmark starts a new visit session; past-visit messages remain inaccessible', () {
      final controller = AppController();
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      controller.setMockNow(t0);

      // Enter Staller Steps (Visit 1)
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      // Send a message during Visit 1
      final sent1 = controller.sendLandmarkMessage(
        'lm-staller',
        'Message from Visit 1',
      );
      expect(sent1, isTrue);
      final visit1Messages = controller.landmarkMessagesFor('lm-staller');
      expect(
        visit1Messages.any((m) => m.body == 'Message from Visit 1'),
        isTrue,
      );

      // Exit landmark zone (Walk 400m away)
      final tExit = t0.add(const Duration(minutes: 5));
      controller.setMockNow(tExit);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9190,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: tExit,
          areaName: 'Outside Staller Steps',
        ),
      );

      // While outside, chat is inaccessible
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);

      // Re-enter Staller Steps (Visit 2) 10 minutes later
      final tReEnter = t0.add(const Duration(minutes: 15));
      controller.setMockNow(tReEnter);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: tReEnter,
          areaName: 'Staller Steps',
        ),
      );

      // Visit 2 messages query: Visit 1 message MUST be inaccessible
      final visit2Messages = controller.landmarkMessagesFor('lm-staller');
      expect(
        visit2Messages.any((m) => m.body == 'Message from Visit 1'),
        isFalse,
        reason: 'Messages from previous visit must never leak into a new visit',
      );

      // New message sent in Visit 2 is visible
      final sent2 = controller.sendLandmarkMessage(
        'lm-staller',
        'Message from Visit 2',
      );
      expect(sent2, isTrue);
      final updatedVisit2 = controller.landmarkMessagesFor('lm-staller');
      expect(
        updatedVisit2.any((m) => m.body == 'Message from Visit 2'),
        isTrue,
      );
    });
  });
}
