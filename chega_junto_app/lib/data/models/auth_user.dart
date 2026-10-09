class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
  });
  final String id, fullName, email;
}

class AuthResult {
  const AuthResult(this.user, {this.accessToken});
  final AuthUser user;
  final String? accessToken;
}
