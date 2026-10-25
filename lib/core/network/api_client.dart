import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_models.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, [this.details]);

  final int statusCode;
  final String message;
  final dynamic details;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    String? initialAccessToken,
    String? initialRefreshToken,
  })  : _client = client ?? http.Client(),
        _accessToken = initialAccessToken,
        _refreshToken = initialRefreshToken;

  final String baseUrl;
  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  void setTokens({String? accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    if (queryParams == null || queryParams.isEmpty) {
      return Uri.parse(fullUrl);
    }

    final sanitizedParams = <String, String>{};
    queryParams.forEach((key, value) {
      if (value != null) {
        sanitizedParams[key] = value.toString();
      }
    });

    return Uri.parse(fullUrl).replace(queryParameters: sanitizedParams);
  }

  Map<String, String> _buildHeaders({bool isJson = true, bool requiresAuth = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (requiresAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<http.Response> _sendWithAuthRetry(
    Future<http.Response> Function() requestSender,
  ) async {
    final response = await requestSender();

    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _attemptTokenRefresh();
      if (refreshed) {
        return await requestSender();
      }
    }

    return response;
  }

  Future<bool> _attemptTokenRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final res = await _client.post(
        _uri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final tokenRes = TokenResponse.fromJson(decoded);
        _accessToken = tokenRes.accessToken;
        _refreshToken = tokenRes.refreshToken;
        return true;
      }
    } catch (_) {
      // Fall through on refresh failure
    }
    clearTokens();
    return false;
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String errorMessage = 'Request failed with status ${response.statusCode}';
    dynamic details;
    try {
      final body = jsonDecode(response.body);
      details = body;
      if (body is Map && body.containsKey('detail')) {
        errorMessage = body['detail'].toString();
      }
    } catch (_) {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }

    throw ApiException(response.statusCode, errorMessage, details);
  }

  // --- HEALTH ---

  Future<Map<String, dynamic>> healthCheck() async {
    final res = await _client.get(_uri('/health'));
    return (_processResponse(res) as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> databaseHealth() async {
    final res = await _client.get(_uri('/health/database'));
    return (_processResponse(res) as Map<String, dynamic>?) ?? {};
  }

  // --- AUTH ---

  Future<TokenResponse> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      _uri('/auth/register'),
      headers: _buildHeaders(requiresAuth: false),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    final token = TokenResponse.fromJson(data);
    setTokens(accessToken: token.accessToken, refreshToken: token.refreshToken);
    return token;
  }

  Future<TokenResponse> login({
    required String username,
    required String password,
  }) async {
    final res = await _client.post(
      _uri('/auth/login'),
      headers: _buildHeaders(requiresAuth: false),
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    final token = TokenResponse.fromJson(data);
    setTokens(accessToken: token.accessToken, refreshToken: token.refreshToken);
    return token;
  }

  Future<TokenResponse> refresh({required String refreshToken}) async {
    final res = await _client.post(
      _uri('/auth/refresh'),
      headers: _buildHeaders(requiresAuth: false),
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    final token = TokenResponse.fromJson(data);
    setTokens(accessToken: token.accessToken, refreshToken: token.refreshToken);
    return token;
  }

  Future<void> logout() async {
    try {
      if (_refreshToken != null) {
        await _client.post(
          _uri('/auth/logout'),
          headers: _buildHeaders(),
          body: jsonEncode({'refresh_token': _refreshToken}),
        );
      }
    } finally {
      clearTokens();
    }
  }

  // --- USERS ---

  Future<UserProfileResponse> getMe() async {
    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/users/me'), headers: _buildHeaders()),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return UserProfileResponse.fromJson(data);
  }

  Future<UserProfileResponse> updateMe({
    String? bio,
    String? identityMode,
    bool? visibleInNearby,
    double? nearbyRadiusMeters,
  }) async {
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (identityMode != null) body['identity_mode'] = identityMode;
    if (visibleInNearby != null) body['visible_in_nearby'] = visibleInNearby;
    if (nearbyRadiusMeters != null) body['nearby_radius_meters'] = nearbyRadiusMeters;

    final res = await _sendWithAuthRetry(
      () => _client.patch(
        _uri('/users/me'),
        headers: _buildHeaders(),
        body: jsonEncode(body),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return UserProfileResponse.fromJson(data);
  }

  Future<UserProfileResponse> setGhostMode({required bool enabled}) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/users/me/ghost-mode', {'enabled': enabled}),
        headers: _buildHeaders(),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return UserProfileResponse.fromJson(data);
  }

  Future<PublicIdentityProjection> getPublicUser(String userId) async {
    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/users/$userId'), headers: _buildHeaders()),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return PublicIdentityProjection.fromJson(data);
  }

  Future<void> blockUser(String userId) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(_uri('/users/$userId/block'), headers: _buildHeaders()),
    );
    _processResponse(res);
  }

  Future<void> unblockUser(String userId) async {
    final res = await _sendWithAuthRetry(
      () => _client.delete(_uri('/users/$userId/block'), headers: _buildHeaders()),
    );
    _processResponse(res);
  }

  // --- LANDMARKS ---

  Future<List<LandmarkResponse>> getLandmarks({
    double? latitude,
    double? longitude,
  }) async {
    final query = <String, dynamic>{};
    if (latitude != null) query['latitude'] = latitude;
    if (longitude != null) query['longitude'] = longitude;

    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/landmarks', query), headers: _buildHeaders(requiresAuth: false)),
    );
    final data = _processResponse(res) as List<dynamic>;
    return data.map((item) => LandmarkResponse.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<LandmarkVisitResponse> enterLandmark(
    String landmarkId,
    LocationFixRequest fix,
  ) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/landmarks/$landmarkId/enter'),
        headers: _buildHeaders(),
        body: jsonEncode(fix.toJson()),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return LandmarkVisitResponse.fromJson(data);
  }

  Future<LandmarkVisitResponse> landmarkHeartbeat(
    String landmarkId,
    LocationFixRequest fix,
  ) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/landmarks/$landmarkId/heartbeat'),
        headers: _buildHeaders(),
        body: jsonEncode(fix.toJson()),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return LandmarkVisitResponse.fromJson(data);
  }

  Future<void> leaveLandmark(String landmarkId) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(_uri('/landmarks/$landmarkId/leave'), headers: _buildHeaders()),
    );
    _processResponse(res);
  }

  Future<List<ChatMessageResponse>> getLandmarkMessages(
    String landmarkId, {
    int? limit,
    int? sinceSequence,
  }) async {
    final query = <String, dynamic>{};
    if (limit != null) query['limit'] = limit;
    if (sinceSequence != null) query['since_sequence'] = sinceSequence;

    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/landmarks/$landmarkId/messages', query), headers: _buildHeaders()),
    );
    final data = _processResponse(res) as List<dynamic>;
    return data.map((item) => ChatMessageResponse.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatMessageResponse> postLandmarkMessage(
    String landmarkId, {
    required String body,
    required LocationFixRequest fix,
    String? attachmentId,
  }) async {
    final reqBody = <String, dynamic>{
      'body': body,
      'location_fix': fix.toJson(),
    };
    if (attachmentId != null) {
      reqBody['attachment_id'] = attachmentId;
    }

    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/landmarks/$landmarkId/messages'),
        headers: _buildHeaders(),
        body: jsonEncode(reqBody),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return ChatMessageResponse.fromJson(data);
  }

  // --- EVENTS ---

  Future<List<EventResponse>> getEvents({
    double? latitude,
    double? longitude,
    String? categoryTag,
    String? areaName,
  }) async {
    final query = <String, dynamic>{};
    if (latitude != null) query['latitude'] = latitude;
    if (longitude != null) query['longitude'] = longitude;
    if (categoryTag != null) query['category'] = categoryTag;
    if (areaName != null) query['area_name'] = areaName;

    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/events', query), headers: _buildHeaders(requiresAuth: false)),
    );
    final data = _processResponse(res) as List<dynamic>;
    return data.map((item) => EventResponse.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<EventResponse> getEvent(String eventId) async {
    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/events/$eventId'), headers: _buildHeaders()),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return EventResponse.fromJson(data);
  }

  Future<EventResponse> createEvent(Map<String, dynamic> requestBody) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/events'),
        headers: _buildHeaders(),
        body: jsonEncode(requestBody),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return EventResponse.fromJson(data);
  }

  Future<dynamic> joinEvent(String eventId, {String? joinCode}) async {
    final body = <String, dynamic>{};
    if (joinCode != null) body['join_code'] = joinCode;

    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/events/$eventId/join'),
        headers: _buildHeaders(),
        body: jsonEncode(body),
      ),
    );
    return _processResponse(res);
  }

  Future<EventResponse> startEvent(String eventId, LocationFixRequest fix) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/events/$eventId/start'),
        headers: _buildHeaders(),
        body: jsonEncode(fix.toJson()),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return EventResponse.fromJson(data);
  }

  Future<EventResponse> endEvent(String eventId) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(_uri('/events/$eventId/end'), headers: _buildHeaders()),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return EventResponse.fromJson(data);
  }

  Future<void> transferEventHost(String eventId, String recipientUserId) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/events/$eventId/transfer-host'),
        headers: _buildHeaders(),
        body: jsonEncode({'recipient_user_id': recipientUserId}),
      ),
    );
    _processResponse(res);
  }

  Future<EventResponse> acceptEventTransfer(String eventId, LocationFixRequest fix) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/events/$eventId/accept-transfer'),
        headers: _buildHeaders(),
        body: jsonEncode(fix.toJson()),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return EventResponse.fromJson(data);
  }

  Future<List<ChatMessageResponse>> getEventMessages(
    String eventId, {
    int? limit,
  }) async {
    final query = <String, dynamic>{};
    if (limit != null) query['limit'] = limit;

    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/events/$eventId/messages', query), headers: _buildHeaders()),
    );
    final data = _processResponse(res) as List<dynamic>;
    return data.map((item) => ChatMessageResponse.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatMessageResponse> postEventMessage(
    String eventId, {
    required String body,
    required LocationFixRequest fix,
    String? attachmentId,
  }) async {
    final reqBody = <String, dynamic>{
      'body': body,
      'location_fix': fix.toJson(),
    };
    if (attachmentId != null) {
      reqBody['attachment_id'] = attachmentId;
    }

    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/events/$eventId/messages'),
        headers: _buildHeaders(),
        body: jsonEncode(reqBody),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return ChatMessageResponse.fromJson(data);
  }

  // --- NEARBY ---

  Future<List<NearbyParticipantResponse>> discoverNearby(LocationFixRequest fix) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/nearby'),
        headers: _buildHeaders(),
        body: jsonEncode(fix.toJson()),
      ),
    );
    final data = _processResponse(res) as List<dynamic>;
    return data.map((item) => NearbyParticipantResponse.fromJson(item as Map<String, dynamic>)).toList();
  }

  // --- MEDIA ---

  Future<MediaUploadResponse> uploadMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String channelId,
    required String channelKind,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/media/upload'));
    request.headers.addAll(_buildHeaders(isJson: false));
    request.fields['channel_id'] = channelId;
    request.fields['channel_kind'] = channelKind;
    final parts = mimeType.split('/');
    final primaryType = parts.isNotEmpty ? parts[0] : 'image';
    final subType = parts.length > 1 ? parts[1] : 'jpeg';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType(primaryType, subType),
      ),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final data = _processResponse(response) as Map<String, dynamic>;
    return MediaUploadResponse.fromJson(data);
  }

  Future<MediaDownloadTokenResponse> getMediaDownloadToken(String mediaId) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(_uri('/media/$mediaId/token'), headers: _buildHeaders()),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return MediaDownloadTokenResponse.fromJson(data);
  }

  Future<Uint8List> downloadMedia(String mediaId, {String? token}) async {
    final query = <String, dynamic>{};
    if (token != null) query['token'] = token;

    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/media/$mediaId', query), headers: _buildHeaders(isJson: false)),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    _processResponse(res);
    return Uint8List(0);
  }

  // --- DIRECT MESSAGING ---

  Future<DmConversationResponse> createDmRequest(
    String recipientId, {
    String introMessage = 'Hello!',
  }) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/dm/requests'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'recipient_id': recipientId,
          'intro_message': introMessage,
        }),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return DmConversationResponse.fromJson(data);
  }

  Future<List<DmConversationResponse>> getDmInbox({int limit = 50, int offset = 0}) async {
    final res = await _sendWithAuthRetry(
      () => _client.get(
        _uri('/dm/inbox', {'limit': '$limit', 'offset': '$offset'}),
        headers: _buildHeaders(),
      ),
    );
    final data = _processResponse(res) as List<dynamic>;
    return data.map((item) => DmConversationResponse.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<DmConversationResponse> getDmConversation(String conversationId) async {
    final res = await _sendWithAuthRetry(
      () => _client.get(_uri('/dm/conversations/$conversationId'), headers: _buildHeaders()),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return DmConversationResponse.fromJson(data);
  }

  Future<DmConversationResponse> respondToDmRequest(
    String conversationId, {
    required bool accept,
  }) async {
    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/dm/conversations/$conversationId/respond'),
        headers: _buildHeaders(),
        body: jsonEncode({'accept': accept}),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return DmConversationResponse.fromJson(data);
  }

  Future<List<ChatMessageResponse>> getDmMessages(String conversationId, {int limit = 50}) async {
    final res = await _sendWithAuthRetry(
      () => _client.get(
        _uri('/dm/conversations/$conversationId/messages', {'limit': '$limit'}),
        headers: _buildHeaders(),
      ),
    );
    final data = _processResponse(res) as List<dynamic>;
    return data.map((item) => ChatMessageResponse.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatMessageResponse> postDmMessage(
    String conversationId, {
    required String body,
    String? attachmentId,
  }) async {
    final payload = <String, dynamic>{'body': body};
    if (attachmentId != null) payload['attachment_id'] = attachmentId;

    final res = await _sendWithAuthRetry(
      () => _client.post(
        _uri('/dm/conversations/$conversationId/messages'),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ),
    );
    final data = _processResponse(res) as Map<String, dynamic>;
    return ChatMessageResponse.fromJson(data);
  }
}

