import '../models/auth_user.dart';

abstract class AuthRepository {
  Future<void> signInDemo();
  bool get supportsDemo => true;
  String get identityLabel => 'E-mail ou CPF';
  String get loginHint =>
      'Acesso demonstrativo · dados fictícios\nUse um e-mail fictício e uma senha de 4 caracteres ou mais.';
  String get logoutLabel => 'Sair da demonstração';
  String? validateIdentity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe um e-mail ou CPF fictício.';
    if (RegExp(r'^\d{11}$').hasMatch(text.replaceAll(RegExp(r'[.\-\s]'), '')) ||
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return null;
    }
    return 'Use um e-mail ou CPF fictício válido.';
  }

  String? validateLoginPassword(String? value) =>
      (value?.runes.length ?? 0) >= 4
      ? null
      : 'Use uma senha fictícia com pelo menos 4 caracteres.';
  Future<AuthResult> login(String email, String password) async {
    await signInDemo();
    return AuthResult(await me());
  }

  Future<AuthResult> register(String name, String email, String password) =>
      login(email, password);
  Future<AuthUser> me() async => const AuthUser(
    id: 'mock',
    fullName: 'Maria da Silva',
    email: 'maria@example.test',
  );
}

String? validateRegistrationPassword(String? value) {
  final count = value?.runes.length ?? 0;
  return count >= 8 && count <= 128
      ? null
      : 'Use uma senha entre 8 e 128 caracteres.';
}
