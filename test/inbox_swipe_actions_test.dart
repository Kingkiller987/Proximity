import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/inbox/inbox_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5: Pure-Flutter Inbox Swipe Actions & Local Thread Management', () {
    testWidgets(
      'Swiping conversation tile left reveals Pin, Archive, and Delete action buttons',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: InboxScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Find an accepted thread tile
        final tileFinder = find.byKey(const Key('inbox-thread-tile-dm-2'));
        expect(tileFinder, findsOneWidget);

        // Swipe tile horizontally to the left
        await tester.drag(tileFinder, const Offset(-200, 0));
        await tester.pumpAndSettle();

        // Action buttons are revealed
        expect(find.byKey(const Key('inbox-action-pin-dm-2')), findsOneWidget);
        expect(
          find.byKey(const Key('inbox-action-archive-dm-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('inbox-action-delete-dm-2')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Pinning a thread moves it to the top with a pinned indicator',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: InboxScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Swipe dm-2 and tap Pin
        final tileFinder = find.byKey(const Key('inbox-thread-tile-dm-2'));
        await tester.drag(tileFinder, const Offset(-200, 0));
        await tester.pumpAndSettle();

        final pinBtn = find.byKey(const Key('inbox-action-pin-dm-2'));
        await tester.tap(pinBtn);
        await tester.pumpAndSettle();

        // Thread is now pinned in controller and displays pin icon
        final thread = controller.acceptedDmThreads.firstWhere(
          (t) => t.id == 'dm-2',
        );
        expect(thread.isPinned, isTrue);
        expect(find.byKey(const Key('inbox-pinned-icon-dm-2')), findsOneWidget);
      },
    );

    testWidgets(
      'Archiving a thread moves it to Archived view and unarchiving restores it',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: InboxScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Swipe dm-2 and tap Archive
        final tileFinder = find.byKey(const Key('inbox-thread-tile-dm-2'));
        await tester.drag(tileFinder, const Offset(-200, 0));
        await tester.pumpAndSettle();

        final archiveBtn = find.byKey(const Key('inbox-action-archive-dm-2'));
        await tester.tap(archiveBtn);
        await tester.pumpAndSettle();

        // Thread removed from Active view
        expect(find.byKey(const Key('inbox-thread-tile-dm-2')), findsNothing);

        // Switch to Archived filter
        final archivedTab = find.byKey(const Key('inbox-filter-archived'));
        expect(archivedTab, findsOneWidget);
        await tester.tap(archivedTab);
        await tester.pumpAndSettle();

        // Thread is present in Archived view
        expect(find.byKey(const Key('inbox-thread-tile-dm-2')), findsOneWidget);

        // Unarchive
        await tester.drag(
          find.byKey(const Key('inbox-thread-tile-dm-2')),
          const Offset(-200, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inbox-action-archive-dm-2')));
        await tester.pumpAndSettle();

        // Switched back to active: thread is restored
        final activeTab = find.byKey(const Key('inbox-filter-active'));
        await tester.tap(activeTab);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('inbox-thread-tile-dm-2')), findsOneWidget);
      },
    );

    testWidgets(
      'Deleting thread shows confirmation; confirming deletes locally while peer copy is preserved',
      (tester) async {
        final controller = AppController();

        await tester.pumpWidget(
          MaterialApp(home: InboxScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Swipe dm-2 and tap Delete
        final tileFinder = find.byKey(const Key('inbox-thread-tile-dm-2'));
        await tester.drag(tileFinder, const Offset(-200, 0));
        await tester.pumpAndSettle();

        final deleteBtn = find.byKey(const Key('inbox-action-delete-dm-2'));
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(
          find.textContaining('Delete Conversation Locally?'),
          findsOneWidget,
        );

        // Cancel keeps thread
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('inbox-thread-tile-dm-2')), findsOneWidget);

        // Tap Delete again and confirm
        await tester.drag(tileFinder, const Offset(-200, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inbox-action-delete-dm-2')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Thread is deleted locally for current user
        expect(find.byKey(const Key('inbox-thread-tile-dm-2')), findsNothing);

        // Thread is still preserved in controller data for peer
        final rawThread = controller.allDmRequestsRaw.firstWhere(
          (t) => t.id == 'dm-2',
        );
        expect(rawThread.deletedByUserIds.contains('user-me'), isTrue);
        expect(rawThread.deletedByUserIds.contains('user-pine'), isFalse);
      },
    );

    testWidgets(
      'Anonymous sender unmasked to recipient in incoming DM request card only',
      (tester) async {
        final controller = AppController();
        // Add incoming pending DM request with unmasked real info
        controller.injectMockDmRequest(
          DmRequest(
            id: 'dm-incoming-unmask',
            fromUserId: 'user-secret',
            fromDisplayName: 'ShadowHawk#303',
            fromIsAnonymous: true,
            fromRealUsername: 'SarahConnor',
            fromRealBio: 'Leading the resistance against bots.',
            toUserId: 'user-me',
            toDisplayName: 'Alex',
            introMessage: 'Please accept my connection request.',
            createdAt: controller.now,
            status: DmRequestStatus.pending,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: InboxScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Sender real username and bio are revealed in incoming request card
        expect(find.textContaining('@SarahConnor'), findsOneWidget);
        expect(find.textContaining('Leading the resistance'), findsOneWidget);
      },
    );
  });
}
