import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:proximity_app/core/network/api_client.dart';
import 'package:proximity_app/core/network/api_models.dart';

void main() {
  group('Api Models Serialization & Deserialization', () {
    test('TokenResponse deserializes correctly', () {
      final json = {
        'access_token': 'test_acc_token',
        'refresh_token': 'test_ref_token',
        'token_type': 'bearer',
        'expires_in': 1800,
      };
      final res = TokenResponse.fromJson(json);
      expect(res.accessToken, 'test_acc_token');
      expect(res.refreshToken, 'test_ref_token');
      expect(res.tokenType, 'bearer');
      expect(res.expiresIn, 1800);

      final out = res.toJson();
      expect(out['access_token'], 'test_acc_token');
      expect(out['refresh_token'], 'test_ref_token');
    });

    test('UserProfileResponse deserializes correctly', () {
      final json = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'username': 'alex_runner',
        'email': 'alex@example.com',
        'anonymous_handle': 'Swift Falcon',
        'identity_mode': 'username',
        'visible_in_nearby': true,
        'ghost_browse_nearby': false,
        'is_ghost_mode': false,
        'nearby_radius_meters': 500.0,
        'message_retention_hours': 24,
        'bio': 'Exploring Long Island',
        'created_at': '2026-10-25T10:00:00.000Z',
      };
      final profile = UserProfileResponse.fromJson(json);
      expect(profile.id, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(profile.username, 'alex_runner');
      expect(profile.anonymousHandle, 'Swift Falcon');
      expect(profile.identityMode, 'username');
      expect(profile.visibleInNearby, isTrue);
      expect(profile.isGhostMode, isFalse);
      expect(profile.nearbyRadiusMeters, 500.0);
      expect(profile.messageRetentionHours, 24);
      expect(profile.bio, 'Exploring Long Island');
      expect(profile.createdAt.isUtc, isTrue);
    });

    test('LandmarkResponse and LandmarkVisitResponse deserialize correctly', () {
      final lmJson = {
        'id': '33333333-3333-3333-3333-333333333333',
        'name': 'Staller Steps',
        'area_name': 'Campus Center',
        'latitude': 40.9152,
        'longitude': -73.1234,
        'radius_meters': 100.0,
        'category': 'venue',
        'distance_meters': 42.5,
        'distance_label': '< 100m away',
        'is_user_inside': true,
      };
      final landmark = LandmarkResponse.fromJson(lmJson);
      expect(landmark.name, 'Staller Steps');
      expect(landmark.isUserInside, isTrue);
      expect(landmark.distanceMeters, 42.5);

      final visitJson = {
        'session_id': '44444444-4444-4444-4444-444444444444',
        'landmark_id': landmark.id,
        'entered_at': '2026-10-25T12:00:00.000Z',
        'last_heartbeat_at': '2026-10-25T12:01:00.000Z',
        'min_message_sequence': 5,
        'is_active': true,
      };
      final visit = LandmarkVisitResponse.fromJson(visitJson);
      expect(visit.sessionId, '44444444-4444-4444-4444-444444444444');
      expect(visit.minMessageSequence, 5);
      expect(visit.isActive, isTrue);
    });

    test('ChatMessageResponse deserializes correctly', () {
      final msgJson = {
        'id': '55555555-5555-5555-5555-555555555555',
        'channel_id': '33333333-3333-3333-3333-333333333333',
        'sender_id': '11111111-1111-1111-1111-111111111111',
        'sender_display_name': '@alex_runner',
        'is_anonymous': false,
        'body': 'Meeting by the steps soon!',
        'sequence': 12,
        'area_name': 'Campus Center',
        'distance_label': '< 100m away',
        'attachment_id': null,
        'is_system_notice': false,
        'created_at': '2026-10-25T12:05:00.000Z',
        'expires_at': '2026-10-26T12:05:00.000Z',
      };
      final msg = ChatMessageResponse.fromJson(msgJson);
      expect(msg.body, 'Meeting by the steps soon!');
      expect(msg.sequence, 12);
      expect(msg.isSystemNotice, isFalse);
    });

    test('EventResponse and NearbyParticipantResponse deserialize correctly', () {
      final evtJson = {
        'id': '66666666-6666-6666-6666-666666666666',
        'host_id': '11111111-1111-1111-1111-111111111111',
        'title': 'SBUHacks Hackathon',
        'description': 'Building next-generation location apps',
        'category_tag': 'social',
        'area_name': 'SAC Ballroom',
        'radius_meters': 150.0,
        'access_type': 'public',
        'starts_at': '2026-10-25T13:00:00.000Z',
        'expires_at': '2026-10-25T19:00:00.000Z',
        'venue_timezone': 'America/New_York',
        'default_open_minutes': 540,
        'default_close_minutes': 1320,
        'daily_overrides': {},
        'is_cancelled': false,
        'is_ended': false,
        'is_started': true,
        'started_at': '2026-10-25T13:00:00.000Z',
        'participant_count': 14,
        'is_joined': true,
        'is_host': true,
        'distance_label': 'On Site',
        'created_at': '2026-10-25T12:00:00.000Z',
      };
      final event = EventResponse.fromJson(evtJson);
      expect(event.title, 'SBUHacks Hackathon');
      expect(event.isStarted, isTrue);
      expect(event.isHost, isTrue);
      expect(event.participantCount, 14);

      final nearbyJson = {
        'user_id': '77777777-7777-7777-7777-777777777777',
        'display_name': 'Neon Hawk',
        'is_anonymous': true,
        'area_name': 'SAC Ballroom',
        'distance_label': '< 50m away',
        'visible_in_nearby': true,
      };
      final nearby = NearbyParticipantResponse.fromJson(nearbyJson);
      expect(nearby.displayName, 'Neon Hawk');
      expect(nearby.isAnonymous, isTrue);
    });
  });

  group('ApiClient HTTP Operations & Interceptors', () {
    const baseUrl = 'https://api.example.com';

    test('Health check succeeds', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response(
            jsonEncode({'status': 'ok', 'service': 'proximity-api'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(baseUrl: baseUrl, client: mock);
      final health = await client.healthCheck();
      expect(health['status'], 'ok');
      expect(health['service'], 'proximity-api');
    });

    test('Register sends correct payload and stores tokens', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/auth/register') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['username'], 'kingp');
          expect(body['email'], 'kingp@example.com');
          expect(body['password'], 'secretpass123');

          return http.Response(
            jsonEncode({
              'access_token': 'new_access_token',
              'refresh_token': 'new_refresh_token',
              'token_type': 'bearer',
              'expires_in': 3600,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Bad Request', 400);
      });

      final client = ApiClient(baseUrl: baseUrl, client: mock);
      expect(client.isAuthenticated, isFalse);

      final token = await client.register(
        username: 'kingp',
        email: 'kingp@example.com',
        password: 'secretpass123',
      );

      expect(token.accessToken, 'new_access_token');
      expect(client.isAuthenticated, isTrue);
      expect(client.accessToken, 'new_access_token');
      expect(client.refreshToken, 'new_refresh_token');
    });

    test('Login sends correct payload and stores tokens', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['username'], 'kingp');
          expect(body['password'], 'password888');

          return http.Response(
            jsonEncode({
              'access_token': 'login_access_token',
              'refresh_token': 'login_refresh_token',
              'token_type': 'bearer',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Unauthorized', 401);
      });

      final client = ApiClient(baseUrl: baseUrl, client: mock);
      final token = await client.login(
        username: 'kingp',
        password: 'password888',
      );

      expect(token.accessToken, 'login_access_token');
      expect(client.isAuthenticated, isTrue);
    });

    test('Authenticated request attaches Bearer token', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/users/me') {
          expect(request.headers['Authorization'], 'Bearer valid_token_123');
          return http.Response(
            jsonEncode({
              'id': 'user-123',
              'username': 'kingp',
              'email': 'kingp@example.com',
              'anonymous_handle': 'Swift Owl',
              'identity_mode': 'username',
              'visible_in_nearby': true,
              'ghost_browse_nearby': false,
              'is_ghost_mode': false,
              'nearby_radius_meters': 500.0,
              'message_retention_hours': 24,
              'bio': 'Proximity Lead Dev',
              'created_at': '2026-10-25T10:00:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Unauthorized', 401);
      });

      final client = ApiClient(
        baseUrl: baseUrl,
        client: mock,
        initialAccessToken: 'valid_token_123',
      );

      final me = await client.getMe();
      expect(me.username, 'kingp');
      expect(me.bio, 'Proximity Lead Dev');
    });

    test('401 triggers token refresh and retries successfully', () async {
      int requestMeAttempts = 0;

      final mock = MockClient((request) async {
        if (request.url.path == '/users/me') {
          requestMeAttempts++;
          if (requestMeAttempts == 1) {
            // First attempt with expired token fails
            expect(request.headers['Authorization'], 'Bearer expired_token');
            return http.Response(
              jsonEncode({'detail': 'Token expired'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          } else {
            // Second attempt with refreshed token succeeds
            expect(request.headers['Authorization'], 'Bearer newly_refreshed_access');
            return http.Response(
              jsonEncode({
                'id': 'user-123',
                'username': 'kingp',
                'email': 'kingp@example.com',
                'anonymous_handle': 'Swift Owl',
                'identity_mode': 'username',
                'visible_in_nearby': true,
                'ghost_browse_nearby': false,
                'is_ghost_mode': false,
                'nearby_radius_meters': 500.0,
                'message_retention_hours': 24,
                'bio': '',
                'created_at': '2026-10-25T10:00:00.000Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        } else if (request.url.path == '/auth/refresh') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['refresh_token'], 'valid_refresh_token');
          return http.Response(
            jsonEncode({
              'access_token': 'newly_refreshed_access',
              'refresh_token': 'newly_refreshed_refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(
        baseUrl: baseUrl,
        client: mock,
        initialAccessToken: 'expired_token',
        initialRefreshToken: 'valid_refresh_token',
      );

      final me = await client.getMe();
      expect(requestMeAttempts, 2);
      expect(me.username, 'kingp');
      expect(client.accessToken, 'newly_refreshed_access');
      expect(client.refreshToken, 'newly_refreshed_refresh');
    });

    test('Server errors throw ApiException with backend message', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Outside authorized landmark radius'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        baseUrl: baseUrl,
        client: mock,
        initialAccessToken: 'test_token',
      );

      expect(
        () => client.enterLandmark(
          'some-landmark-id',
          LocationFixRequest(
            latitude: 40.0,
            longitude: -73.0,
            accuracyMeters: 10.0,
            recordedAt: DateTime.now().toUtc(),
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', 'Outside authorized landmark radius'),
        ),
      );
    });

    test('Landmarks, Messages, Events, and Nearby API calls work', () async {
      final mock = MockClient((request) async {
        final path = request.url.path;
        if (path == '/landmarks') {
          return http.Response(
            jsonEncode([
              {
                'id': 'lm-1',
                'name': 'Staller Steps',
                'area_name': 'Campus',
                'latitude': 40.91,
                'longitude': -73.12,
                'radius_meters': 100.0,
                'category': 'venue',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/landmarks/lm-1/messages' && request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'msg-1',
                'channel_id': 'lm-1',
                'sender_id': 'user-1',
                'sender_display_name': 'Fox',
                'is_anonymous': true,
                'body': 'Hello campus',
                'sequence': 1,
                'area_name': 'Campus',
                'distance_label': '< 100m away',
                'attachment_id': null,
                'is_system_notice': false,
                'created_at': '2026-10-25T12:00:00.000Z',
                'expires_at': '2026-10-26T12:00:00.000Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/nearby' && request.method == 'POST') {
          return http.Response(
            jsonEncode([
              {
                'user_id': 'u-2',
                'display_name': 'Falcon',
                'is_anonymous': true,
                'area_name': 'Campus',
                'distance_label': '< 50m away',
                'visible_in_nearby': true,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(baseUrl: baseUrl, client: mock, initialAccessToken: 'tok');
      final landmarks = await client.getLandmarks();
      expect(landmarks.length, 1);
      expect(landmarks.first.name, 'Staller Steps');

      final msgs = await client.getLandmarkMessages('lm-1');
      expect(msgs.length, 1);
      expect(msgs.first.body, 'Hello campus');

      final nearby = await client.discoverNearby(
        LocationFixRequest(
          latitude: 40.91,
          longitude: -73.12,
          accuracyMeters: 5.0,
          recordedAt: DateTime.now().toUtc(),
        ),
      );
      expect(nearby.length, 1);
      expect(nearby.first.displayName, 'Falcon');
    });
  });
}
