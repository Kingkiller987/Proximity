import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/events/events_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final validPng = Uint8List.fromList(<int>[
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

  group('Phase 6: Explore Map Defaults and List-Only Filter Menu', () {
    testWidgets(
      'Opening Explore defaults to Map view; Map view contains no filter row',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: ExploreEventsScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Map view is default
        expect(find.byKey(const Key('explore-expanded-map')), findsOneWidget);

        // Map view contains no filter chips or popup filter menu
        expect(find.byKey(const Key('explore-filter-menu-btn')), findsNothing);
        expect(find.widgetWithText(FilterChip, 'All'), findsNothing);
        expect(find.widgetWithText(FilterChip, 'Public'), findsNothing);

        // Switching to List reveals filter PopupMenuButton
        final listSegment = find.text('List');
        expect(listSegment, findsOneWidget);
        await tester.tap(listSegment);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('explore-filter-menu-btn')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Filter selection in List view filters events and persists across tab switches',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: ExploreEventsScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Switch to List
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();

        // Open filter popup menu
        final filterBtn = find.byKey(const Key('explore-filter-menu-btn'));
        await tester.tap(filterBtn);
        await tester.pumpAndSettle();

        // Options appear
        expect(find.text('Public'), findsOneWidget);
        expect(find.text('Join Code'), findsOneWidget);

        // Select Join Code
        await tester.tap(find.text('Join Code'));
        await tester.pumpAndSettle();

        // Filter is applied
        expect(find.textContaining('Filter: Join Code'), findsOneWidget);

        // Switch to Map and back to List; filter state preserved
        await tester.tap(find.text('Map'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Filter: Join Code'), findsOneWidget);
      },
    );
  });

  group('Phase 6: Dual Map Markers and Landmark Detail Sheet', () {
    testWidgets(
      'Explore Map displays both landmark markers and event markers interactively',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: ExploreEventsScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Both event markers and landmark markers appear on the map
        expect(
          find.byKey(const Key('map-marker-landmark-lm-staller')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('map-marker-event-evt-open-jam')),
          findsOneWidget,
        );

        // Tapping landmark marker opens LandmarkDetailSheet
        await tester.tap(
          find.byKey(const Key('map-marker-landmark-lm-staller')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Staller Steps'), findsWidgets);
        expect(find.textContaining('Point Of Interest'), findsOneWidget);
        expect(find.textContaining('radius'), findsWidgets);
      },
    );

    testWidgets(
      'Explore detail sheet has no inline chat; displays Open Chat in Nearby for joined events',
      (tester) async {
        final controller = AppController();
        controller.joinEvent('evt-open-jam');
        final event = controller.discoverableEvents.firstWhere(
          (e) => e.id == 'evt-open-jam',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: ctx,
                      builder: (_) => FractionallySizedBox(
                        heightFactor: 0.88,
                        child: EventDetailSheet(
                          controller: controller,
                          eventId: event.id,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Details'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Details'));
        await tester.pumpAndSettle();

        // No inline chat composer in detail sheet
        expect(
          find.widgetWithText(TextField, 'Message event participants...'),
          findsNothing,
        );

        // Shortcut button to open in Nearby
        await tester.scrollUntilVisible(find.text('Open Chat in Nearby'), 100);
        expect(find.text('Open Chat in Nearby'), findsOneWidget);
      },
    );
  });

  group('Phase 6: Event Poster Images in Cards and Map', () {
    testWidgets(
      'Event cards and detail sheets render poster image when present',
      (tester) async {
        final controller = AppController();
        // Create an event with a poster
        final event = controller.createEvent(
          title: 'Art Exhibition & Live Strings',
          description: 'Outdoor musical showcase with student art galleries.',
          categoryTag: 'Music & Arts',
          location: controller.currentLocation,
          radiusMeters: 250,
          duration: const Duration(hours: 3),
          accessType: EventAccessType.public,
          posterBytes: validPng,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EventDetailSheet(controller: controller, eventId: event.id),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Poster image rendered in header
        expect(
          find.byKey(const Key('event-detail-poster-image')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Explore List, _EventRadarOverview, and CreateEventScreen render without RenderFlex overflow on narrow 320px viewport',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 3.0, 640 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = AppController();
        controller.createEvent(
          title: 'Extraordinary Campus Late-Night Quantum Computing Symposium',
          description:
              'Deep dive into quantum algorithms and error correction.',
          categoryTag: 'Academic',
          location: controller.currentLocation,
          radiusMeters: 300,
          duration: const Duration(hours: 3),
          accessType: EventAccessType.public,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.1),
              ),
              child: ExploreEventsScreen(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to List view (renders _EventRadarOverview chips and _EventCard)
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Render CreateEventScreen on the same narrow 320px viewport
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.1),
              ),
              child: CreateEventScreen(
                controller: controller,
                onCreated: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
