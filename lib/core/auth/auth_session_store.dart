abstract class AuthSessionStore {
  Future<String?> getSavedSessionUsername();
  Future<void> saveSessionUsername(String username);
  Future<void> clearSession();

  Future<String?> getAccessToken() async => null;
  Future<String?> getRefreshToken() async => null;
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  Future<void> clearTokens() async {}
}

/// In-memory demo session store for prototyping and tests.
/// Never stores passwords or secrets.
class LocalDemoSessionStore implements AuthSessionStore {
  LocalDemoSessionStore({
    String? initialUsername,
    String? initialAccessToken,
    String? initialRefreshToken,
  })  : _savedUsername = initialUsername,
        _accessToken = initialAccessToken,
        _refreshToken = initialRefreshToken;

  String? _savedUsername;
  String? _accessToken;
  String? _refreshToken;

  @override
  Future<String?> getSavedSessionUsername() async => _savedUsername;

  @override
  Future<void> saveSessionUsername(String username) async {
    _savedUsername = username;
  }

  @override
  Future<void> clearSession() async {
    _savedUsername = null;
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
