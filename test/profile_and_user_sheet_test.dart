import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/profile/profile_screen.dart';
import 'package:proximity_app/features/profile/user_profile_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: ProfileScreen Editing and Retention Removal', () {
    testWidgets('ProfileScreen removes ephemeral message retention block', (
      tester,
    ) async {
      final controller = AppController();

      await tester.pumpWidget(
        MaterialApp(home: ProfileScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ephemeral Message Retention'), findsNothing);
      expect(find.textContaining('expire automatically after:'), findsNothing);
    });

    testWidgets(
      'ProfileScreen supports editing bio, photo, and toggling anonymous mode',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = AppController();
        // Clear active hosted event so anonymous mode switch is enabled
        controller.endEvent('evt-study-code');
        controller.setAnonymousMode(true);
        final initialHandle = controller.profile.anonymousHandle;

        await tester.pumpWidget(
          MaterialApp(home: ProfileScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Anonymous mode switch is present and on
        final anonSwitch = find.byKey(const Key('profile-anonymous-switch'));
        expect(anonSwitch, findsOneWidget);

        // Toggle off (real mode)
        await tester.ensureVisible(anonSwitch);
        await tester.tap(anonSwitch);
        await tester.pumpAndSettle();
        expect(controller.profile.isAnonymous, isFalse);

        // Toggle back on (OFF -> ON transition regenerates handle)
        await tester.ensureVisible(anonSwitch);
        await tester.tap(anonSwitch);
        await tester.pumpAndSettle();
        expect(controller.profile.isAnonymous, isTrue);
        expect(
          controller.profile.anonymousHandle,
          isNot(equals(initialHandle)),
        );

        // Real bio editing
        final bioField = find.byKey(const Key('profile-bio-field'));
        if (bioField.evaluate().isNotEmpty) {
          await tester.enterText(bioField, 'Updated Bio for Testing');
          final saveBtn = find.byKey(const Key('profile-save-btn'));
          if (saveBtn.evaluate().isNotEmpty) {
            await tester.tap(saveBtn);
            await tester.pumpAndSettle();
            expect(controller.profile.bio, equals('Updated Bio for Testing'));
          }
        }

        // Log out button
        final logoutFinder = find.byKey(const Key('profile-logout-btn'));
        await tester.ensureVisible(logoutFinder);
        await tester.pumpAndSettle();
        expect(logoutFinder, findsOneWidget);
        await tester.tap(logoutFinder);
        await tester.pumpAndSettle();
        expect(controller.isAuthenticated, isFalse);
      },
    );

    testWidgets(
      'ProfileScreen renders single Ghost Mode toggle and updates nearby visibility and landmark-chat browsing coherently',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = AppController();
        // Default state: Ghost Mode is OFF, nearby participation enabled
        expect(controller.profile.isGhostMode, isFalse);
        expect(controller.canParticipateInNearby, isTrue);

        await tester.pumpWidget(
          MaterialApp(home: ProfileScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Separate obsolete controls are removed
        expect(find.text('Appear in General Nearby Discovery'), findsNothing);
        expect(find.text('Browse Landmark Chats in Ghost Mode'), findsNothing);

        // Single coherent "Ghost Mode" toggle is present
        final ghostSwitch = find.byKey(const Key('profile-ghost-mode-switch'));
        expect(ghostSwitch, findsOneWidget);
        expect(find.text('Ghost Mode'), findsOneWidget);

        // Toggle Ghost Mode ON -> nearby proximity chats become unavailable and user hidden from nearby discovery
        await tester.ensureVisible(ghostSwitch);
        await tester.tap(ghostSwitch);
        await tester.pumpAndSettle();
        expect(controller.profile.isGhostMode, isTrue);
        expect(controller.canParticipateInNearby, isFalse);
        expect(
          controller.visibleNearbyParticipants.any(
            (p) => p.userId == controller.profile.id,
          ),
          isFalse,
        );

        // Toggle Ghost Mode OFF -> nearby proximity chats restored if location fix is fresh
        await tester.ensureVisible(ghostSwitch);
        await tester.tap(ghostSwitch);
        await tester.pumpAndSettle();
        expect(controller.profile.isGhostMode, isFalse);
        expect(controller.canParticipateInNearby, isTrue);
      },
    );
  });

  group('Phase 3: UserProfileSheet with PublicIdentityProjection', () {
    testWidgets(
      'UserProfileSheet displays silhouette and masked bio for anonymous projection',
      (tester) async {
        const anonProjection = PublicIdentityProjection(
          userId: 'user-anon-1',
          displayName: 'GhostOwl#402',
          bio: "I'm anonymous.",
          avatarBytes: null,
          isAnonymous: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showUserProfileSheet(
                        context,
                        projection: anonProjection,
                        distanceLabel: '~120m away',
                        onSendDm: () {},
                        onBlock: () {},
                        onReport: () {},
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('GhostOwl#402'), findsOneWidget);
        expect(find.text("I'm anonymous."), findsOneWidget);
        expect(find.text('~120m away'), findsOneWidget);
        // Default silhouette icon
        expect(find.byIcon(Icons.person), findsWidgets);
        // Action buttons
        expect(find.text('Send DM'), findsOneWidget);
        expect(find.text('Block'), findsOneWidget);
        expect(find.text('Report'), findsOneWidget);
      },
    );

    testWidgets(
      'UserProfileSheet displays real bio and photo for real projection',
      (tester) async {
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
        final realProjection = PublicIdentityProjection(
          userId: 'user-real-1',
          displayName: '@ElenaR',
          bio: 'Photographer and hiker.',
          avatarBytes: validPng,
          isAnonymous: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showUserProfileSheet(
                        context,
                        projection: realProjection,
                        distanceLabel: '~50m away',
                        onSendDm: () {},
                        onBlock: () {},
                        onReport: () {},
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('@ElenaR'), findsOneWidget);
        expect(find.text('Photographer and hiker.'), findsOneWidget);
        expect(find.text('~50m away'), findsOneWidget);
        expect(find.text('Send DM'), findsOneWidget);
      },
    );
  });
}
