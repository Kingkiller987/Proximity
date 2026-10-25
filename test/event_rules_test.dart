import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/events/platform_date_time_picker.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('Scope A: Event Scheduling & Past Validation', () {
    // Fixed reference time: Sunday, Oct 25, 2026 at 14:00:00 EDT (18:00:00 UTC)
    final fixedClockUtc = DateTime.utc(2026, 10, 25, 18, 0, 0);

    test('isStartInPast detects yesterday as past start date', () {
      final yesterdaySchedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 24),
        endDate: DateTime.utc(2026, 10, 24),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 10 * 60, // 10:00 AM
        defaultCloseMinutes: 18 * 60, // 6:00 PM
      );

      expect(yesterdaySchedule.isStartInPast(fixedClockUtc), isTrue);
      expect(
        yesterdaySchedule.validateScheduleAgainst(now: fixedClockUtc),
        contains('past'),
      );
    });

    test('isStartInPast detects earlier time today as past start time in venue timezone', () {
      // 10:00 AM EDT today (fixed clock is 14:00 EDT today)
      final pastTodaySchedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 25),
        endDate: DateTime.utc(2026, 10, 25),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes:
            10 * 60, // 10:00 AM EDT (14:00 UTC, before 18:00 UTC)
        defaultCloseMinutes: 18 * 60,
      );

      expect(pastTodaySchedule.isStartInPast(fixedClockUtc), isTrue);
    });

    test('isStartInPast respects venue timezone correctly (America/Chicago vs America/New_York)', () {
      // At 18:00 UTC:
      // In New York (EDT, UTC-4), it is 14:00 (2:00 PM).
      // In Chicago (CDT, UTC-5), it is 13:00 (1:00 PM).
      // A schedule starting today at 13:30 (1:30 PM):
      // - In New York: 13:30 is 17:30 UTC -> IN THE PAST relative to 18:00 UTC.
      // - In Chicago: 13:30 is 18:30 UTC -> IN THE FUTURE relative to 18:00 UTC!
      final nySchedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 25),
        endDate: DateTime.utc(2026, 10, 25),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 13 * 60 + 30, // 1:30 PM
        defaultCloseMinutes: 18 * 60,
      );

      final chicagoSchedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 25),
        endDate: DateTime.utc(2026, 10, 25),
        venueTimezone: 'America/Chicago',
        defaultOpenMinutes: 13 * 60 + 30, // 1:30 PM
        defaultCloseMinutes: 18 * 60,
      );

      expect(nySchedule.isStartInPast(fixedClockUtc), isTrue);
      expect(chicagoSchedule.isStartInPast(fixedClockUtc), isFalse);
    });

    test('isStartInPast allows future start time today', () {
      // 16:00 EDT today (20:00 UTC, after 18:00 UTC)
      final futureTodaySchedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 25),
        endDate: DateTime.utc(2026, 10, 25),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 16 * 60, // 4:00 PM EDT
        defaultCloseMinutes: 20 * 60,
      );

      expect(futureTodaySchedule.isStartInPast(fixedClockUtc), isFalse);
      expect(
        futureTodaySchedule.validateScheduleAgainst(now: fixedClockUtc),
        isNull,
      );
    });

    test(
      'Preserves multi-day conventions spanning several days without 24h limit',
      () {
        // 4-day convention: Oct 26 to Oct 29, 2026
        final conventionSchedule = EventSchedule(
          startDate: DateTime.utc(2026, 10, 26),
          endDate: DateTime.utc(2026, 10, 29),
          venueTimezone: 'America/New_York',
          defaultOpenMinutes: 9 * 60, // 9:00 AM
          defaultCloseMinutes: 21 * 60, // 9:00 PM
        );

        expect(conventionSchedule.isValid, isTrue);
        expect(conventionSchedule.isStartInPast(fixedClockUtc), isFalse);
        expect(conventionSchedule.dateRangeLabel, 'Oct 26 – Oct 29');
        // Starts on Oct 26 at 09:00 EDT (13:00 UTC)
        expect(
          conventionSchedule.startsAtInstant,
          DateTime.utc(2026, 10, 26, 13, 0),
        );
        // Expires on Oct 29 at 21:00 EDT (Oct 30 01:00 UTC)
        expect(
          conventionSchedule.expiresAtInstant,
          DateTime.utc(2026, 10, 30, 1, 0),
        );
      },
    );

    test('Overnight schedule handles close time on next day correctly', () {
      // 22:00 to 02:00 overnight on Oct 26
      final overnightSchedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 26),
        endDate: DateTime.utc(2026, 10, 26),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 22 * 60, // 10:00 PM EDT
        defaultCloseMinutes: 2 * 60, // 2:00 AM EDT (+1d)
      );

      expect(overnightSchedule.isValid, isTrue);
      expect(overnightSchedule.dailyHoursLabel, contains('(+1d)'));
      // Starts Oct 26 22:00 EDT (Oct 27 02:00 UTC)
      expect(
        overnightSchedule.startsAtInstant,
        DateTime.utc(2026, 10, 27, 2, 0),
      );
      // Expires Oct 27 02:00 EDT (Oct 27 06:00 UTC)
      expect(
        overnightSchedule.expiresAtInstant,
        DateTime.utc(2026, 10, 27, 6, 0),
      );
    });

    test('Handles daylight saving time transition day correctly', () {
      // Fall-back transition: Nov 1, 2026 in America/New_York
      final dstSchedule = EventSchedule(
        startDate: DateTime.utc(2026, 11, 1),
        endDate: DateTime.utc(2026, 11, 1),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 10 * 60,
        defaultCloseMinutes: 16 * 60,
      );

      expect(dstSchedule.isValid, isTrue);
      // On Nov 1, 2026 at 10:00 EST (UTC-5), startsAtInstant is 15:00 UTC
      expect(dstSchedule.startsAtInstant, DateTime.utc(2026, 11, 1, 15, 0));
      // Expires at 16:00 EST (21:00 UTC)
      expect(dstSchedule.expiresAtInstant, DateTime.utc(2026, 11, 1, 21, 0));
    });

    test(
      'AppController.createEvent rejects schedule with start time in the past',
      () {
        final controller = AppController(clock: () => fixedClockUtc);
        final location = const GeoPoint(
          latitude: 40.9151,
          longitude: -73.1231,
          areaName: 'Staller Steps',
          timezone: 'America/New_York',
        );

        final pastSchedule = EventSchedule(
          startDate: DateTime.utc(2026, 10, 25),
          endDate: DateTime.utc(2026, 10, 25),
          venueTimezone: 'America/New_York',
          defaultOpenMinutes:
              10 * 60, // 10:00 AM EDT (in the past relative to 14:00 EDT)
          defaultCloseMinutes: 18 * 60,
        );

        expect(
          () => controller.createEvent(
            title: 'Past Event',
            description: 'Should fail validation',
            categoryTag: 'Testing',
            location: location,
            radiusMeters: 400,
            duration: const Duration(hours: 3),
            accessType: EventAccessType.public,
            schedule: pastSchedule,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('past'),
            ),
          ),
        );
      },
    );

    test('AppController.rescheduleEvent rejects new schedule with start time in the past', () {
      final controller = AppController(clock: () => fixedClockUtc);
      controller.ingestLocationFix(
        LocationFix(
          latitude: 40.9151,
          longitude: -73.1231,
          accuracyMeters: 5,
          recordedAt: fixedClockUtc,
        ),
      );
      final location = const GeoPoint(
        latitude: 40.9151,
        longitude: -73.1231,
        areaName: 'Staller Steps',
        timezone: 'America/New_York',
      );

      // Create valid future event starting at 16:00 EDT
      final futureSchedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 25),
        endDate: DateTime.utc(2026, 10, 25),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 16 * 60,
        defaultCloseMinutes: 20 * 60,
      );

      final event = controller.createEvent(
        title: 'Future Event',
        description: 'Starts at 4pm',
        categoryTag: 'Testing',
        location: location,
        radiusMeters: 400,
        duration: const Duration(hours: 4),
        accessType: EventAccessType.public,
        schedule: futureSchedule,
      );

      // Attempt to reschedule to 10:00 AM EDT (in past)
      final invalidReschedule = EventSchedule(
        startDate: DateTime.utc(2026, 10, 25),
        endDate: DateTime.utc(2026, 10, 25),
        venueTimezone: 'America/New_York',
        defaultOpenMinutes: 10 * 60,
        defaultCloseMinutes: 12 * 60,
      );

      final result = controller.rescheduleEvent(event.id, invalidReschedule);
      expect(result, isFalse);

      // Verify event schedule unchanged
      final reloaded = controller.eventById(event.id);
      expect(reloaded!.schedule!.defaultOpenMinutes, 16 * 60);
    });
  });

  group('Scope B: Host Presence, Scheduled Window & Ownership Handoff', () {
    // Reference time: Sunday, Oct 25, 2026 at 14:00:00 EDT (18:00:00 UTC)
    var clockNow = DateTime.utc(2026, 10, 25, 18, 0, 0);
    final stallerSteps = const GeoPoint(
      latitude: 40.9151,
      longitude: -73.1231,
      areaName: 'Staller Steps',
    );
    final farAwayLocation = const GeoPoint(
      latitude: 40.9462,
      longitude: -73.1065,
      areaName: 'Port Jefferson Harbor', // ~4000m away
    );

    test('startEvent requires host presence and validates scheduled operating window', () {
      final controller = AppController(clock: () => clockNow);
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: clockNow,
        ),
      );

      // 1. Create a scheduled event starting at 16:00 EDT (2 hours in the future)
      final scheduledEvent = controller.createEvent(
        title: 'Sunset Jam Session',
        description: 'Music on the steps',
        categoryTag: 'Music',
        location: stallerSteps,
        radiusMeters: 400,
        duration: const Duration(hours: 3),
        accessType: EventAccessType.public,
        schedule: EventSchedule(
          startDate: DateTime.utc(2026, 10, 25),
          endDate: DateTime.utc(2026, 10, 25),
          venueTimezone: 'America/New_York',
          defaultOpenMinutes: 16 * 60, // 4:00 PM EDT
          defaultCloseMinutes: 19 * 60,
        ),
      );

      expect(scheduledEvent.isStarted, isFalse);
      expect(scheduledEvent.statusAt(clockNow), EventLifecycleStatus.scheduled);

      // 2. Early start rejection: clock is 14:00 EDT, start time is 16:00 EDT
      final earlyStartErr = controller.startEvent(scheduledEvent.id);
      expect(earlyStartErr, contains('before its scheduled start time'));
      expect(controller.eventById(scheduledEvent.id)!.isStarted, isFalse);

      // 3. Fast-forward clock to 16:30 EDT (20:30 UTC), inside scheduled window
      clockNow = DateTime.utc(2026, 10, 25, 20, 30, 0);

      // 4. Host outside radius rejection: host is at Port Jefferson (~4km away)
      controller.ingestLocationFix(
        LocationFix(
          latitude: farAwayLocation.latitude,
          longitude: farAwayLocation.longitude,
          accuracyMeters: 5,
          recordedAt: clockNow,
        ),
      );
      final outsideRadiusErr = controller.startEvent(scheduledEvent.id);
      expect(outsideRadiusErr, contains('Host presence required'));
      expect(outsideRadiusErr, contains('must be within 400m'));
      expect(controller.eventById(scheduledEvent.id)!.isStarted, isFalse);

      // 5. Stale GPS rejection
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: clockNow.subtract(
            const Duration(minutes: 5),
          ), // 5 min old > 30s
        ),
      );
      final staleGpsErr = controller.startEvent(scheduledEvent.id);
      expect(staleGpsErr, contains('fresh, accurate GPS fix'));
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: clockNow,
        ),
      );
      expect(controller.eventById(scheduledEvent.id)!.isStarted, isFalse);

      // 6. Successful start: host present at Staller Steps with fresh GPS inside scheduled window
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: clockNow,
        ),
      );
      final success = controller.startEvent(scheduledEvent.id);
      expect(success, isNull);

      final started = controller.eventById(scheduledEvent.id)!;
      expect(started.isStarted, isTrue);
      expect(started.startedAt, clockNow);
      expect(started.statusAt(clockNow), EventLifecycleStatus.active);

      // Verify system notice in event chat
      final msgs = controller.eventMessagesFor(scheduledEvent.id);
      expect(
        msgs.any((m) => m.isSystemNotice && m.body.contains('Host started')),
        isTrue,
      );

      // Cannot start already started event
      expect(
        controller.startEvent(scheduledEvent.id),
        contains('already started'),
      );
    });

    test('startEvent rejects start on closed day override', () {
      // Clock is 14:00 EDT on Oct 26
      final t = DateTime.utc(2026, 10, 26, 18, 0, 0);
      final controller = AppController(clock: () => t);
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: t,
        ),
      );

      // Multi-day event where Oct 26 is closed
      final closedDayEvent = controller.createEvent(
        title: 'Gallery Showcase',
        description: 'Art exhibit',
        categoryTag: 'Art',
        location: stallerSteps,
        radiusMeters: 400,
        duration: const Duration(days: 3),
        accessType: EventAccessType.public,
        schedule: EventSchedule(
          startDate: DateTime.utc(2026, 10, 26),
          endDate: DateTime.utc(2026, 10, 28),
          venueTimezone: 'America/New_York',
          defaultOpenMinutes: 10 * 60,
          defaultCloseMinutes: 18 * 60,
          dailyOverrides: const <String, DailyScheduleOverride>{
            '2026-10-26': DailyScheduleOverride(
              localDateIso: '2026-10-26',
              isClosed: true,
            ),
          },
        ),
      );

      final err = controller.startEvent(closedDayEvent.id);
      expect(err, contains('closed today'));
      expect(controller.eventById(closedDayEvent.id)!.isStarted, isFalse);
    });

    test('Host ownership transfer enforces independent recipient verification and atomicity', () {
      final t = DateTime.utc(2026, 10, 25, 18, 0, 0);
      final controller = AppController(clock: () => t);
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: t,
        ),
      );

      // 1. Test Host initiating transfer on 'evt-study-code' (hosted by user-me, participant 'user-pine')
      final studyEvt = controller.eventById('evt-study-code')!;
      expect(studyEvt.isHost, isTrue);

      // Attempting to initiate transfer to non-participant fails
      final nonParticipantErr = controller.initiateEventHostTransfer(
        'evt-study-code',
        'user-unknown',
      );
      expect(nonParticipantErr, contains('participant'));

      // Attempting to initiate transfer to self fails
      final selfErr = controller.initiateEventHostTransfer(
        'evt-study-code',
        'user-me',
      );
      expect(selfErr, contains('Cannot transfer ownership to yourself'));

      // Successful initiation designating user-pine (privacy-preserving: host does not probe recipient location)
      final initSuccess = controller.initiateEventHostTransfer(
        'evt-study-code',
        'user-pine',
      );
      expect(initSuccess, isNull);

      final pendingEvt = controller.eventById('evt-study-code')!;
      expect(pendingEvt.pendingHostTransferUserId, equals('user-pine'));
      expect(pendingEvt.isPendingHostTransferForMe, isFalse);

      // Host cancel transfer
      expect(
        controller.cancelOrRejectEventHostTransfer('evt-study-code'),
        isNull,
      );
      expect(
        controller.eventById('evt-study-code')!.pendingHostTransferUserId,
        isNull,
      );

      // 2. Test Recipient accepting transfer:
      // Create an event hosted by user-hana, with user-me as participant, and pendingHostTransferUserId = 'user-me'
      // We start from an event where user-me is the recipient:
      // 'evt-open-jam' is hosted by user-hana at Staller Steps (radius 400m).
      // First, user-me joins evt-open-jam:
      controller.joinEvent('evt-open-jam');

      // Simulate host hana initiating transfer to user-me
      // (Using a helper or internal simulation)
      controller.simulateIncomingHostTransfer(
        eventId: 'evt-open-jam',
        designatedRecipientUserId: 'user-me',
      );

      final transferForMe = controller.eventById('evt-open-jam')!;
      expect(transferForMe.pendingHostTransferUserId, 'user-me');
      expect(transferForMe.isPendingHostTransferForMe, isTrue);
      expect(transferForMe.isHost, isFalse);

      // A. Recipient outside radius rejects acceptance
      controller.ingestLocationFix(
        LocationFix(
          latitude: farAwayLocation.latitude,
          longitude: farAwayLocation.longitude,
          accuracyMeters: 5,
          recordedAt: t,
        ),
      );
      final outsideErr = controller.acceptEventHostTransfer('evt-open-jam');
      expect(outsideErr, contains('Recipient presence required'));
      expect(controller.eventById('evt-open-jam')!.isHost, isFalse);

      // B. Recipient with stale GPS rejects acceptance
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: t.subtract(const Duration(minutes: 5)),
        ),
      );
      final staleErr = controller.acceptEventHostTransfer('evt-open-jam');
      expect(staleErr, contains('fresh, accurate GPS fix'));
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: t,
        ),
      );
      expect(controller.eventById('evt-open-jam')!.isHost, isFalse);

      // C. Recipient inside radius with fresh GPS successfully accepts!
      controller.ingestLocationFix(
        LocationFix(
          latitude: stallerSteps.latitude,
          longitude: stallerSteps.longitude,
          accuracyMeters: 5,
          recordedAt: t,
        ),
      );
      final acceptSuccess = controller.acceptEventHostTransfer('evt-open-jam');
      expect(acceptSuccess, isNull);

      // Verified atomic handoff:
      final acceptedEvt = controller.eventById('evt-open-jam')!;
      expect(acceptedEvt.hostId, equals('user-me'));
      expect(acceptedEvt.isHost, isTrue);
      expect(acceptedEvt.pendingHostTransferUserId, isNull);
      expect(acceptedEvt.isPendingHostTransferForMe, isFalse);

      // New host (user-me) can now perform host-only operations:
      expect(
        controller.updateEventDetails(
          'evt-open-jam',
          title: 'New Jam Title',
          description: 'Updated by new host',
          radiusMeters: 450,
        ),
        isTrue,
      );

      // Host departure rule: user-me cannot leave active event while host
      final leaveErr = controller.leaveEvent('evt-open-jam');
      expect(leaveErr, contains('transfer ownership or end the event'));
    });
  });

  group('Scope C: Platform-Appropriate Date & Time Pickers', () {
    testWidgets(
      'PlatformDateTimePicker renders Cupertino modal picker on iOS',
      (tester) async {
        DateTime? pickedDate;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: Builder(
              builder: (ctx) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        pickedDate =
                            await PlatformDateTimePicker.showPlatformDatePicker(
                              ctx,
                              initialDate: DateTime(2026, 10, 26),
                              firstDate: DateTime(2026, 10, 25),
                              lastDate: DateTime(2026, 11, 26),
                            );
                      },
                      child: const Text('Pick Date'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick Date'));
        await tester.pumpAndSettle();

        // Verify Cupertino modal sheet rendered
        expect(find.byType(CupertinoDatePicker), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(pickedDate, isNotNull);
        expect(pickedDate!.year, 2026);
        expect(pickedDate!.month, 10);
      },
    );

    testWidgets('PlatformDateTimePicker renders Material picker on Android', (
      tester,
    ) async {
      DateTime? pickedDate;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      pickedDate =
                          await PlatformDateTimePicker.showPlatformDatePicker(
                            ctx,
                            initialDate: DateTime(2026, 10, 26),
                            firstDate: DateTime(2026, 10, 25),
                            lastDate: DateTime(2026, 11, 26),
                          );
                    },
                    child: const Text('Pick Material Date'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick Material Date'));
      await tester.pumpAndSettle();

      // Verify Material DatePickerDialog rendered
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(pickedDate, isNotNull);
    });
  });
}
