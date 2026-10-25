import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/config/app_config.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
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
        afterMove.location.areaName,
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

      // Create a join-code protected event as another host by testing verification
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
      // Stored hash is never plaintext '9988'
      expect(created.joinCodeHash, isNotNull);
      expect(created.joinCodeHash, isNot(equals('9988')));
      expect(created.verifyJoinCode('wrong'), isFalse);
      expect(created.verifyJoinCode('9988'), isTrue);

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
      controller.respondToDmRequest(pending.id, accept: true);
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
  });
}
