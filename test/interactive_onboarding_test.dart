import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/config/app_config.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/onboarding/onboarding_overlay.dart';
import 'package:proximity_app/main.dart';

const testConfig = AppConfig(
  environment: 'test',
  supabaseUrl: '',
  supabaseAnonKey: '',
  allowSimulatedLocation: true,
);

void main() {
  testWidgets(
    'New signup automatically triggers onboarding; returning user does not',
    (tester) async {
      final controller = AppController();
      expect(controller.isOnboardingActive, isFalse);

      // Seeded/existing user alex should not trigger onboarding
      controller.login('alex');
      expect(controller.isOnboardingActive, isFalse);

      // Register a new user
      final registerErr = controller.register(
        username: 'new_explorer',
        email: 'new@explorer.com',
        password: 'password123',
      );
      expect(registerErr, isNull);
      expect(controller.isOnboardingActive, isTrue);

      // Dismiss onboarding
      controller.skipOnboarding();
      expect(controller.isOnboardingActive, isFalse);

      // Logging out and logging back in as new_explorer should NOT re-trigger onboarding
      controller.logout();
      expect(controller.isOnboardingActive, isFalse);

      controller.login('new_explorer');
      expect(controller.isOnboardingActive, isFalse);
    },
  );

  testWidgets(
    'OnboardingOverlay steps through all 5 steps with Next/Back and completes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = AppController();
      controller.login('alex');
      controller.startOnboarding();

      await tester.pumpWidget(
        ProximityApp(config: testConfig, controller: controller),
      );
      await tester.pumpAndSettle();

      // Verify Onboarding is active and shows Step 1 of 5
      expect(find.byType(OnboardingOverlay), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-card')),
          matching: find.text('Nearby Chats'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('onboarding-back-btn')),
        findsNothing,
      ); // No back on step 1

      // Step 1 -> Step 2
      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-card')),
          matching: find.text('Explore Map'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('onboarding-back-btn')), findsOneWidget);

      // Step 2 -> Back to Step 1
      await tester.tap(find.byKey(const Key('onboarding-back-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-card')),
          matching: find.text('Nearby Chats'),
        ),
        findsOneWidget,
      );

      // Step 1 -> Step 2 -> Step 3 -> Step 4 -> Step 5
      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-card')),
          matching: find.text('Host Events'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-card')),
          matching: find.text('Inbox & DMs'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-card')),
          matching: find.text('Profile & Privacy'),
        ),
        findsOneWidget,
      );
      expect(find.text('Get Started'), findsOneWidget);

      // Final step "Get Started" completes onboarding
      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingOverlay), findsNothing);
      expect(controller.isOnboardingActive, isFalse);
    },
  );

  testWidgets(
    'Skip button immediately dismisses tutorial and records completion',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = AppController();
      controller.login('alex');
      controller.startOnboarding();

      await tester.pumpWidget(
        ProximityApp(config: testConfig, controller: controller),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingOverlay), findsOneWidget);
      expect(find.byKey(const Key('onboarding-skip-btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-skip-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingOverlay), findsNothing);
      expect(controller.isOnboardingActive, isFalse);
      expect(
        controller.shouldShowOnboardingFor(controller.profile.id),
        isFalse,
      );
    },
  );

  testWidgets(
    'Tapping non-target background absorbs touch and does not change state',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = AppController();
      controller.login('alex');
      controller.startOnboarding();

      await tester.pumpWidget(
        ProximityApp(config: testConfig, controller: controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 5'), findsOneWidget);

      // Tap somewhere in the top middle of the screen (dimmed area)
      await tester.tapAt(const Offset(400, 200));
      await tester.pumpAndSettle();

      // Still on Step 1 of 5
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(controller.isOnboardingActive, isTrue);
    },
  );

  testWidgets('Graceful fallback when target key is empty or missing', (
    tester,
  ) async {
    final controller = AppController();
    final emptyKeys = <GlobalKey>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingOverlay(
            controller: controller,
            targetKeys: emptyKeys,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Renders safely without throwing exception
    expect(find.byType(OnboardingOverlay), findsOneWidget);
    expect(find.text('Step 1 of 5'), findsOneWidget);

    // Can skip safely
    await tester.tap(find.byKey(const Key('onboarding-skip-btn')));
    await tester.pumpAndSettle();
    expect(controller.isOnboardingActive, isFalse);
  });

  testWidgets('Tapping spotlight target area advances to next step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = AppController();
    controller.login('alex');
    controller.startOnboarding();

    await tester.pumpWidget(
      ProximityApp(config: testConfig, controller: controller),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 5'), findsOneWidget);

    // Tap the Nearby tab (first bottom navigation destination, hit through overlay)
    final nearbyFinder = find.text('Nearby');
    expect(nearbyFinder, findsOneWidget);
    await tester.tap(nearbyFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Should advance to Step 2
    expect(find.text('Step 2 of 5'), findsOneWidget);
  });
}
