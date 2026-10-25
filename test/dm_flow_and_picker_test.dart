import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proximity_app/core/network/api_client.dart';
import 'package:proximity_app/core/models/models.dart';
import 'package:proximity_app/core/state/app_controller.dart';
import 'package:proximity_app/features/chat/chat_image_widgets.dart';
import 'package:proximity_app/features/inbox/inbox_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DM Flow, Inbox State, and Image Picker Tests', () {
    test('sendDmRequest creates pending request, sets inbox tab, and is idempotent without duplicates', () {
      final controller = AppController();

      // Initial count of DM requests
      final initialCount = controller.allDmRequestsRaw.length;

      // 1. Send DM request to a new member
      final err = controller.sendDmRequest(
        toUserId: 'user-new-member',
        toDisplayName: '@new_member',
        introMessage: 'Hi there!',
      );
      expect(err, isNull);
      expect(controller.allDmRequestsRaw.length, initialCount + 1);

      // Verify inbox tab requested
      expect(controller.consumeRequestedTabIndex(), 3);
      final createdThreadId = controller.pendingOpenDmThreadId;
      expect(createdThreadId, isNotNull);

      // Check the created thread in pending requests
      final created = controller.dmThreadById(createdThreadId!);
      expect(created, isNotNull);
      expect(created!.status, DmRequestStatus.pending);
      expect(created.toUserId, 'user-new-member');
      expect(created.introMessage, 'Hi there!');

      // 2. Tapping Send DM again for the same member
      final err2 = controller.sendDmRequest(
        toUserId: 'user-new-member',
        toDisplayName: '@new_member',
        introMessage: 'Second attempt',
      );
      expect(err2, isNull);
      // No duplicate thread created
      expect(controller.allDmRequestsRaw.length, initialCount + 1);
      // Navigates to Inbox
      expect(controller.consumeRequestedTabIndex(), 3);
      // Focuses existing thread
      expect(controller.consumePendingOpenDmThreadId(), createdThreadId);
    });

    testWidgets('InboxScreen auto-opens thread sheet on sendDmRequest, displays Pending badge, and allows re-opening', (tester) async {
      final controller = AppController();

      // Send DM request to create an outgoing pending request
      controller.sendDmRequest(
        toUserId: 'target-user-99',
        toDisplayName: '@target99',
        introMessage: 'Let us connect on Proximity',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InboxScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Thread sheet automatically opened because pendingOpenDmThreadId was set
      expect(find.text('Outgoing Request (Pending)'), findsOneWidget);
      expect(find.text('Chat locked until recipient accepts request'), findsOneWidget);

      // Close the modal sheet by tapping outside or dragging down
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // 2. Now back in Inbox view: Pending badge chip is rendered on the list item
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Sent to @target99'), findsOneWidget);
      expect(find.text('"Let us connect on Proximity"'), findsOneWidget);

      // 3. Tapping the card re-opens the thread sheet
      await tester.tap(find.text('Sent to @target99'));
      await tester.pumpAndSettle();

      expect(find.text('Outgoing Request (Pending)'), findsOneWidget);
    });

    testWidgets('Incoming pending request allows accepting and transitions to active messaging', (tester) async {
      final controller = AppController();

      // Inject incoming pending request
      final incomingReq = DmRequest(
        id: 'incoming-req-1',
        fromUserId: 'sender-123',
        fromDisplayName: '@sender123',
        fromIsAnonymous: false,
        toUserId: controller.profile.id,
        toDisplayName: controller.profile.publicDisplayName,
        introMessage: 'Hey, I saw you nearby!',
        createdAt: DateTime.now(),
        status: DmRequestStatus.pending,
      );
      controller.injectMockDmRequest(incomingReq);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InboxScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('From @sender123'), findsOneWidget);

      // Tap card to open sheet
      await tester.tap(find.text('From @sender123'));
      await tester.pumpAndSettle();

      expect(find.text('Incoming Request (Pending)'), findsOneWidget);
      expect(find.text('Accept Request'), findsOneWidget);

      // Tap Accept
      await tester.tap(find.text('Accept Request'));
      await tester.pumpAndSettle();

      // Verified: status transitioned to accepted and active composer unlocked!
      expect(find.text('Incoming Request (Pending)'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('Staged image preview bar renders and sends attachment in accepted thread', (tester) async {
      final controller = AppController();

      // Add accepted DM thread
      final acceptedReq = DmRequest(
        id: 'accepted-thread-1',
        fromUserId: controller.profile.id,
        fromDisplayName: controller.profile.publicDisplayName,
        fromIsAnonymous: false,
        toUserId: 'friend-456',
        toDisplayName: '@friend456',
        introMessage: 'Accepted intro',
        createdAt: DateTime.now(),
        status: DmRequestStatus.accepted,
      );
      controller.injectMockDmRequest(acceptedReq);

      // Stage an image in this channel
      // Valid minimal JPEG bytes
      final minimalJpeg = Uint8List.fromList(<int>[
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xC0, 0x00, 0x0B,
        0x08, 0x00, 0x0A, 0x00, 0x0A, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xDA, 0x00,
        0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xBF, 0x00, 0xFF, 0xD9,
      ]);
      final uploadId = controller.stageImageUpload(
        channelId: 'accepted-thread-1',
        rawBytes: minimalJpeg,
      );
      expect(uploadId, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InboxScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the accepted thread
      await tester.tap(find.byKey(const Key('inbox-thread-tile-accepted-thread-1')));
      await tester.pumpAndSettle();

      // Staged image preview bar is displayed!
      expect(find.byType(StagedImagePreviewBar), findsOneWidget);
      expect(find.textContaining('Photo staged'), findsOneWidget);

      // Tap Send
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Message with attachment is sent and displayed in chat
      final updatedThread = controller.dmThreadById('accepted-thread-1');
      expect(updatedThread!.messages.length, 1);
      expect(updatedThread.messages.first.attachment, isNotNull);
    });

    test('ApiClient direct messaging endpoints serialization and deserialization', () async {
      final mock = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/dm/requests') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['recipient_id'], 'user-target-id');
          expect(body['intro_message'], 'Hello API');
          return http.Response(
            jsonEncode({
              'id': 'conv-123',
              'initiator_id': 'user-me-id',
              'recipient_id': 'user-target-id',
              'status': 'pending',
              'intro_message': 'Hello API',
              'other_user': {
                'user_id': 'user-target-id',
                'display_name': '@target_api',
                'bio': 'Developer',
                'is_anonymous': false,
              },
              'is_incoming': false,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'GET' && request.url.path == '/dm/inbox') {
          return http.Response(
            jsonEncode([
              {
                'id': 'conv-123',
                'initiator_id': 'user-me-id',
                'recipient_id': 'user-target-id',
                'status': 'pending',
                'intro_message': 'Hello API',
                'other_user': {
                  'user_id': 'user-target-id',
                  'display_name': '@target_api',
                  'bio': 'Developer',
                  'is_anonymous': false,
                },
                'is_incoming': false,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' && request.url.path == '/dm/conversations/conv-123/respond') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['accept'], isTrue);
          return http.Response(
            jsonEncode({
              'id': 'conv-123',
              'initiator_id': 'user-other-id',
              'recipient_id': 'user-me-id',
              'status': 'accepted',
              'intro_message': 'Accepted now',
              'other_user': {
                'user_id': 'user-other-id',
                'display_name': '@other_api',
                'bio': '',
                'is_anonymous': false,
              },
              'is_incoming': true,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' && request.url.path == '/dm/conversations/conv-123/messages') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['body'], 'Testing DM post');
          return http.Response(
            jsonEncode({
              'id': 'msg-1',
              'channel_id': 'conv-123',
              'sender_id': 'user-me-id',
              'sender_display_name': '@me',
              'is_anonymous': false,
              'body': 'Testing DM post',
              'sequence': 1,
              'area_name': '',
              'distance_label': '',
              'is_system_notice': false,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'expires_at': DateTime.now().add(const Duration(hours: 24)).toUtc().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final client = ApiClient(baseUrl: 'http://localhost:8000', client: mock, initialAccessToken: 'test-token');

      // 1. Create DM request
      final req = await client.createDmRequest('user-target-id', introMessage: 'Hello API');
      expect(req.id, 'conv-123');
      expect(req.status, 'pending');
      expect(req.otherUser.displayName, '@target_api');

      // 2. Get inbox
      final inbox = await client.getDmInbox();
      expect(inbox.length, 1);
      expect(inbox.first.id, 'conv-123');

      // 3. Respond
      final responded = await client.respondToDmRequest('conv-123', accept: true);
      expect(responded.status, 'accepted');

      // 4. Post message
      final msg = await client.postDmMessage('conv-123', body: 'Testing DM post');
      expect(msg.body, 'Testing DM post');
      expect(msg.sequence, 1);
    });
  });
}
