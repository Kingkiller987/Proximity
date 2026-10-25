import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/auth/auth_session_store.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/auth/auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Slice 4: Signup, Login, and Returning-User Experience', () {
    testWidgets(
      '1. New user registration with inline validation and successful signup',
      (tester) async {
        final sessionStore = LocalDemoSessionStore();
        final controller = AppController(sessionStore: sessionStore);
        controller.logout(); // Enter unauthenticated state

        await tester.pumpWidget(
          MaterialApp(home: AuthScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Switch to Sign Up tab
        await tester.tap(find.byKey(const Key('auth-tab-signup')));
        await tester.pumpAndSettle();

        // Tap submit with empty fields
        await tester.tap(find.byKey(const Key('auth-submit-btn')));
        await tester.pumpAndSettle();

        // Inline validation errors appear
        expect(find.text('Username is required.'), findsOneWidget);
        expect(find.text('Email is required.'), findsOneWidget);
        expect(find.text('Password is required.'), findsOneWidget);

        // Enter mismatched password
        await tester.enterText(
          find.byKey(const Key('auth-username-field')),
          'new_user',
        );
        await tester.enterText(
          find.byKey(const Key('auth-email-field')),
          'invalid-email',
        );
        await tester.enterText(
          find.byKey(const Key('auth-password-field')),
          'password123',
        );
        await tester.enterText(
          find.byKey(const Key('auth-confirm-password-field')),
          'password456',
        );

        await tester.ensureVisible(find.byKey(const Key('auth-submit-btn')));
        await tester.tap(find.byKey(const Key('auth-submit-btn')));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a valid email address.'),
          findsOneWidget,
        );
        expect(find.text('Passwords do not match.'), findsOneWidget);

        // Fix email and matching password
        await tester.enterText(
          find.byKey(const Key('auth-email-field')),
          'user@stonybrook.edu',
        );
        await tester.enterText(
          find.byKey(const Key('auth-password-field')),
          'password123',
        );
        await tester.enterText(
          find.byKey(const Key('auth-confirm-password-field')),
          'password123',
        );

        await tester.ensureVisible(find.byKey(const Key('auth-submit-btn')));
        await tester.tap(find.byKey(const Key('auth-submit-btn')));
        await tester.pumpAndSettle();

        // Successfully authenticated
        expect(controller.isAuthenticated, isTrue);
        expect(controller.profile.username, equals('new_user'));
        expect(
          await sessionStore.getSavedSessionUsername(),
          equals('new_user'),
        );
      },
    );

    testWidgets('2. Existing user login succeeds and updates session store', (
      tester,
    ) async {
      final sessionStore = LocalDemoSessionStore();
      final controller = AppController(sessionStore: sessionStore);
      controller.logout();

      await tester.pumpWidget(
        MaterialApp(home: AuthScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Enter existing mock username 'Alex'
      await tester.enterText(
        find.byKey(const Key('auth-username-field')),
        'Alex',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'password123',
      );

      await tester.tap(find.byKey(const Key('auth-submit-btn')));
      await tester.pumpAndSettle();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.profile.username.toLowerCase(), equals('alex'));
      expect(await sessionStore.getSavedSessionUsername(), equals('Alex'));
    });

    test(
      '3. Returning-user auto-login restores session on app restart',
      () async {
        final sessionStore = LocalDemoSessionStore(initialUsername: 'alex');
        final controller = AppController(sessionStore: sessionStore);

        // App initializes and restores saved session
        final restored = await controller.restoreSavedSession();
        expect(restored, isTrue);
        expect(controller.isAuthenticated, isTrue);
        expect(controller.profile.username.toLowerCase(), equals('alex'));
      },
    );

    test(
      '4. Explicit logout clears session and prevents auto-login on restart',
      () async {
        final sessionStore = LocalDemoSessionStore(initialUsername: 'alex');
        final controller = AppController(sessionStore: sessionStore);

        await controller.restoreSavedSession();
        expect(controller.isAuthenticated, isTrue);

        // Explicit logout
        controller.logout();
        expect(controller.isAuthenticated, isFalse);
        expect(await sessionStore.getSavedSessionUsername(), isNull);

        // New controller instance simulating app restart with the same store
        final restartedController = AppController(sessionStore: sessionStore);
        final restored = await restartedController.restoreSavedSession();
        expect(restored, isFalse);
        expect(restartedController.isAuthenticated, isFalse);
      },
    );

    testWidgets('5. Passwords are wiped from memory and never persisted', (
      tester,
    ) async {
      final sessionStore = LocalDemoSessionStore();
      final controller = AppController(sessionStore: sessionStore);
      controller.logout();

      await tester.pumpWidget(
        MaterialApp(home: AuthScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      final pwdFinder = find.byKey(const Key('auth-password-field'));
      await tester.enterText(pwdFinder, 'ephemeral_secret_123');
      expect(
        tester.widget<TextField>(pwdFinder).controller!.text,
        equals('ephemeral_secret_123'),
      );

      await tester.enterText(
        find.byKey(const Key('auth-username-field')),
        'Alex',
      );
      await tester.tap(find.byKey(const Key('auth-submit-btn')));
      await tester.pumpAndSettle();

      // Password field controller is cleared immediately
      expect(tester.widget<TextField>(pwdFinder).controller!.text, isEmpty);
      // Session store only contains the username, no credentials
      final savedUser = await sessionStore.getSavedSessionUsername();
      expect(savedUser, equals('Alex'));
    });
  });
}
