import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';

class MockProfileRepository implements ProfileRepository {
  const MockProfileRepository();
  @override
  Future<UserProfile> loadProfile() async => const UserProfile(
    fullName: 'Maria da Silva',
    email: 'maria@example.test',
    phone: '(11) 99999-9999',
    susCardNumber: '700 1234 5678 9012',
  );
}
