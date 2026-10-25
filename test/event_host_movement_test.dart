import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/events/host_movement_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Slice 2: Independent Event Locations & Host Movement Prompt', () {
    test('1. Event location is stored independently and displayed at its coordinates', () {
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

      final customCoords = const GeoPoint(
        latitude: 40.9200,
        longitude: -73.1300,
        areaName: 'North P-Lot Gazebo',
      );

      final createdEvent = controller.createEvent(
        title: 'Independent Tailgate',
        description: 'Independent coordinates test event',
        categoryTag: 'Social',
        location: customCoords,
        radiusMeters: 150,
        duration: const Duration(hours: 2),
        accessType: EventAccessType.public,
      );

      final eventId = createdEvent.id;
      final created = controller.eventById(eventId);
      expect(created, isNotNull);
      expect(created!.location!.latitude, equals(40.9200));
      expect(created.location!.longitude, equals(-73.1300));
      expect(created.location!.areaName, equals('North P-Lot Gazebo'));
    });

    test('2 & 6. Host moving outside event radius triggers prompt; dismissing prevents re-prompting', () {
      var currentTime = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => currentTime);

      final eventLocation = const GeoPoint(
        latitude: 40.9154,
        longitude: -73.1225,
        areaName: 'Staller Steps',
      );

      // Host is at Staller Steps
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Staller Steps',
        ),
      );

      final createdEvent = controller.createEvent(
        title: 'Lawn Concert',
        description: 'Hosted concert',
        categoryTag: 'Music',
        location: eventLocation,
        radiusMeters: 100,
        duration: const Duration(hours: 2),
        accessType: EventAccessType.public,
      );
      final eventId = createdEvent.id;
      final startErr = controller.startEvent(eventId);
      expect(startErr, isNull);
      expect(controller.pendingHostMovementEventId, isNull);

      // Host moves ~200 meters away (outside 100m radius, but still within campus/study-code radius)
      currentTime = currentTime.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9140,
          longitude: -73.1240,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Campus Pathway',
        ),
      );

      // Should trigger pending host movement prompt
      expect(controller.pendingHostMovementEventId, equals(eventId));

      // Dismissing the prompt clears pending status
      controller.dismissHostMovementPrompt(eventId);
      expect(controller.pendingHostMovementEventId, isNull);

      // Event is still active and location is unchanged
      final event = controller.eventById(eventId);
      expect(event, isNotNull);
      expect(event!.isEnded, isFalse);
      expect(event.location!.latitude, equals(40.9154));

      // Another fix at the same departed area does NOT re-prompt because it was dismissed
      currentTime = currentTime.add(const Duration(seconds: 5));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9139,
          longitude: -73.1241,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Campus Pathway',
        ),
      );
      expect(controller.pendingHostMovementEventId, isNull);

      // Host returns inside the radius
      currentTime = currentTime.add(const Duration(seconds: 5));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Staller Steps',
        ),
      );
      expect(controller.pendingHostMovementEventId, isNull);

      // Host departs AGAIN -> should prompt again!
      currentTime = currentTime.add(const Duration(seconds: 5));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9140,
          longitude: -73.1240,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Campus Pathway',
        ),
      );
      expect(controller.pendingHostMovementEventId, equals(eventId));
    });

    test('3. Host choosing "Move Event" updates event location and alerts participants', () {
      var currentTime = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => currentTime);

      final eventLocation = const GeoPoint(
        latitude: 40.9154,
        longitude: -73.1225,
        areaName: 'Staller Steps',
      );

      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Staller Steps',
        ),
      );

      final createdEvent = controller.createEvent(
        title: 'Moving Group',
        description: 'Test move',
        categoryTag: 'Social',
        location: eventLocation,
        radiusMeters: 100,
        duration: const Duration(hours: 2),
        accessType: EventAccessType.public,
      );
      final eventId = createdEvent.id;
      expect(controller.startEvent(eventId), isNull);

      // Add another participant
      controller.addParticipantForTest(eventId, 'user-hana');

      // Move outside
      currentTime = currentTime.add(const Duration(seconds: 10));
      final newPoint = const GeoPoint(
        latitude: 40.9175,
        longitude: -73.1210,
        areaName: 'Student Union',
      );
      controller.ingestLocationFix(
        LocationFix(
          latitude: newPoint.latitude,
          longitude: newPoint.longitude,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: newPoint.areaName,
        ),
      );
      expect(controller.pendingHostMovementEventId, equals(eventId));

      // Execute "Move Event" to current location
      final moved = controller.moveEventLocation(
        eventId,
        controller.currentLocation,
      );
      expect(moved, isTrue);
      expect(controller.pendingHostMovementEventId, isNull);

      final updatedEvent = controller.eventById(eventId);
      expect(updatedEvent!.location!.areaName, equals('Student Union'));
      expect(updatedEvent.locationMoveCount, equals(1));

      // Alert was generated for attendees
      final alerts = controller.eventAlerts;
      expect(
        alerts.any(
          (a) => a.contains('Host moved "Moving Group" to Student Union'),
        ),
        isTrue,
      );
    });

    test('4. Host choosing "Transfer Ownership" designates candidate without ending event', () {
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

      final createdEvent = controller.createEvent(
        title: 'Handoff Event',
        description: 'Testing handoff',
        categoryTag: 'Social',
        location: const GeoPoint(
          latitude: 40.9154,
          longitude: -73.1225,
          areaName: 'Staller Steps',
        ),
        radiusMeters: 100,
        duration: const Duration(hours: 2),
        accessType: EventAccessType.public,
      );
      final eventId = createdEvent.id;
      expect(controller.startEvent(eventId), isNull);

      controller.addParticipantForTest(eventId, 'user-hana');

      // Host moves outside
      currentTime = currentTime.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9180,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Campus Center',
        ),
      );
      expect(controller.pendingHostMovementEventId, equals(eventId));

      // Initiate transfer to attendee user-hana
      final transferInitiated = controller.initiateHostTransfer(
        eventId,
        'user-hana',
      );
      expect(transferInitiated, isTrue);

      final event = controller.eventById(eventId);
      expect(event!.pendingHostTransferUserId, equals('user-hana'));
      expect(event.isEnded, isFalse);
    });

    test('5. Host choosing "End Event" marks event ended and clears pending prompt', () {
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

      final createdEvent = controller.createEvent(
        title: 'Ending Event',
        description: 'Testing end',
        categoryTag: 'Social',
        location: const GeoPoint(
          latitude: 40.9154,
          longitude: -73.1225,
          areaName: 'Staller Steps',
        ),
        radiusMeters: 100,
        duration: const Duration(hours: 2),
        accessType: EventAccessType.public,
      );
      final eventId = createdEvent.id;
      expect(controller.startEvent(eventId), isNull);

      currentTime = currentTime.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9180,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentTime,
          areaName: 'Campus Center',
        ),
      );
      expect(controller.pendingHostMovementEventId, equals(eventId));

      // Choose "End Event"
      final ended = controller.endEvent(eventId);
      expect(ended, isTrue);
      expect(controller.pendingHostMovementEventId, isNull);

      final event = controller.eventById(eventId);
      // Ended event is not active
      expect(event == null || event.isEnded, isTrue);
    });

    test('7. Stale or inaccurate host fix does NOT trigger pending prompt', () {
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

      final createdEvent = controller.createEvent(
        title: 'Accuracy Test Event',
        description: 'Testing accuracy guard',
        categoryTag: 'Social',
        location: const GeoPoint(
          latitude: 40.9154,
          longitude: -73.1225,
          areaName: 'Staller Steps',
        ),
        radiusMeters: 100,
        duration: const Duration(hours: 2),
        accessType: EventAccessType.public,
      );
      expect(createdEvent.id, isNotEmpty);

      // Inaccurate fix (> 50m) far away
      currentTime = currentTime.add(const Duration(seconds: 10));
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9250,
          longitude: -73.1225,
          accuracyMeters: 65.0,
          recordedAt: currentTime,
          areaName: 'Distant Inaccurate Point',
        ),
      );
      expect(controller.pendingHostMovementEventId, isNull);

      // Stale fix (> 30s) far away
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9250,
          longitude: -73.1225,
          accuracyMeters: 8.0,
          recordedAt: currentTime.subtract(const Duration(seconds: 45)),
          areaName: 'Distant Stale Point',
        ),
      );
      expect(controller.pendingHostMovementEventId, isNull);
    });

    testWidgets(
      '8. HostMovementDialog UI displays 3 choices plus dismiss and handles actions',
      (tester) async {
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

        final createdEvent = controller.createEvent(
          title: 'Dialog Test Event',
          description: 'Testing dialog UI',
          categoryTag: 'Social',
          location: const GeoPoint(
            latitude: 40.9154,
            longitude: -73.1225,
            areaName: 'Staller Steps',
          ),
          radiusMeters: 100,
          duration: const Duration(hours: 2),
          accessType: EventAccessType.public,
        );
        final eventId = createdEvent.id;
        controller.startEvent(eventId);

        // Trigger departure
        currentTime = currentTime.add(const Duration(seconds: 10));
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9140,
            longitude: -73.1240,
            accuracyMeters: 8.0,
            recordedAt: currentTime,
            areaName: 'Campus Pathway',
          ),
        );
        expect(controller.pendingHostMovementEventId, equals(eventId));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => HostMovementDialog.show(
                    context,
                    controller: controller,
                    eventId: eventId,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('host-movement-dialog')), findsOneWidget);
        expect(find.text('Host Departure Detected'), findsOneWidget);
        expect(
          find.textContaining(
            'You have moved outside the event boundary for "Dialog Test Event".',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('host-move-action-move')), findsOneWidget);
        expect(
          find.byKey(const Key('host-move-action-transfer')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('host-move-action-end')), findsOneWidget);
        expect(
          find.byKey(const Key('host-move-action-cancel')),
          findsOneWidget,
        );

        // Tap Dismiss
        await tester.tap(find.byKey(const Key('host-move-action-cancel')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('host-movement-dialog')), findsNothing);
        expect(controller.pendingHostMovementEventId, isNull);
      },
    );
  });
}
