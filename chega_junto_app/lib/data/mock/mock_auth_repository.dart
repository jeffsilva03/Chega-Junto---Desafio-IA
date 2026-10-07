import '../repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<void> signInDemo() =>
      Future<void>.delayed(const Duration(milliseconds: 400));
}
