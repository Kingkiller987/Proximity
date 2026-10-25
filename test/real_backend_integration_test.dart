@Tags(['live-backend'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_app/core/network/api_client.dart';
import 'package:proximity_app/core/network/api_models.dart';

void main() {
  const backendBaseUrl = 'http://localhost:8000';

  group('Real Backend E2E Integration (FastAPI + PostGIS)', () {
    late ApiClient client;
    bool isBackendAvailable = false;

    setUpAll(() async {
      client = ApiClient(baseUrl: backendBaseUrl);
      try {
        final socket = await Socket.connect('localhost', 8000, timeout: const Duration(seconds: 2));
        await socket.close();
        final health = await client.healthCheck();
        isBackendAvailable = health['status'] == 'ok';
      } catch (_) {
        isBackendAvailable = false;
      }
    });

    test('Backend health and PostGIS extension are functional', () async {
      if (!isBackendAvailable) {
        markTestSkipped('Local backend not reachable on $backendBaseUrl');
        return;
      }

      final health = await client.healthCheck();
      expect(health['status'], 'ok');
      expect(health['service'], 'proximity-api');

      final dbHealth = await client.databaseHealth();
      expect(dbHealth['status'], 'ok');
      expect(dbHealth['database'], 'proximity');
      expect(dbHealth['postgis_version'], contains('3.5'));
    });

    test('Landmarks endpoint returns seeded SBU campus locations with PostGIS distances', () async {
      if (!isBackendAvailable) {
        markTestSkipped('Local backend not reachable on $backendBaseUrl');
        return;
      }

      // Query near Staller Steps: 40.9154, -73.1225
      final landmarks = await client.getLandmarks(
        latitude: 40.9154,
        longitude: -73.1225,
      );

      expect(landmarks.length, greaterThanOrEqualTo(5));
      final staller = landmarks.firstWhere((l) => l.name == 'Staller Steps');
      expect(staller.areaName, contains('Staller Steps'));
      expect(staller.isUserInside, isTrue);
      expect(staller.distanceMeters, lessThan(10.0));
    });

    test('User registration, login, and profile retrieval work against live PostgreSQL', () async {
      if (!isBackendAvailable) {
        markTestSkipped('Local backend not reachable on $backendBaseUrl');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch % 100000000;
      final uniqueUsername = 'u_$timestamp';
      final email = '$uniqueUsername@sbuhacks.test';
      const password = 'StrongPassword999!';

      // 1. Register
      final registerTokens = await client.register(
        username: uniqueUsername,
        email: email,
        password: password,
      );
      expect(registerTokens.accessToken, isNotEmpty);
      expect(registerTokens.refreshToken, isNotEmpty);
      expect(client.isAuthenticated, isTrue);

      // 2. Fetch Profile
      final me = await client.getMe();
      expect(me.username, uniqueUsername);
      expect(me.email, email);
      expect(me.anonymousHandle, isNotEmpty);
      expect(me.visibleInNearby, isTrue);

      // 3. Update bio and nearby radius
      final updatedMe = await client.updateMe(
        bio: 'Hacking on Proximity at SBUHacks!',
        nearbyRadiusMeters: 1000.0,
      );
      expect(updatedMe.bio, 'Hacking on Proximity at SBUHacks!');
      expect(updatedMe.nearbyRadiusMeters, 1000.0);

      // 4. Login with fresh client
      final freshClient = ApiClient(baseUrl: backendBaseUrl);
      final loginTokens = await freshClient.login(
        username: uniqueUsername,
        password: password,
      );
      expect(loginTokens.accessToken, isNotEmpty);
      expect(freshClient.isAuthenticated, isTrue);
      final freshMe = await freshClient.getMe();
      expect(freshMe.username, uniqueUsername);
    });

    test('Live Event lifecycle: creation, retrieval, starting, and messaging', () async {
      if (!isBackendAvailable) {
        markTestSkipped('Local backend not reachable on $backendBaseUrl');
        return;
      }

      // Ensure authenticated client
      final timestamp = DateTime.now().millisecondsSinceEpoch % 100000000;
      final hostUsername = 'host_$timestamp';
      await client.register(
        username: hostUsername,
        email: '$hostUsername@sbuhacks.test',
        password: 'HostPassword123!',
      );

      final startsAt = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final eventData = {
        'title': 'SBUHacks Demo Event $timestamp',
        'description': 'Live testing integration with PostGIS',
        'category_tag': 'social',
        'latitude': 40.9154,
        'longitude': -73.1225,
        'area_name': 'Staller Steps',
        'radius_meters': 150.0,
        'access_type': 'public',
        'starts_at': startsAt.toIso8601String(),
        'duration_seconds': 7200,
        'venue_timezone': 'America/New_York',
        'default_open_minutes': 540,
        'default_close_minutes': 1320,
      };

      // 1. Create event
      final createdEvent = await client.createEvent(eventData);
      expect(createdEvent.title, eventData['title']);
      expect(createdEvent.isHost, isTrue);
      expect(createdEvent.isStarted, isFalse);

      // 2. Fetch event by ID
      final fetchedEvent = await client.getEvent(createdEvent.id);
      expect(fetchedEvent.id, createdEvent.id);
      expect(fetchedEvent.description, 'Live testing integration with PostGIS');

      // 3. Start event
      final locationFix = LocationFixRequest(
        latitude: 40.9154,
        longitude: -73.1225,
        accuracyMeters: 5.0,
        recordedAt: DateTime.now().toUtc(),
        areaName: 'Staller Steps',
      );
      final startedEvent = await client.startEvent(createdEvent.id, locationFix);
      expect(startedEvent.isStarted, isTrue);
      expect(startedEvent.startedAt, isNotNull);

      // 4. Send message inside event venue radius
      final msg = await client.postEventMessage(
        createdEvent.id,
        body: 'Welcome to the live demo event!',
        fix: LocationFixRequest(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 5.0,
          recordedAt: DateTime.now().toUtc(),
          areaName: 'Staller Steps',
        ),
      );
      expect(msg.body, 'Welcome to the live demo event!');
      expect(msg.sequence, greaterThanOrEqualTo(1));

      // 5. Query event messages
      final messages = await client.getEventMessages(createdEvent.id);
      expect(messages.any((m) => m.id == msg.id), isTrue);

      // 6. End event
      final endedEvent = await client.endEvent(createdEvent.id);
      expect(endedEvent.isEnded, isTrue);
    });

    test('Live Nearby discovery respects visibility and spatial proximity', () async {
      if (!isBackendAvailable) {
        markTestSkipped('Local backend not reachable on $backendBaseUrl');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch % 100000000;
      final nearbyUsername = 'near_$timestamp';
      await client.register(
        username: nearbyUsername,
        email: '$nearbyUsername@sbuhacks.test',
        password: 'NearbyPassword123!',
      );

      // Enter a landmark to become active in nearby
      final landmarks = await client.getLandmarks();
      final staller = landmarks.firstWhere((l) => l.name == 'Staller Steps');

      await client.enterLandmark(
        staller.id,
        LocationFixRequest(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 5.0,
          recordedAt: DateTime.now().toUtc(),
          areaName: staller.areaName,
        ),
      );

      final nearbyList = await client.discoverNearby(
        LocationFixRequest(
          latitude: 40.9154,
          longitude: -73.1225,
          accuracyMeters: 5.0,
          recordedAt: DateTime.now().toUtc(),
          areaName: staller.areaName,
        ),
      );

      expect(nearbyList, isNotEmpty);
      // The current authenticated user should appear in results as (You)
      expect(nearbyList.any((p) => p.displayName.contains('(You)')), isTrue);
    });

    test('End-to-end direct messaging, request acceptance, and image upload on live backend', () async {
      if (!isBackendAvailable) {
        markTestSkipped('Local backend not reachable on $backendBaseUrl');
        return;
      }

      final ts = DateTime.now().millisecondsSinceEpoch % 100000000;
      final aliceName = 'dm_a_$ts';
      final bobName = 'dm_b_$ts';

      final clientA = ApiClient(baseUrl: backendBaseUrl);
      final clientB = ApiClient(baseUrl: backendBaseUrl);

      // Register Alice
      await clientA.register(
        username: aliceName,
        email: '$aliceName@sbuhacks.test',
        password: 'Password123!',
      );
      final aliceProfile = await clientA.getMe();

      // Register Bob
      await clientB.register(
        username: bobName,
        email: '$bobName@sbuhacks.test',
        password: 'Password123!',
      );
      final bobProfile = await clientB.getMe();

      // 1. Alice sends DM request to Bob
      final req = await clientA.createDmRequest(
        bobProfile.id,
        introMessage: 'Hello from live test!',
      );
      expect(req.status, 'pending');
      expect(req.recipientId, bobProfile.id);
      expect(req.isIncoming, isFalse);

      final convId = req.id;

      // 2. Idempotency on live backend
      final req2 = await clientA.createDmRequest(
        bobProfile.id,
        introMessage: 'Repeat',
      );
      expect(req2.id, convId);

      // 3. Bob checks inbox
      final bobInbox = await clientB.getDmInbox();
      expect(bobInbox.any((c) => c.id == convId), isTrue);
      final bConv = bobInbox.firstWhere((c) => c.id == convId);
      expect(bConv.status, 'pending');
      expect(bConv.isIncoming, isTrue);

      // 4. Bob accepts the DM request
      final accepted = await clientB.respondToDmRequest(convId, accept: true);
      expect(accepted.status, 'accepted');

      // 5. Alice sends a direct message
      final msgA = await clientA.postDmMessage(convId, body: 'Thanks for connecting!');
      expect(msgA.sequence, 1);
      expect(msgA.body, 'Thanks for connecting!');

      // 6. Bob uploads an image and sends with attachment
      final minimalJpeg = <int>[
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xC0, 0x00, 0x0B,
        0x08, 0x00, 0x0A, 0x00, 0x0A, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xDA, 0x00,
        0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xBF, 0x00, 0xFF, 0xD9,
      ];
      final mediaUpload = await clientB.uploadMedia(
        bytes: minimalJpeg,
        filename: 'live_test.jpg',
        mimeType: 'image/jpeg',
        channelId: convId,
        channelKind: 'dm',
      );
      expect(mediaUpload.mediaId, isNotEmpty);

      final msgB = await clientB.postDmMessage(
        convId,
        body: 'Here is my photo',
        attachmentId: mediaUpload.mediaId,
      );
      expect(msgB.sequence, 2);
      expect(msgB.attachmentId, mediaUpload.mediaId);

      // 7. Alice fetches messages and verifies both messages
      final messages = await clientA.getDmMessages(convId);
      expect(messages.length, 2);
      expect(messages[0].body, 'Thanks for connecting!');
      expect(messages[1].attachmentId, mediaUpload.mediaId);
    });
  });
}
