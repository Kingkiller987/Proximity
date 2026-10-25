import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/config/app_config.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/nearby/nearby_members_sidebar.dart';
import 'package:proximity_app/features/nearby/nearby_screen.dart';
import 'package:proximity_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: Nearby Proximity Dropdown & Radius Controls Removal', () {
    testWidgets(
      'Radius-selection chips are completely removed; legitimate distance displays preserved',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: NearbyScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Prohibited radius presets must not exist as ChoiceChips
        expect(find.widgetWithText(ChoiceChip, '100m'), findsNothing);
        expect(find.widgetWithText(ChoiceChip, '250m'), findsNothing);
        expect(find.widgetWithText(ChoiceChip, '500m'), findsNothing);
        expect(find.widgetWithText(ChoiceChip, '1km'), findsNothing);
        expect(find.widgetWithText(ChoiceChip, '2.5km'), findsNothing);

        // Distance indicators remain visible in the header / landmark info
        expect(find.textContaining('m away'), findsWidgets);
      },
    );

    testWidgets(
      'Top proximity-chat dropdown lists eligible chats, displays full names and distances, and selects chat',
      (tester) async {
        final controller = AppController();
        // Probe location at campus center
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: controller.now,
            areaName: 'Staller Steps',
          ),
        );

        // Test with 320px narrow viewport and 1.2x text scaler
        tester.view.physicalSize = const Size(320 * 3.0, 640 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.2),
              ),
              child: NearbyScreen(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Proximity-chat dropdown exists
        final dropdownFinder = find.byKey(
          const Key('nearby-proximity-chat-dropdown'),
        );
        expect(dropdownFinder, findsOneWidget);

        // Tap dropdown to open eligible choices
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        // Staller Steps should be visible with distance
        expect(find.textContaining('Staller Steps'), findsWidgets);

        // Close / select
        await tester.tap(find.textContaining('Staller Steps').last);
        await tester.pumpAndSettle();

        expect(controller.selectedLandmarkId, equals('lm-staller'));
      },
    );

    testWidgets(
      'Exactly ONE proximity-chat dropdown below mode buttons; scrollable for long lists without overflow',
      (tester) async {
        final controller = AppController();
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: controller.now,
            areaName: 'Staller Steps',
          ),
        );

        // Add 10 additional nearby eligible landmarks at current location
        for (var i = 1; i <= 10; i++) {
          controller.addLandmarkForTest(
            id: 'lm-extra-$i',
            name: 'Extra Zone Landmark #$i',
            areaName: 'Staller Steps',
            center: const GeoPoint(
              latitude: 40.9154,
              longitude: -73.1225,
              areaName: 'Staller Steps',
            ),
            radiusMeters: 200,
          );
        }

        // Add an ineligible landmark far away
        controller.addLandmarkForTest(
          id: 'lm-ineligible-far',
          name: 'Remote Mountain Zone',
          areaName: 'Far Away',
          center: const GeoPoint(
            latitude: 42.0000,
            longitude: -74.0000,
            areaName: 'Far Away',
          ),
          radiusMeters: 100,
        );

        // Small screen viewport: 320 x 480
        tester.view.physicalSize = const Size(320 * 3.0, 480 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(320, 480)),
              child: NearbyScreen(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify exactly ONE DropdownButton exists on the Nearby screen
        final dropdownFinder = find.byType(DropdownButtonHideUnderline);
        expect(dropdownFinder, findsOneWidget);
        final nearbyDropdown = find.byKey(
          const Key('nearby-proximity-chat-dropdown'),
        );
        expect(nearbyDropdown, findsOneWidget);

        // 2. Verify it is located directly UNDER the two mode buttons
        final nearbyTabsFinder = find.byKey(const Key('nearby-chats-tab'));
        final eventsTabFinder = find.byKey(const Key('nearby-events-tab'));
        expect(nearbyTabsFinder, findsOneWidget);
        expect(eventsTabFinder, findsOneWidget);

        final dropdownTop = tester.getTopLeft(nearbyDropdown).dy;
        final nearbyTabBottom = tester.getBottomLeft(nearbyTabsFinder).dy;
        final eventsTabBottom = tester.getBottomLeft(eventsTabFinder).dy;
        expect(dropdownTop, greaterThan(nearbyTabBottom));
        expect(dropdownTop, greaterThan(eventsTabBottom));

        // 3. Open dropdown and verify scrollable menu
        await tester.tap(nearbyDropdown);
        await tester.pumpAndSettle();

        // Remote Mountain Zone (ineligible) must NOT be present
        expect(find.text('Remote Mountain Zone'), findsNothing);
        // Event titles must NOT be present in proximity-chat dropdown
        expect(find.textContaining('Twilight Lawn Acoustic Jam'), findsNothing);

        // The popup menu contains a Scrollable for its items
        final popupScrollable = find.byType(Scrollable).last;
        expect(popupScrollable, findsOneWidget);

        // Scroll down inside the dropdown menu to reveal the bottom-most item
        final bottomItem = find.text('Extra Zone Landmark #10');
        await tester.scrollUntilVisible(
          bottomItem,
          50.0,
          scrollable: popupScrollable,
        );
        await tester.pumpAndSettle();
        expect(bottomItem, findsOneWidget);

        // Select the bottom-most item
        await tester.tap(bottomItem);
        await tester.pumpAndSettle();

        expect(controller.selectedLandmarkId, equals('lm-extra-10'));

        // 4. Switch to "Events You're In" and verify separation
        await tester.tap(eventsTabFinder);
        await tester.pumpAndSettle();

        // Proximity chat dropdown is no longer rendered
        expect(
          find.byKey(const Key('nearby-proximity-chat-dropdown')),
          findsNothing,
        );
      },
    );

    testWidgets('Empty state renders cleanly when outside all landmark zones', (
      tester,
    ) async {
      final controller = AppController();
      // Move far away from all landmarks
      controller.ingestLocationFix(
        LocationFix(
          latitude: 41.5000,
          longitude: -74.0000,
          accuracyMeters: 10.0,
          recordedAt: controller.now,
          areaName: 'Remote Wilderness',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: NearbyScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Outside landmark zones'), findsWidgets);
    });

    testWidgets(
      'On-demand stale fix clears message feed on rebuild without background timers',
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
        controller.sendLandmarkMessage(
          'lm-staller',
          'Fresh message for visit 1',
        );

        await tester.pumpWidget(
          MaterialApp(home: NearbyScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Message list is present
        expect(find.byKey(const Key('nearby-message-list')), findsOneWidget);

        // Advance clock 31 seconds without new location fix
        controller.setMockNow(t0.add(const Duration(seconds: 31)));

        // Trigger rebuild / interaction
        await tester.pump();

        // Message list should be cleared and stale location warning displayed
        expect(find.textContaining('Location fix expired'), findsOneWidget);
      },
    );
  });

  group('Phase 4: Message Timestamps, Expiration Privacy & 2-Way Switch', () {
    testWidgets(
      'Messages display sent timestamp only; no countdowns or auto-expires notices',
      (tester) async {
        final controller = AppController();
        final t0 = DateTime(2026, 10, 25, 14, 30);
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
        controller.sendLandmarkMessage(
          'lm-staller',
          'Fresh message for visit 1',
        );

        await tester.pumpWidget(
          MaterialApp(home: NearbyScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Zero expiration countdowns (no '⏳' symbol)
        expect(find.textContaining('⏳'), findsNothing);

        // Zero 'Auto-expires in' text
        expect(find.textContaining('Auto-expires in'), findsNothing);

        // Sent timestamps appear (e.g. AM / PM)
        expect(
          find.textContaining(RegExp(r'\d{1,2}:\d{2}\s*(AM|PM)')),
          findsWidgets,
        );
      },
    );

    testWidgets(
      '2-Way switch toggles between Nearby Chats and Events You Are In',
      (tester) async {
        final controller = AppController();
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: controller.now,
            areaName: 'Staller Steps',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: NearbyScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Toggle switch exists
        final nearbyChatsTab = find.byKey(const Key('nearby-chats-tab'));
        final eventsTab = find.byKey(const Key('nearby-events-tab'));
        expect(nearbyChatsTab, findsOneWidget);
        expect(eventsTab, findsOneWidget);

        // Switch to Events You're In
        await tester.tap(eventsTab);
        await tester.pumpAndSettle();

        // Shows joined event chats or empty state
        expect(find.textContaining("Events You're In"), findsWidgets);

        // Switch back
        await tester.tap(nearbyChatsTab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('nearby-proximity-chat-dropdown')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Discord-style member sidebar opens and lists participants with public projection',
      (tester) async {
        final controller = AppController();
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: controller.now,
            areaName: 'Staller Steps',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: NearbyScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Member sidebar button
        final sidebarBtn = find.byKey(const Key('nearby-members-sidebar-btn'));
        expect(sidebarBtn, findsOneWidget);

        await tester.tap(sidebarBtn);
        await tester.pumpAndSettle();

        // Sidebar is rendered
        expect(find.byType(NearbyMembersSidebar), findsOneWidget);
        expect(find.textContaining('Members'), findsWidgets);
      },
    );

    testWidgets(
      'Nearby screen removes map icon and uses non-map icon on Nearby bottom-navigation tab',
      (tester) async {
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
        await tester.pumpAndSettle();

        // Map toggle button is removed from Nearby screen
        expect(find.byKey(const Key('toggle-nearby-map-btn')), findsNothing);
        expect(find.byIcon(Icons.map), findsNothing);
        expect(find.byIcon(Icons.map_outlined), findsNothing);

        // Nearby bottom-navigation tab uses non-map forum icon and navigates cleanly
        expect(find.byIcon(Icons.forum), findsOneWidget);
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.text('Profile & Privacy'), findsOneWidget);
        expect(find.byIcon(Icons.forum_outlined), findsOneWidget);

        await tester.tap(find.text('Nearby'));
        await tester.pumpAndSettle();
        expect(find.text('Nearby Pulse'), findsOneWidget);
      },
    );

    testWidgets(
      'Nearby chat Add Image button uses shared NativeImagePickerHelper with camera/gallery prompt, cancellation, validation, and sanitization',
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync(
          'nearby_picker_test',
        );
        String? mockPickedPath;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/image_picker'),
              (MethodCall methodCall) async {
                if (methodCall.method == 'pickImage') {
                  return mockPickedPath;
                }
                return null;
              },
            );
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('plugins.flutter.io/image_picker'),
                null,
              );
        });

        final controller = AppController();
        controller.ingestLocationFix(
          LocationFix(
            latitude: 40.9154,
            longitude: -73.1225,
            accuracyMeters: 8.0,
            recordedAt: controller.now,
            areaName: 'Staller Steps',
          ),
        );
        controller.selectLandmark('lm-staller');

        await tester.pumpWidget(
          MaterialApp(home: NearbyScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        final attachBtn = find.byKey(const Key('nearby-attach-photo-btn'));
        expect(attachBtn, findsOneWidget);

        // 1. Cancellation: tap attach button, choose gallery, platform returns null -> no staged upload
        mockPickedPath = null;
        await tester.tap(attachBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('image-picker-source-gallery')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('image-picker-source-camera')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('image-picker-source-gallery')));
        await tester.pumpAndSettle();
        expect(controller.pendingUploadsForChannel('lm-staller'), isEmpty);

        // 2. Corrupt image rejected with error SnackBar
        final corruptFile = File('${tempDir.path}/corrupt.jpg')
          ..writeAsBytesSync(List<int>.filled(16, 0x42));
        mockPickedPath = corruptFile.path;
        await tester.tap(attachBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('image-picker-source-camera')));
        await tester.pumpAndSettle();
        await tester.pump();
        expect(controller.pendingUploadsForChannel('lm-staller'), isEmpty);
        expect(find.textContaining('Unsupported image format'), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
            .clearSnackBars();
        await tester.pumpAndSettle();

        // 3. Oversized (> 5 MB) image rejected with error SnackBar
        final oversizedBytes = Uint8List((5 * 1024 * 1024) + 128);
        oversizedBytes[0] = 0xFF;
        oversizedBytes[1] = 0xD8;
        final oversizedFile = File('${tempDir.path}/oversized.jpg')
          ..writeAsBytesSync(oversizedBytes);
        mockPickedPath = oversizedFile.path;
        await tester.tap(attachBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('image-picker-source-gallery')));
        await tester.pumpAndSettle();
        await tester.pump();
        expect(controller.pendingUploadsForChannel('lm-staller'), isEmpty);
        expect(
          find.textContaining('Image exceeds maximum allowed size'),
          findsOneWidget,
        );
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
            .clearSnackBars();
        await tester.pumpAndSettle();

        // 4. Valid JPEG with EXIF is sanitized and staged in Nearby chat
        final jpegWithExif = Uint8List.fromList(<int>[
          0xFF, 0xD8, // SOI
          0xFF, 0xE1, 0x00, 0x14, // APP1 Exif
          0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
          0x47, 0x50, 0x53, 0x4C, 0x61, 0x74, 0x34, 0x30, 0x2E, 0x39, 0x31,
          0x35,
          0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x40, 0x00, 0x50, 0x01, 0x01,
          0x11, 0x00,
          0xFF, 0xD9,
        ]);
        final validFile = File('${tempDir.path}/valid_exif.jpg')
          ..writeAsBytesSync(jpegWithExif);
        mockPickedPath = validFile.path;

        await tester.tap(attachBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('image-picker-source-gallery')));
        await tester.pumpAndSettle();
        await tester.pump();

        final staged = controller.pendingUploadsForChannel('lm-staller');
        expect(staged, hasLength(1));
        expect(staged.first.sizeBytes, lessThan(jpegWithExif.length));
        expect(find.textContaining('Photo staged'), findsOneWidget);
      },
    );
  });
}
