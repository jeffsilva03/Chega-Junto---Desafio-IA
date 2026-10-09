import 'package:flutter/foundation.dart';
import '../data/repositories/auth_repository.dart';
import '../core/auth/auth_token_store.dart';
import '../core/network/api_exception.dart';
import '../data/models/auth_user.dart';

enum SessionStatus { initializing, unauthenticated, authenticated }

/// Historical name retained for V2 callers; supports mock and authenticated API sessions.
class DemoSession extends ChangeNotifier {
  DemoSession(this.repository, {AuthTokenStore? tokenStore})
    : tokenStore = tokenStore ?? MemoryAuthTokenStore();
  final AuthRepository repository;
  final AuthTokenStore tokenStore;
  SessionStatus status = SessionStatus.unauthenticated;
  AuthUser? user;
  String? message;
  bool busy = false, _disposed = false;
  int epoch = 0, _attempt = 0;
  bool get signedIn => status == SessionStatus.authenticated;
  bool get initializing => status == SessionStatus.initializing;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    final attempt = ++_attempt;
    status = SessionStatus.initializing;
    _notify();
    try {
      final token = await tokenStore.read();
      if (token == null) {
        if (!_disposed && attempt == _attempt) {
          status = SessionStatus.unauthenticated;
        }
      } else {
        final identity = await repository.me();
        if (!_disposed && attempt == _attempt) {
          user = identity;
          status = SessionStatus.authenticated;
          epoch++;
        }
      }
    } catch (e) {
      if (!_disposed && attempt == _attempt) {
        if (e is UnauthorizedException) await tokenStore.clear();
        user = null;
        status = SessionStatus.unauthenticated;
        message = userError(e);
      }
    }
    if (!_disposed && attempt == _attempt) _notify();
  }

  Future<void> _authenticate(Future<AuthResult> Function() action) async {
    if (busy) return;
    final attempt = ++_attempt;
    busy = true;
    message = null;
    _notify();
    try {
      final result = await action();
      if (_disposed || attempt != _attempt) return;
      if (result.accessToken != null) {
        await tokenStore.write(result.accessToken!);
      }
      if (_disposed || attempt != _attempt) {
        if (await tokenStore.read() == result.accessToken) {
          await tokenStore.clear();
        }
        return;
      }
      // Validate the new bearer and use the canonical identity. A temporary
      // read failure does not undo a registration already committed by the API.
      if (result.accessToken != null) {
        try {
          final canonical = await repository.me();
          if (_disposed || attempt != _attempt) return;
          user = canonical;
        } on UnauthorizedException {
          if (_disposed || attempt != _attempt) return;
          final stored = await tokenStore.read();
          if (_disposed || attempt != _attempt) return;
          if (stored == result.accessToken) await tokenStore.clear();
          rethrow;
        } catch (_) {
          if (_disposed || attempt != _attempt) return;
          user = result.user;
        }
      } else {
        user = result.user;
      }
      if (_disposed || attempt != _attempt) return;
      status = SessionStatus.authenticated;
      epoch++;
    } finally {
      if (!_disposed && attempt == _attempt) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> login(String email, String password) =>
      _authenticate(() => repository.login(email, password));
  Future<void> register(String name, String email, String password) =>
      _authenticate(() => repository.register(name, email, password));
  Future<void> signIn() => _authenticate(() async {
    await repository.signInDemo();
    return AuthResult(await repository.me());
  });
  Future<void> signOut({bool expired = false}) async {
    _attempt++;
    status = SessionStatus.unauthenticated;
    user = null;
    busy = false;
    epoch++;
    message = expired ? 'Sua sessão expirou. Entre novamente.' : null;
    _notify();
    await tokenStore.clear();
  }

  Future<void> expire() => signOut(expired: true);
  @override
  void dispose() {
    _disposed = true;
    _attempt++;
    super.dispose();
  }
}
