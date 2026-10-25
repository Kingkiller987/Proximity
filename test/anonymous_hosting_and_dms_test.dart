import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/events/events_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Slice 3: Anonymous Identity & Event-Hosting / DM Rules', () {
    test('1. Creating event in anonymous mode always publishes host as public @username', () {
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => t0);

      // Verify user is in anonymous mode
      expect(controller.profile.isAnonymous, isTrue);
      expect(controller.profile.activeDisplayName, isNot(startsWith('@')));

      // Create event
      final event = controller.createEvent(
        title: 'Public Identity Concert',
        description: 'Hosted concert by anonymous user',
        categoryTag: 'Music',
        location: const GeoPoint(
          latitude: 40.9154,
          longitude: -73.1225,
          areaName: 'Staller Steps',
        ),
        radiusMeters: 100,
        duration: const Duration(hours: 2),
        accessType: EventAccessType.public,
      );

      // Host display name MUST be public @username
      expect(event.hostDisplayName, equals('@${controller.profile.username}'));
      expect(event.hostDisplayName, isNot(contains('#')));

      // Retrieve via controller
      final retrieved = controller.eventById(event.id);
      expect(retrieved, isNotNull);
      expect(
        retrieved!.hostDisplayName,
        equals('@${controller.profile.username}'),
      );
    });

    test('4. Sending DM from anonymous user displays public username in DM request and messages', () {
      final t0 = DateTime(2026, 10, 25, 12, 0, 0);
      final controller = AppController(clock: () => t0);

      // Verify anonymous mode is on
      expect(controller.profile.isAnonymous, isTrue);

      // Send DM request to user-harbor (no pre-existing thread)
      final err = controller.sendDmRequest(
        toUserId: 'user-harbor',
        toDisplayName: '@harbor_scout',
        introMessage: 'Hello from user!',
      );
      expect(err, isNull);

      final req = controller.pendingDmRequests.firstWhere(
        (r) => r.fromUserId == controller.profile.id,
      );
      expect(req.fromDisplayName, equals('@${controller.profile.username}'));
      expect(req.fromIsAnonymous, isFalse);

      // Simulate thread acceptance and send a message
      controller.simulateAcceptedDmThreadForTest(req.id);

      final sent = controller.sendDirectMessage(
        req.id,
        'Follow-up direct message',
      );
      expect(sent, isTrue);

      final thread = controller.acceptedDmThreads.firstWhere(
        (t) => t.id == req.id,
      );
      expect(
        thread.messages.last.senderDisplayName,
        equals('@${controller.profile.username}'),
      );
      expect(thread.messages.last.senderDisplayName, isNot(contains('#')));
    });

    test('5. Seeded DM fixtures only use public identities for DM senders', () {
      final controller = AppController();
      final thread = controller.acceptedDmThreads.firstWhere(
        (t) => t.id == 'dm-2',
      );

      expect(thread.fromDisplayName, equals('@pine_owl'));
      expect(thread.fromIsAnonymous, isFalse);
      expect(thread.messages.first.senderDisplayName, equals('@pine_owl'));
    });

    testWidgets(
      '2 & 3. Anonymous user accepting host transfer requires confirmation and assigns public name',
      (tester) async {
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

        // Switch to anonymous mode
        controller.setAnonymousMode(true);
        expect(controller.profile.isAnonymous, isTrue);

        // Create an event hosted by user-hana and add user-me
        controller.addParticipantForTest('evt-open-jam', controller.profile.id);
        controller.simulateIncomingHostTransfer(
          eventId: 'evt-open-jam',
          designatedRecipientUserId: controller.profile.id,
        );

        final event = controller.eventById('evt-open-jam');
        expect(event, isNotNull);
        expect(event!.isPendingHostTransferForMe, isTrue);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EventDetailSheet(
                controller: controller,
                eventId: 'evt-open-jam',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Accept Host Role"
        final acceptBtn = find.byKey(const Key('accept-host-transfer-btn'));
        expect(acceptBtn, findsOneWidget);
        await tester.tap(acceptBtn);
        await tester.pumpAndSettle();

        // Warning dialog appears explaining public profile exposure
        expect(
          find.byKey(const Key('anonymous-host-transfer-confirm-dialog')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Your public profile (@${controller.profile.username}) will be visible as the host',
          ),
          findsOneWidget,
        );

        // 1. Test Cancel
        await tester.tap(find.byKey(const Key('cancel-host-transfer-btn')));
        await tester.pumpAndSettle();

        // Not transferred yet
        expect(
          controller.eventById('evt-open-jam')!.hostId,
          equals('user-hana'),
        );

        // 2. Test Confirm & Accept
        await tester.tap(acceptBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('confirm-host-transfer-btn')));
        await tester.pumpAndSettle();

        // Ownership transferred! Host display name is public @username
        final updatedEvent = controller.eventById('evt-open-jam')!;
        expect(updatedEvent.hostId, equals(controller.profile.id));
        expect(
          updatedEvent.hostDisplayName,
          equals('@${controller.profile.username}'),
        );

        // Anonymous mode for nearby chats was NOT altered
        expect(controller.profile.isAnonymous, isTrue);
      },
    );
  });
}
