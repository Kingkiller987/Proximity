import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Slice 1: Ghost Mode Chat History Preservation', () {
    test('1 & 2. Toggling Ghost Mode while remaining in range preserves chat messages and does not reset session or sequence', () {
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => t0);

      // Enter Staller Steps landmark with valid fix
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      expect(controller.canParticipateInNearby, isTrue);
      expect(
        controller.activeLandmarkChats.any((c) => c.id == 'lm-staller'),
        isTrue,
      );

      // Send a message during this visit
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Hello from active visit'),
        isTrue,
      );
      final msgsBeforeGhost = controller.landmarkMessagesFor('lm-staller');
      expect(
        msgsBeforeGhost.any((m) => m.body == 'Hello from active visit'),
        isTrue,
      );
      final visitIdBeforeGhost = controller.activeVisitSessionIdFor(
        'lm-staller',
      );
      expect(visitIdBeforeGhost, isNotNull);

      // Turn Ghost Mode ON (while still in range)
      controller.setGhostMode(true);
      expect(controller.profile.isGhostMode, isTrue);

      // Nearby participation is blocked while Ghost Mode is on
      expect(controller.canParticipateInNearby, isFalse);
      expect(controller.activeLandmarkChats, isEmpty);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(controller.sendNearbyMessage('Attempt while ghost'), isFalse);
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Attempt while ghost'),
        isFalse,
      );

      // Turn Ghost Mode OFF while STILL in range with fresh fix
      controller.setGhostMode(false);
      expect(controller.profile.isGhostMode, isFalse);
      expect(controller.canParticipateInNearby, isTrue);

      // Same visit session is preserved; no duplicate session created
      final visitIdAfterGhost = controller.activeVisitSessionIdFor(
        'lm-staller',
      );
      expect(visitIdAfterGhost, equals(visitIdBeforeGhost));

      // The previous messages from the visit remain accessible!
      final msgsAfterGhost = controller.landmarkMessagesFor('lm-staller');
      expect(
        msgsAfterGhost.any((m) => m.body == 'Hello from active visit'),
        isTrue,
      );

      // New messages sent in the restored visit are also visible
      expect(
        controller.sendLandmarkMessage(
          'lm-staller',
          'Follow-up after unmasking',
        ),
        isTrue,
      );
      final finalMsgs = controller.landmarkMessagesFor('lm-staller');
      expect(finalMsgs.length, equals(msgsBeforeGhost.length + 1));
      expect(
        finalMsgs.any((m) => m.body == 'Follow-up after unmasking'),
        isTrue,
      );
    });

    test('3. Ghost Mode blocks Nearby participation while enabled', () {
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => t0);

      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      controller.setGhostMode(true);
      expect(controller.canParticipateInNearby, isFalse);
      expect(controller.activeLandmarkChats, isEmpty);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(controller.sendNearbyMessage('Blocked text'), isFalse);
    });

    test('4. Joined event chat remains accessible during Ghost Mode', () {
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => t0);

      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      // Join open jam event
      final joinErr = controller.joinEvent('evt-open-jam');
      expect(joinErr, isNull);
      expect(controller.isAuthorizedForEvent('evt-open-jam'), isTrue);

      // Enable Ghost Mode
      controller.setGhostMode(true);

      // Nearby is blocked, but joined event chat is fully available
      expect(controller.canParticipateInNearby, isFalse);
      expect(controller.isAuthorizedForEvent('evt-open-jam'), isTrue);
      expect(
        controller.sendEventMessage(
          'evt-open-jam',
          'Event discussion in Ghost Mode',
        ),
        isTrue,
      );
      final eventMsgs = controller.eventMessagesFor('evt-open-jam');
      expect(
        eventMsgs.any((m) => m.body == 'Event discussion in Ghost Mode'),
        isTrue,
      );
    });

    test('5. Actually leaving the landmark radius terminates visit and boundaries messages', () {
      var currentTime = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => currentTime);

      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Staller Steps',
        ),
      );
      controller.sendLandmarkMessage('lm-staller', 'Before leaving note');
      final session1 = controller.activeVisitSessionIdFor('lm-staller');

      // Enable Ghost Mode
      controller.setGhostMode(true);

      // Move outside Staller Steps radius (> 200m away, e.g. Student Union 40.9175, -73.1210)
      currentTime = currentTime.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9175,
          longitude: -73.1210,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Student Union',
        ),
      );

      // Disable Ghost Mode
      controller.setGhostMode(false);
      expect(controller.activeVisitSessionIdFor('lm-staller'), isNull);

      // Return to Staller Steps
      currentTime = currentTime.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Staller Steps',
        ),
      );

      final session2 = controller.activeVisitSessionIdFor('lm-staller');
      expect(session2, isNotNull);
      expect(session2, isNot(equals(session1)));

      // Past visit messages are NOT accessible in the new visit
      final freshMsgs = controller.landmarkMessagesFor('lm-staller');
      expect(freshMsgs.any((m) => m.body == 'Before leaving note'), isFalse);
    });

    test(
      '6. Stale, inaccurate, or revoked location does not grant Nearby access',
      () {
        final t0 = DateTime(2026, 10, 25, 12, 0, 0);
        final controller = AppController(clock: () => t0);

        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: t0,
            areaName: 'Staller Steps',
          ),
        );
        controller.sendLandmarkMessage('lm-staller', 'Valid fix message');

        // Inaccurate fix (> 50m)
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 65.0,
            recordedAt: t0.add(const Duration(seconds: 5)),
            areaName: 'Staller Steps',
          ),
        );
        expect(controller.hasFreshAccurateLocation, isFalse);
        expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);

        // Stale fix (> 30s)
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: t0.subtract(const Duration(seconds: 40)),
            areaName: 'Staller Steps',
          ),
        );
        expect(controller.hasFreshAccurateLocation, isFalse);
        expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);

        // Revoked permission
        controller.setPermissionState(LocationPermissionState.denied);
        expect(controller.hasFreshAccurateLocation, isFalse);
        expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      },
    );
  });
}
