import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/config/app_config.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/main.dart';

void main() {
  group('Landmark Chat History & Session Lifecycle Acceptance Criteria', () {
    test('Criterion 1: A -> B -> A preserves A\'s messages when A remains eligible', () {
      final controller = AppController();
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      controller.setMockNow(t0);

      // Location at Staller Steps center: within both lm-staller (180m) and lm-sbu-campus (800m)
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      // 1. Select Landmark A (lm-staller) and send a message
      expect(controller.selectLandmark('lm-staller'), isTrue);
      final sentA = controller.sendLandmarkMessage(
        'lm-staller',
        'Hello from Landmark A',
      );
      expect(sentA, isTrue);

      final messagesA1 = controller.landmarkMessagesFor('lm-staller');
      expect(messagesA1.any((m) => m.body == 'Hello from Landmark A'), isTrue);

      // 2. Switch to Landmark B (lm-sbu-campus) and send a message
      expect(controller.selectLandmark('lm-sbu-campus'), isTrue);
      final sentB = controller.sendLandmarkMessage(
        'lm-sbu-campus',
        'Hello from Landmark B',
      );
      expect(sentB, isTrue);

      final messagesB = controller.landmarkMessagesFor('lm-sbu-campus');
      expect(messagesB.any((m) => m.body == 'Hello from Landmark B'), isTrue);

      // 3. Switch back to Landmark A without losing eligibility
      expect(controller.selectLandmark('lm-staller'), isTrue);
      final messagesA2 = controller.landmarkMessagesFor('lm-staller');
      expect(
        messagesA2.any((m) => m.body == 'Hello from Landmark A'),
        isTrue,
        reason: 'Switching chats must not terminate visit; existing messages from the same visit must be preserved.',
      );
      expect(
        controller.nearbyMessages.any((m) => m.body == 'Hello from Landmark A'),
        isTrue,
      );
    });

    test('Criterion 2: A -> town/campus -> A preserves independent visits and messages when both remain eligible', () {
      final controller = AppController();
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      controller.setMockNow(t0);

      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      // Small venue landmark (lm-staller)
      controller.selectLandmark('lm-staller');
      controller.sendLandmarkMessage('lm-staller', 'Venue note');

      // Broad campus landmark (lm-sbu-campus)
      controller.selectLandmark('lm-sbu-campus');
      controller.sendLandmarkMessage('lm-sbu-campus', 'Campus-wide note');

      // Verify independent history across multiple switches
      controller.selectLandmark('lm-staller');
      var stallerMsgs = controller.landmarkMessagesFor('lm-staller');
      expect(stallerMsgs.any((m) => m.body == 'Venue note'), isTrue);
      expect(stallerMsgs.any((m) => m.body == 'Campus-wide note'), isFalse);

      controller.selectLandmark('lm-sbu-campus');
      var campusMsgs = controller.landmarkMessagesFor('lm-sbu-campus');
      expect(campusMsgs.any((m) => m.body == 'Campus-wide note'), isTrue);
      expect(campusMsgs.any((m) => m.body == 'Venue note'), isFalse);

      controller.selectLandmark('lm-staller');
      stallerMsgs = controller.landmarkMessagesFor('lm-staller');
      expect(stallerMsgs.any((m) => m.body == 'Venue note'), isTrue);
    });

    testWidgets(
      'Criterion 3: Navigating away (tabs/profile/events) preserves history if eligibility remains valid',
      (WidgetTester tester) async {
        final t0 = DateTime(2026, 10, 25, 12, 0, 0);
        final controller = AppController(clock: () => t0, handleSeed: 42);
        controller.setMockNow(t0);
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: t0,
            areaName: 'Staller Steps',
          ),
        );

        const config = AppConfig(
          environment: 'test',
          supabaseUrl: '',
          supabaseAnonKey: '',
          allowSimulatedLocation: true,
        );

        await tester.pumpWidget(
          ProximityApp(config: config, controller: controller),
        );
        await tester.pumpAndSettle();

        // Send a message in Nearby
        final sent = controller.sendLandmarkMessage(
          'lm-staller',
          'Persistent message across navigation',
        );
        expect(sent, isTrue, reason: 'sendLandmarkMessage must succeed');
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Persistent message across navigation',
            skipOffstage: false,
          ),
          findsOneWidget,
        );

        // 1. Navigate to Explore
        await tester.tap(find.text('Explore'));
        await tester.pumpAndSettle();
        expect(find.text('Explore Local Events'), findsOneWidget);

        // 2. Navigate to Create
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(find.text('Host Temporary Event'), findsOneWidget);

        // 3. Navigate to Inbox
        await tester.tap(find.text('Inbox'));
        await tester.pumpAndSettle();
        expect(find.text('Inbox & Requests'), findsOneWidget);

        // 4. Navigate to Profile
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.text('Profile & Privacy'), findsOneWidget);

        // 5. Navigate back to Nearby
        await tester.tap(find.text('Nearby'));
        await tester.pumpAndSettle();

        // Message must still be displayed
        expect(
          find.text(
            'Persistent message across navigation',
            skipOffstage: false,
          ),
          findsOneWidget,
        );

        // 6. Switch to "Events You're In" view
        await tester.tap(find.byKey(const Key('nearby-events-tab')));
        await tester.pumpAndSettle();

        // 7. Switch back to "Nearby Chats" view
        await tester.tap(find.byKey(const Key('nearby-chats-tab')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Persistent message across navigation',
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      },
    );

    test('Criterion 4: Leaving A\'s radius invalidates A\'s visit; re-entering creates fresh session without old messages', () {
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

      controller.sendLandmarkMessage('lm-staller', 'Message from Visit 1');
      expect(
        controller
            .landmarkMessagesFor('lm-staller')
            .any((m) => m.body == 'Message from Visit 1'),
        isTrue,
      );

      // Leave A's radius (move to Port Jefferson Harbor pier, ~5 km away)
      final tExit = t0.add(const Duration(minutes: 5));
      controller.setMockNow(tExit);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9465,
          longitude: -73.0691,
          accuracyMeters: 8.0,
          recordedAt: tExit,
          areaName: 'Port Jefferson Harbor Pier',
        ),
      );

      // Chat A is now inaccessible
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(
        controller.activeLandmarkChats.any((c) => c.id == 'lm-staller'),
        isFalse,
      );
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Should fail'),
        isFalse,
      );

      // Re-enter Staller Steps (Visit 2)
      final tReenter = t0.add(const Duration(minutes: 15));
      controller.setMockNow(tReenter);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: tReenter,
          areaName: 'Staller Steps',
        ),
      );

      // Messages from Visit 1 must NOT be restored
      final visit2Messages = controller.landmarkMessagesFor('lm-staller');
      expect(
        visit2Messages.any((m) => m.body == 'Message from Visit 1'),
        isFalse,
        reason: 'Old visit messages must never leak into a new visit',
      );

      // New message sent in Visit 2 is visible
      controller.sendLandmarkMessage('lm-staller', 'Message from Visit 2');
      final updatedVisit2 = controller.landmarkMessagesFor('lm-staller');
      expect(
        updatedVisit2.any((m) => m.body == 'Message from Visit 2'),
        isTrue,
      );
    });

    test('Criterion 5: Stale (>30s), inaccurate (>50m), missing, or revoked location fix blocks landmark history access', () {
      final controller = AppController();
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      controller.setMockNow(t0);

      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );
      controller.sendLandmarkMessage('lm-staller', 'Active landmark note');
      expect(controller.landmarkMessagesFor('lm-staller'), isNotEmpty);

      // 5a. Stale location fix (> 30s)
      final tStale = t0.add(const Duration(seconds: 31));
      controller.setMockNow(tStale);
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(controller.activeLandmarkChats, isEmpty);
      expect(controller.nearbyMessages, isEmpty);
      expect(controller.sendNearbyMessage('Blocked stale send'), isFalse);
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Blocked stale send'),
        isFalse,
      );

      // Restore fresh accurate location fix
      final tFresh = tStale.add(const Duration(seconds: 1));
      controller.setMockNow(tFresh);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: tFresh,
          areaName: 'Staller Steps',
        ),
      );
      expect(controller.hasFreshAccurateLocation, isTrue);

      // 5b. Inaccurate GPS (> 50m)
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 65.0,
          recordedAt: tFresh,
          areaName: 'Staller Steps',
        ),
      );
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(controller.activeLandmarkChats, isEmpty);

      // 5c. Revoked location permission
      controller.setPermissionState(LocationPermissionState.denied);
      expect(controller.hasLocationAccess, isFalse);
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);

      // 5d. Background lifecycle state
      controller.setPermissionState(LocationPermissionState.granted);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: tFresh,
          areaName: 'Staller Steps',
        ),
      );
      expect(controller.hasFreshAccurateLocation, isTrue);
      controller.setAppLifecycleActive(false);
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
    });

    test('Criterion 6: Two simultaneously eligible landmarks maintain independent sessions', () {
      final controller = AppController();
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      controller.setMockNow(t0);

      // User at Staller Steps (inside both lm-staller and lm-sbu-campus)
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      final staller = controller.landmarkById('lm-staller');
      final campus = controller.landmarkById('lm-sbu-campus');
      expect(staller, isNotNull);
      expect(campus, isNotNull);

      // Distinct visit sessions
      expect(staller!.visitSessionId, isNot(equals(campus!.visitSessionId)));

      controller.sendLandmarkMessage('lm-staller', 'Only for Staller');
      controller.sendLandmarkMessage('lm-sbu-campus', 'Only for Campus');

      final stallerMsgs = controller.landmarkMessagesFor('lm-staller');
      final campusMsgs = controller.landmarkMessagesFor('lm-sbu-campus');

      expect(stallerMsgs.any((m) => m.body == 'Only for Staller'), isTrue);
      expect(stallerMsgs.any((m) => m.body == 'Only for Campus'), isFalse);

      expect(campusMsgs.any((m) => m.body == 'Only for Campus'), isTrue);
      expect(campusMsgs.any((m) => m.body == 'Only for Staller'), isFalse);
    });

    test('Criterion 7: Leaving A\'s radius invalidates A without invalidating still-eligible B', () {
      final controller = AppController();
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      controller.setMockNow(t0);

      // Start inside both lm-staller (180m) and lm-sbu-campus (800m)
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );

      controller.sendLandmarkMessage('lm-staller', 'Staller visit message');
      controller.sendLandmarkMessage('lm-sbu-campus', 'Campus visit message');

      expect(controller.landmarkMessagesFor('lm-staller'), isNotEmpty);
      expect(controller.landmarkMessagesFor('lm-sbu-campus'), isNotEmpty);

      // Move to Campus North Probe: (40.9175, -73.1230)
      // Distance to Staller Steps is ~237m (> 180m radius -> outside A)
      // Distance to Campus center is ~278m (<= 800m radius -> inside B)
      final tProbe = t0.add(const Duration(seconds: 15));
      controller.setMockNow(tProbe);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9175,
          longitude: -73.1230,
          accuracyMeters: 8.0,
          recordedAt: tProbe,
          areaName: 'Campus North Probe',
        ),
      );

      // A (lm-staller) must be invalidated
      expect(
        controller.activeLandmarkChats.any((c) => c.id == 'lm-staller'),
        isFalse,
      );
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Should fail'),
        isFalse,
      );

      // B (lm-sbu-campus) remains eligible and retains its message history!
      expect(
        controller.activeLandmarkChats.any((c) => c.id == 'lm-sbu-campus'),
        isTrue,
      );
      final campusMsgs = controller.landmarkMessagesFor('lm-sbu-campus');
      expect(
        campusMsgs.any((m) => m.body == 'Campus visit message'),
        isTrue,
        reason: 'Invalidating A must not automatically invalidate B if B remains eligible',
      );
    });

    test('Criterion 8: Ghost Mode blocks nearby chats while preserving access to eligible joined event chats; disabling Ghost Mode requires fresh location fix to restore access', () {
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => t0);

      // User is at Staller Steps, authorized for joined event evt-open-jam
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: t0,
          areaName: 'Staller Steps',
        ),
      );
      expect(controller.joinEvent('evt-open-jam'), isNull);

      // Send a landmark message and an event message
      controller.sendLandmarkMessage('lm-staller', 'Pre-ghost landmark note');
      controller.sendEventMessage(
        'evt-open-jam',
        'Pre-ghost event announcement',
      );

      expect(
        controller
            .landmarkMessagesFor('lm-staller')
            .any((m) => m.body == 'Pre-ghost landmark note'),
        isTrue,
      );
      expect(
        controller
            .eventMessagesFor('evt-open-jam')
            .any((m) => m.body == 'Pre-ghost event announcement'),
        isTrue,
      );

      // 1. Enable Ghost Mode
      controller.setGhostMode(true);
      expect(controller.profile.isGhostMode, isTrue);

      // Nearby proximity chats are completely unavailable
      expect(controller.canParticipateInNearby, isFalse);
      expect(controller.activeLandmarkChats, isEmpty);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);
      expect(controller.nearbyMessages, isEmpty);
      expect(controller.sendNearbyMessage('Blocked ghost message'), isFalse);
      expect(
        controller.sendLandmarkMessage('lm-staller', 'Blocked ghost message'),
        isFalse,
      );

      // Joined event chats REMAIN ACCESSIBLE subject to their existing rules
      expect(controller.isAuthorizedForEvent('evt-open-jam'), isTrue);
      final eventMsgs = controller.eventMessagesFor('evt-open-jam');
      expect(
        eventMsgs.any((m) => m.body == 'Pre-ghost event announcement'),
        isTrue,
      );
      expect(
        controller.sendEventMessage(
          'evt-open-jam',
          'Event message while in Ghost Mode',
        ),
        isTrue,
      );

      // 2. Advance time past location fix freshness window (> 30s)
      final tStale = t0.add(const Duration(seconds: 40));
      controller.setMockNow(tStale);

      // 3. Disable Ghost Mode while location fix is stale
      controller.setGhostMode(false);
      expect(controller.profile.isGhostMode, isFalse);

      // Fresh eligibility check fails because GPS fix is stale (>30s)
      // Access must NOT be restored without a fresh location fix!
      expect(controller.hasFreshAccurateLocation, isFalse);
      expect(controller.activeLandmarkChats, isEmpty);
      expect(controller.landmarkMessagesFor('lm-staller'), isEmpty);

      // 4. Ingest a fresh, accurate GPS fix inside Staller Steps
      final tFresh = tStale.add(const Duration(seconds: 1));
      controller.setMockNow(tFresh);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: tFresh,
          areaName: 'Staller Steps',
        ),
      );

      // Fresh eligibility check succeeds and starts a NEW visit session
      expect(controller.hasFreshAccurateLocation, isTrue);
      expect(controller.canParticipateInNearby, isTrue);
      expect(
        controller.activeLandmarkChats.any((c) => c.id == 'lm-staller'),
        isTrue,
      );

      // Crucial: Old messages sent before Ghost Mode must NOT be restored!
      final freshVisitMessages = controller.landmarkMessagesFor('lm-staller');
      expect(
        freshVisitMessages.any((m) => m.body == 'Pre-ghost landmark note'),
        isFalse,
        reason: 'Disabling Ghost Mode must not restore an expired visit without fresh eligibility checks; old visit messages remain inaccessible.',
      );

      // New message sent after re-enabling is visible
      controller.sendLandmarkMessage(
        'lm-staller',
        'Fresh note after ghost mode',
      );
      expect(
        controller
            .landmarkMessagesFor('lm-staller')
            .any((m) => m.body == 'Fresh note after ghost mode'),
        isTrue,
      );
    });
  });
}
