import '../models/user_profile.dart';
import '../models/health_record.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> loadProfile();
  Future<UserProfile> saveProfile(UserProfile profile);
  Future<HealthOverview> loadHealth();
  Future<HealthOverview> saveHealth(
    List<HealthItem> medications,
    List<HealthItem> allergies,
  );
}
