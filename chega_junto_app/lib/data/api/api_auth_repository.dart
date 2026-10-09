import '../../core/network/api_client.dart';
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';
import 'api_mapping.dart';

class ApiAuthRepository extends AuthRepository {
  ApiAuthRepository(this.client);
  final ApiClient client;
  @override
  bool get supportsDemo => false;
  @override
  String get identityLabel => 'E-mail';
  @override
  String get logoutLabel => 'Sair da conta';
  @override
  String get loginHint =>
      'Use somente dados fictícios.\nGoogle e recuperação de senha ainda não estão disponíveis.';
  @override
  String? validateIdentity(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Informe um e-mail válido.';
  @override
  String? validateLoginPassword(String? value) =>
      validateRegistrationPassword(value);
  @override
  Future<void> signInDemo() async =>
      throw UnsupportedError('Acesso demonstrativo indisponível.');
  AuthUser _user(Json j) => AuthUser(
    id: decimalId(j['id']),
    fullName: j['full_name'],
    email: j['email'],
  );
  Future<AuthResult> _authenticate(String path, Json body) async {
    final j = await client.request(
      'POST',
      '/api/v1/auth/$path',
      body: body,
      authenticated: false,
    );
    if (j['token_type'] != 'bearer' ||
        j['access_token'] is! String ||
        (j['access_token'] as String).isEmpty) {
      throw const FormatException('Invalid authentication response');
    }
    return AuthResult(_user(j['user']), accessToken: j['access_token']);
  }

  @override
  Future<AuthResult> login(String email, String password) => _authenticate(
    'login',
    {'email': email.trim().toLowerCase(), 'password': password},
  );
  @override
  Future<AuthResult> register(String name, String email, String password) =>
      _authenticate('register', {
        'full_name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      });
  @override
  Future<AuthUser> me() async =>
      _user(await client.request('GET', '/api/v1/auth/me'));
}
