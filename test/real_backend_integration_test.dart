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
  });
}
