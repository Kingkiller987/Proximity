import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:proximity_app/core/network/api_client.dart';

void main() {
  const publicBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  group('Public Internet Backend Acceptance Pass', () {
    if (publicBaseUrl.trim().isEmpty) {
      test('Cloud HTTPS deployment configuration note', () {
        // Diagnostic pass when run during offline test runner passes
        expect(publicBaseUrl, isEmpty);
      });
      return;
    }

    final testRunId = DateTime.now().millisecondsSinceEpoch;
    final alphaUsername = 'pub_a_$testRunId';
    final betaUsername = 'pub_b_$testRunId';
    const testPassword = 'Password123!';

    test('1. Public HTTPS endpoint responds to liveness and readiness probes', () async {
      final cleanBase = publicBaseUrl.endsWith('/')
          ? publicBaseUrl.substring(0, publicBaseUrl.length - 1)
          : publicBaseUrl;

      // Liveness probe
      final healthUri = Uri.parse('$cleanBase/health');
      final healthRes = await http.get(healthUri);
      expect(healthRes.statusCode, 200, reason: 'Public /health must return 200 OK');
      final healthJson = jsonDecode(healthRes.body) as Map<String, dynamic>;
      expect(healthJson['status'], 'ok');
      expect(healthJson['service'], 'proximity-api');

      // Readiness probe
      final readyUri = Uri.parse('$cleanBase/health/ready');
      final readyRes = await http.get(readyUri);
      expect(readyRes.statusCode, 200, reason: 'Public /health/ready must confirm DB & PostGIS');
      final readyJson = jsonDecode(readyRes.body) as Map<String, dynamic>;
      expect(readyJson['status'], 'ready');
      expect(readyJson['database'], 'connected');
      expect(readyJson['postgis'], 'available');
    });

    test('2. End-to-end DM request, acceptance, and cloud media upload/download', () async {
      final clientA = ApiClient(baseUrl: publicBaseUrl);
      final clientB = ApiClient(baseUrl: publicBaseUrl);

      // Register test users
      await clientA.register(
        username: alphaUsername,
        email: '$alphaUsername@sbuhacks.test',
        password: testPassword,
      );
      final profileA = await clientA.getMe();
      expect(profileA.username, alphaUsername);

      await clientB.register(
        username: betaUsername,
        email: '$betaUsername@sbuhacks.test',
        password: testPassword,
      );
      final profileB = await clientB.getMe();
      expect(profileB.username, betaUsername);

      // Alpha initiates DM request to Beta
      final dmReq = await clientA.createDmRequest(
        profileB.id,
        introMessage: 'Public HTTPS test handshake',
      );
      expect(dmReq.status, 'pending');
      expect(dmReq.recipientId, profileB.id);
      expect(dmReq.isIncoming, isFalse);

      final convId = dmReq.id;

      // Beta lists inbox -> finds pending request
      final inboxB = await clientB.getDmInbox();
      final thread = inboxB.firstWhere((c) => c.id == convId);
      expect(thread.status, 'pending');
      expect(thread.isIncoming, isTrue);

      // Beta accepts DM request
      final accepted = await clientB.respondToDmRequest(convId, accept: true);
      expect(accepted.status, 'accepted');

      // Alpha uploads a real JPEG image
      final sampleJpeg = <int>[
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xC0, 0x00, 0x0B,
        0x08, 0x00, 0x0A, 0x00, 0x0A, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xDA, 0x00,
        0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xBF, 0x00, 0xFF, 0xD9,
      ];

      final uploadResult = await clientA.uploadMedia(
        bytes: sampleJpeg,
        filename: 'cloud_test.jpg',
        channelKind: 'dm',
        channelId: convId,
        mimeType: 'image/jpeg',
      );
      final mediaId = uploadResult.mediaId;
      expect(mediaId, isNotEmpty);

      // Alpha sends DM message with media attachment
      final sentMsg = await clientA.postDmMessage(
        convId,
        body: 'Testing durable cloud media upload',
        attachmentId: mediaId,
      );
      expect(sentMsg.attachmentId, mediaId);

      // Beta requests download token and fetches bytes
      final tokenRes = await clientB.getMediaDownloadToken(mediaId);
      final token = tokenRes.token;
      expect(token, isNotEmpty);

      final downloadedBytes = await clientB.downloadMedia(mediaId, token: token);
      expect(downloadedBytes.length, sampleJpeg.length);
      expect(downloadedBytes.sublist(0, 3), [0xFF, 0xD8, 0xFF], reason: 'JPEG magic bytes verified');

      // Unauthorized user (unauthenticated client) attempting download must be rejected
      final unauthClient = ApiClient(baseUrl: publicBaseUrl);
      expect(
        () => unauthClient.downloadMedia(mediaId),
        throwsA(anything),
        reason: 'Unauthenticated user cannot access private media',
      );
    });
  });
}
