import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/config/app_config.dart';
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

  const testConfig = AppConfig(
    environment: 'test',
    supabaseUrl: '',
    supabaseAnonKey: '',
    allowSimulatedLocation: true,
  );

  group('Feature 1: Event search beside the filter button', () {
    testWidgets('1. A matching title returns the expected event', (
      tester,
    ) async {
      final controller = AppController();
      await tester.pumpWidget(
        MaterialApp(
          home: ExploreEventsScreen(controller: controller, config: testConfig),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to List view
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      // Enter search query matching title
      final searchField = find.byKey(const Key('explore-event-search-field'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'acoustic');
      await tester.pumpAndSettle();

      expect(find.text('Twilight Lawn Acoustic Jam'), findsWidgets);
      expect(find.text('Systems & PostGIS Late-Night Sprint'), findsNothing);
      expect(find.text('Founders Rooftop Tea Circle'), findsNothing);
    });

    testWidgets('2. A matching description returns the expected event', (
      tester,
    ) async {
      final controller = AppController();
      await tester.pumpWidget(
        MaterialApp(
          home: ExploreEventsScreen(controller: controller, config: testConfig),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to List view
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      // Enter search query matching description ("whiteboard" in Systems & PostGIS Late-Night Sprint)
      final searchField = find.byKey(const Key('explore-event-search-field'));
      await tester.enterText(searchField, 'whiteboard');
      await tester.pumpAndSettle();

      expect(find.text('Systems & PostGIS Late-Night Sprint'), findsWidgets);
      expect(find.text('Twilight Lawn Acoustic Jam'), findsNothing);
    });

    testWidgets('3. A nonmatching query produces the correct empty state', (
      tester,
    ) async {
      final controller = AppController();
      await tester.pumpWidget(
        MaterialApp(
          home: ExploreEventsScreen(controller: controller, config: testConfig),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('explore-event-search-field'));
      await tester.enterText(searchField, 'nonexistent_query_xyz');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('explore-empty-events-text')),
        findsOneWidget,
      );
      expect(find.text('No events found'), findsOneWidget);
      expect(
        find.byKey(const Key('explore-empty-events-icon')),
        findsOneWidget,
      );
    });

    testWidgets(
      '4. Search is case-insensitive and handles surrounding whitespace',
      (tester) async {
        final controller = AppController();
        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('explore-event-search-field'));
        await tester.enterText(searchField, '   AcOuStIc   ');
        await tester.pumpAndSettle();

        expect(find.text('Twilight Lawn Acoustic Jam'), findsWidgets);
        expect(find.text('Systems & PostGIS Late-Night Sprint'), findsNothing);
      },
    );

    testWidgets(
      '5. Search and selected filters combine correctly with AND semantics',
      (tester) async {
        final controller = AppController();
        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('explore-event-search-field'));
        // "acoustic" is a Public event
        await tester.enterText(searchField, 'acoustic');
        await tester.pumpAndSettle();
        expect(find.text('Twilight Lawn Acoustic Jam'), findsWidgets);

        // Now set filter to Join Code
        final filterBtn = find.byKey(const Key('explore-filter-menu-btn'));
        await tester.tap(filterBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Join Code'));
        await tester.pumpAndSettle();

        // Since "acoustic" is not a Join Code event, result must be empty
        expect(find.text('No events found'), findsOneWidget);

        // Searching "PostGIS" which IS a Join Code event should show it
        await tester.enterText(searchField, 'PostGIS');
        await tester.pumpAndSettle();
        expect(find.text('Systems & PostGIS Late-Night Sprint'), findsWidgets);
        expect(find.text('Twilight Lawn Acoustic Jam'), findsNothing);
      },
    );

    testWidgets(
      '6. Editing or clearing query does not reset selected filters',
      (tester) async {
        final controller = AppController();
        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();

        // 1. Select "Join Code" filter
        final filterBtn = find.byKey(const Key('explore-filter-menu-btn'));
        await tester.tap(filterBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Join Code'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Filter: Join Code'), findsOneWidget);

        // 2. Type search query
        final searchField = find.byKey(const Key('explore-event-search-field'));
        await tester.enterText(searchField, 'PostGIS');
        await tester.pumpAndSettle();

        // Clear button should be visible
        final clearBtn = find.byKey(const Key('explore-search-clear-btn'));
        expect(clearBtn, findsOneWidget);

        // 3. Clear search query via clear button
        await tester.tap(clearBtn);
        await tester.pumpAndSettle();

        // Filter MUST still be "Join Code"
        expect(find.textContaining('Filter: Join Code'), findsOneWidget);
        expect(find.text('Systems & PostGIS Late-Night Sprint'), findsWidgets);
        // Public events still excluded because filter remains Join Code
        expect(find.text('Twilight Lawn Acoustic Jam'), findsNothing);
      },
    );

    testWidgets(
      '7. The search/filter row fits a narrow 320px viewport without RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = AppController();
        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();

        // Set filter to "Invite Only" (longest label)
        final filterBtn = find.byKey(const Key('explore-filter-menu-btn'));
        await tester.tap(filterBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Invite Only'));
        await tester.pumpAndSettle();

        // Type in search field
        final searchField = find.byKey(const Key('explore-event-search-field'));
        await tester.enterText(searchField, 'Founders');
        await tester.pumpAndSettle();

        // Verify no overflow occurred and elements are rendered properly
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Filter: Invite Only'), findsOneWidget);
        expect(find.text('Founders Rooftop Tea Circle'), findsWidgets);
      },
    );
  });

  group('Feature 2: Show current user on the map using their avatar', () {
    testWidgets(
      '1. Valid location with profile picture displays avatar marker at coordinates',
      (tester) async {
        final controller = AppController();
        controller.updateRealProfile(avatarBytes: validPng);

        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default Explore view is Map
        expect(find.byKey(const Key('explore-expanded-map')), findsOneWidget);

        // User marker is present
        final userMarker = find.byKey(const Key('map-marker-user-avatar'));
        expect(userMarker, findsOneWidget);

        // Profile avatar image is rendered inside the marker
        expect(
          find.byKey(const Key('map-marker-avatar-image')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('map-marker-default-avatar-icon')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '2. Valid location without profile picture displays default silhouette avatar',
      (tester) async {
        final controller = AppController();
        controller.updateRealProfile(clearAvatar: true);

        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('map-marker-user-avatar')), findsOneWidget);
        expect(find.byKey(const Key('map-marker-avatar-image')), findsNothing);
        expect(
          find.byKey(const Key('map-marker-default-avatar-icon')),
          findsOneWidget,
        );
      },
    );

    testWidgets('3. Updating location updates marker position', (tester) async {
      final controller = AppController();
      await tester.pumpWidget(
        MaterialApp(
          home: ExploreEventsScreen(controller: controller, config: testConfig),
        ),
      );
      await tester.pumpAndSettle();

      final initialTooltip = tester.widget<Tooltip>(
        find.byKey(const Key('map-marker-user-avatar')),
      );
      expect(
        initialTooltip.message,
        'You (${AppController.presetLocations.first.areaName})',
      );

      // Move user to a new preset location
      controller.setSimulatedLocation(AppController.presetLocations[1]);
      await tester.pumpAndSettle();

      // Marker tooltip now reflects updated location area
      final updatedTooltip = tester.widget<Tooltip>(
        find.byKey(const Key('map-marker-user-avatar')),
      );
      expect(
        updatedTooltip.message,
        'You (${AppController.presetLocations[1].areaName})',
      );
    });

    testWidgets(
      '4. Stale, inaccurate, or revoked location removes or suppresses user marker',
      (tester) async {
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

        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('map-marker-user-avatar')), findsOneWidget);

        // 4a. Inaccurate location fix (> 50m)
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 80.0, // Inaccurate
            recordedAt: t0,
            areaName: 'Staller Steps',
          ),
        );
        await tester.pumpAndSettle();

        // Map is replaced by freshness requirement fallback; marker suppressed
        expect(find.byKey(const Key('map-marker-user-avatar')), findsNothing);
        expect(
          find.text(
            'Fresh, accurate location required to view interactive map.',
          ),
          findsOneWidget,
        );

        // 4b. Restore accurate location
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: t0,
            areaName: 'Staller Steps',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-marker-user-avatar')), findsOneWidget);

        // 4c. Stale location fix (> 30s)
        final tStale = t0.add(const Duration(seconds: 35));
        controller.setMockNow(tStale);
        controller.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-marker-user-avatar')), findsNothing);
      },
    );

    testWidgets(
      '5. Corrupt or unparseable image data falls back gracefully to default avatar',
      (tester) async {
        final controller = AppController();
        // Provide malformed non-image bytes
        controller.updateRealProfile(
          avatarBytes: Uint8List.fromList(<int>[0x00, 0x11, 0x22, 0x33, 0x44]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Marker is rendered without throwing unhandled exceptions
        expect(find.byKey(const Key('map-marker-user-avatar')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '6. Event and landmark markers continue to render and remain interactable alongside user marker',
      (tester) async {
        final controller = AppController();
        await tester.pumpWidget(
          MaterialApp(
            home: ExploreEventsScreen(
              controller: controller,
              config: testConfig,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // User marker, landmark markers, and event markers are all present
        expect(find.byKey(const Key('map-marker-user-avatar')), findsOneWidget);
        expect(
          find.byKey(const Key('map-marker-landmark-lm-staller')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('map-marker-event-evt-open-jam')),
          findsOneWidget,
        );

        // Tap landmark marker opens LandmarkDetailSheet
        await tester.tap(
          find.byKey(const Key('map-marker-landmark-lm-staller')),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('Staller Steps'), findsWidgets);

        // Dismiss bottom sheet
        Navigator.of(tester.element(find.text('Staller Steps'))).pop();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Tap event marker title text opens EventDetailSheet
        final eventTitleFinder = find.text('Twilight Lawn Acoustic Jam');
        expect(eventTitleFinder, findsOneWidget);
        await tester.tap(eventTitleFinder);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Event detail sheet is displayed
        expect(find.byType(BottomSheet), findsOneWidget);

        // Dismiss bottom sheet
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      },
    );
  });
}
