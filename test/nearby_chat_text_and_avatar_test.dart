import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/config/app_config.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/core/theme/app_theme.dart';
import 'package:proximity_app/features/nearby/nearby_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1x1 transparent PNG bytes
  final sampleAvatarBytes = Uint8List.fromList(<int>[
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

  group('Nearby Chat: Message text contrast and Profile Pictures', () {
    testWidgets('Message body text color adapts to Light and Dark mode', (
      tester,
    ) async {
      final controller = AppController();
      final config = AppConfig.fromEnvironment();

      // Ensure user is in a landmark zone with messages
      controller.setSimulatedLocation(AppController.presetLocations.first);

      // Light theme verification
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: NearbyScreen(controller: controller, config: config),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find message body text
      final lightTextFinder = find.byWidgetPredicate((w) {
        if (w is Text && w.data != null && w.style?.fontSize == 14) {
          return w.style?.color == const Color(0xFF0F172A);
        }
        return false;
      });
      expect(
        lightTextFinder,
        findsAtLeastNWidgets(1),
        reason: 'Message body text must be dark #0F172A in Light mode',
      );

      // Dark theme verification
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: NearbyScreen(controller: controller, config: config),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkTextFinder = find.byWidgetPredicate((w) {
        if (w is Text && w.data != null && w.style?.fontSize == 14) {
          return w.style?.color == const Color(0xFFF8FAFC);
        }
        return false;
      });
      expect(
        darkTextFinder,
        findsAtLeastNWidgets(1),
        reason: 'Message body text must be light #F8FAFC in Dark mode',
      );
    });

    testWidgets(
      'Profile picture displays beside username when available, fallback when none, and respects anonymity',
      (tester) async {
        final controller = AppController();
        final config = AppConfig.fromEnvironment();

        // Give current user a profile picture and turn off anonymous mode
        controller.setAnonymousMode(false);
        controller.updateRealProfile(avatarBytes: sampleAvatarBytes);
        controller.setSimulatedLocation(AppController.presetLocations.first);

        // Send a message from current user
        final landmarkId = controller.activeLandmarkChats.first.id;
        controller.selectLandmark(landmarkId);
        final sent = controller.sendLandmarkMessage(
          landmarkId,
          'Hello from me with avatar!',
        );
        expect(sent, isTrue);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: NearbyScreen(controller: controller, config: config),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Current user (not anonymous, has avatar) -> Image.memory rendered
        final imageFinder = find.byType(Image);
        expect(imageFinder, findsAtLeastNWidgets(1));

        // 2. Toggle current user to anonymous mode (ending active hosted event first)
        controller.endEvent('evt-study-code');
        controller.setAnonymousMode(true);
        controller.sendLandmarkMessage(landmarkId, 'Hello anonymously!');
        await tester.pumpAndSettle();

        // Anonymous message must render person icon, NOT avatar image
        final personIconFinder = find.byIcon(Icons.person);
        expect(personIconFinder, findsAtLeastNWidgets(1));

        // 3. User without profile picture (not anonymous) -> renders person_outline fallback icon
        controller.setAnonymousMode(false);
        controller.updateRealProfile(clearAvatar: true);
        controller.sendLandmarkMessage(landmarkId, 'Hello without avatar!');
        await tester.pumpAndSettle();

        final personOutlineFinder = find.byIcon(Icons.person_outline);
        expect(personOutlineFinder, findsAtLeastNWidgets(1));
      },
    );
  });
}
