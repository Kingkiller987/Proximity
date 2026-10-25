import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/config/app_config.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/auth/auth_screen.dart';
import 'package:proximity_app/features/events/events_screen.dart';
import 'package:proximity_app/features/inbox/inbox_screen.dart';
import 'package:proximity_app/features/nearby/nearby_screen.dart';
import 'package:proximity_app/features/profile/profile_screen.dart';

void main() {
  const narrowSize = Size(320, 640);

  testWidgets(
    'Reproduce overflow on ProfileScreen with available width ~376px',
    (tester) async {
      // 376 + 32 (ListView padding) + 32 (Card padding) = 440 approx
      // Let's set physical size so available width is exactly 376px
      // In ProfileScreen: Card width = screenWidth - 32 (padding of ListView).
      // Available width inside Card = Card width - 32 (padding of Card) = screenWidth - 64.
      // If screenWidth = 440, available width = 376 px!
      tester.view.physicalSize = const Size(440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = AppController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfileScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Check for overflow exceptions
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ProfileScreen renders without overflow on 320px viewport', (
    tester,
  ) async {
    tester.view.physicalSize = narrowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('AuthScreen renders without overflow on 320px viewport', (
    tester,
  ) async {
    tester.view.physicalSize = narrowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('NearbyScreen renders without overflow on 320px viewport', (
    tester,
  ) async {
    tester.view.physicalSize = narrowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbyScreen(
            controller: controller,
            config: const AppConfig(
              environment: 'test',
              supabaseUrl: '',
              supabaseAnonKey: '',
              allowSimulatedLocation: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ExploreEventsScreen renders without overflow on 320px viewport',
    (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = AppController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreEventsScreen(
              controller: controller,
              config: const AppConfig(
                environment: 'test',
                supabaseUrl: '',
                supabaseAnonKey: '',
                allowSimulatedLocation: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('InboxScreen renders without overflow on 320px viewport', (
    tester,
  ) async {
    tester.view.physicalSize = narrowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InboxScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
