abstract class AuthSessionStore {
  Future<String?> getSavedSessionUsername();
  Future<void> saveSessionUsername(String username);
  Future<void> clearSession();
}

/// In-memory demo session store for prototyping and tests.
/// Never stores passwords or secrets.
class LocalDemoSessionStore implements AuthSessionStore {
  LocalDemoSessionStore({String? initialUsername})
    : _savedUsername = initialUsername;

  String? _savedUsername;

  @override
  Future<String?> getSavedSessionUsername() async => _savedUsername;

  @override
  Future<void> saveSessionUsername(String username) async {
    _savedUsername = username;
  }

  @override
  Future<void> clearSession() async {
    _savedUsername = null;
  }
}
