abstract interface class AuthTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Memory-only on Android and Web. Passwords are never stored here.
class MemoryAuthTokenStore implements AuthTokenStore {
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

/// An old account's pending requests can never borrow a subsequent account's token.
class ScopedAuthTokenStore implements AuthTokenStore {
  ScopedAuthTokenStore(this.store, this.isActive);
  final AuthTokenStore store;
  final bool Function() isActive;
  @override
  Future<String?> read() async {
    if (!isActive()) return null;
    final token = await store.read();
    return isActive() ? token : null;
  }

  @override
  Future<void> write(String token) =>
      throw UnsupportedError('Read-only session scope.');
  @override
  Future<void> clear() => throw UnsupportedError('Read-only session scope.');
}
