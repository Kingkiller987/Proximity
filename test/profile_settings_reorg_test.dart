import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Slice 5: Profile Menu and Settings Reorganization', () {
    testWidgets(
      '1. Searching settings filters visible sections; clearing restores all',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: ProfileScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // All 3 sections are initially present
        expect(
          find.byKey(const Key('settings-section-personalization')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings-section-security')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings-section-miscellaneous')),
          findsOneWidget,
        );

        // Search for "theme"
        await tester.enterText(
          find.byKey(const Key('settings-search-field')),
          'theme',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings-section-personalization')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings-section-security')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('settings-section-miscellaneous')),
          findsNothing,
        );

        // Search for "password"
        await tester.enterText(
          find.byKey(const Key('settings-search-field')),
          'password',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings-section-personalization')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('settings-section-security')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings-section-miscellaneous')),
          findsNothing,
        );

        // Search for "xyznonexistent"
        await tester.enterText(
          find.byKey(const Key('settings-search-field')),
          'xyznonexistent',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings-no-results-text')),
          findsOneWidget,
        );

        // Clear search
        await tester.tap(find.byKey(const Key('settings-search-clear-btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings-section-personalization')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings-section-security')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings-section-miscellaneous')),
          findsOneWidget,
        );
      },
    );

    testWidgets('2. Toggling theme updates controller.themeMode', (
      tester,
    ) async {
      final controller = AppController();
      expect(controller.themeMode, equals(ThemeMode.dark));

      await tester.pumpWidget(
        MaterialApp(home: ProfileScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Tap "Light" segment
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(controller.themeMode, equals(ThemeMode.light));

      // Tap "Dark" segment
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(controller.themeMode, equals(ThemeMode.dark));
    });

    testWidgets(
      '3. Change Email dialog requires 2FA code and updates successfully in demo',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: ProfileScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Tap Change Email
        await tester.tap(find.byKey(const Key('settings-change-email-btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('change-email-dialog')), findsOneWidget);
        expect(
          find.textContaining(
            'Demo flow: 2FA email code is simulated locally (enter demo code 123456).',
          ),
          findsOneWidget,
        );

        // Enter invalid email and wrong code
        await tester.enterText(
          find.byKey(const Key('change-email-new-field')),
          'not-an-email',
        );
        await tester.enterText(
          find.byKey(const Key('change-email-2fa-field')),
          '999999',
        );
        await tester.tap(find.byKey(const Key('submit-change-email-btn')));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a valid email address.'),
          findsOneWidget,
        );

        // Enter valid email but wrong code
        await tester.enterText(
          find.byKey(const Key('change-email-new-field')),
          'alex@stonybrook.edu',
        );
        await tester.tap(find.byKey(const Key('submit-change-email-btn')));
        await tester.pumpAndSettle();

        expect(
          find.text('Invalid 2FA code. For demo purposes, enter 123456.'),
          findsOneWidget,
        );

        // Enter correct code 123456
        await tester.enterText(
          find.byKey(const Key('change-email-2fa-field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('submit-change-email-btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('change-email-dialog')), findsNothing);
        expect(find.text('Email updated successfully (demo).'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Change Password dialog requires min 8 chars and demo 2FA code',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: ProfileScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Tap Change Password
        await tester.tap(find.byKey(const Key('settings-change-password-btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('change-password-dialog')), findsOneWidget);

        // Short password (< 8 chars)
        await tester.enterText(
          find.byKey(const Key('change-password-new-field')),
          'short',
        );
        await tester.enterText(
          find.byKey(const Key('change-password-2fa-field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('submit-change-password-btn')));
        await tester.pumpAndSettle();

        expect(
          find.text('Password must be at least 8 characters long.'),
          findsOneWidget,
        );

        // Valid password with wrong code
        await tester.enterText(
          find.byKey(const Key('change-password-new-field')),
          'strong_password_123',
        );
        await tester.enterText(
          find.byKey(const Key('change-password-2fa-field')),
          '000000',
        );
        await tester.tap(find.byKey(const Key('submit-change-password-btn')));
        await tester.pumpAndSettle();

        expect(
          find.text('Invalid 2FA code. For demo purposes, enter 123456.'),
          findsOneWidget,
        );

        // Valid password with correct code
        await tester.enterText(
          find.byKey(const Key('change-password-new-field')),
          'strong_password_123',
        );
        await tester.enterText(
          find.byKey(const Key('change-password-2fa-field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('submit-change-password-btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('change-password-dialog')), findsNothing);
        expect(
          find.text('Password updated successfully (demo).'),
          findsOneWidget,
        );
      },
    );

    testWidgets('5. Bio editing in non-anonymous mode saves bio to profile', (
      tester,
    ) async {
      final controller = AppController();
      controller.setAnonymousMode(false); // Enable real profile mode

      await tester.pumpWidget(
        MaterialApp(home: ProfileScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      final bioField = find.byKey(const Key('profile-bio-field'));
      expect(bioField, findsOneWidget);

      await tester.enterText(bioField, 'Updated test bio for user.');
      await tester.tap(find.byKey(const Key('profile-save-btn')));
      await tester.pumpAndSettle();

      expect(controller.profile.bio, equals('Updated test bio for user.'));
      expect(find.text('Profile updated successfully.'), findsOneWidget);
    });
  });
}
