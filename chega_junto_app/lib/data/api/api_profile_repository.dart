import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/health_record.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';
import 'api_mapping.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this.client);
  final ApiClient client;
  List<HealthRecord> _history = const [];

  UserProfile _profile(Json j) {
    final birth = (j['birth_date'] as String?)?.split('-');
    String text(String key) => j[key] as String? ?? '';
    return UserProfile(
      fullName: j['full_name'],
      email: j['email'],
      phone: text('phone'),
      susCardNumber: j['sus_card_number'] ?? '',
      birthDate: birth == null ? '' : '${birth[2]}/${birth[1]}/${birth[0]}',
      cpf: text('cpf'),
      postcode: text('postcode'),
      street: text('street'),
      number: text('number'),
      complement: j['complement'] ?? '',
      neighborhood: text('neighborhood'),
      city: [
        text('city'),
        text('state_code'),
      ].where((s) => s.isNotEmpty).join(' - '),
      emergencyName: text('emergency_name'),
      emergencyRelationship: text('emergency_relationship'),
      emergencyPhone: text('emergency_phone'),
    );
  }

  Json _writeProfile(UserProfile p) {
    final city = RegExp(
      r'^(.+?)\s*(?:-|/)\s*([a-zA-Z]{2})$',
    ).firstMatch(p.city.trim());
    final birth = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(p.birthDate);
    if ((p.city.trim().isNotEmpty && city == null) ||
        (p.birthDate.trim().isNotEmpty && birth == null)) {
      throw const ValidationException();
    }
    String? optional(String value) =>
        value.trim().isEmpty ? null : value.trim();
    return {
      'full_name': p.fullName,
      'email': p.email,
      'phone': optional(p.phone),
      'birth_date': birth == null
          ? null
          : '${birth[3]}-${birth[2]}-${birth[1]}',
      'cpf': optional(p.cpf),
      'postcode': optional(p.postcode),
      'street': optional(p.street),
      'number': optional(p.number),
      'complement': p.complement.trim().isEmpty ? null : p.complement,
      'neighborhood': optional(p.neighborhood),
      'city': city?[1]?.trim(),
      'state_code': city?[2]?.toUpperCase(),
      'emergency_name': optional(p.emergencyName),
      'emergency_relationship': optional(p.emergencyRelationship),
      'emergency_phone': optional(p.emergencyPhone),
    };
  }

  @override
  Future<UserProfile> loadProfile() async =>
      _profile(await client.request('GET', '/api/v1/me/profile'));
  @override
  Future<UserProfile> saveProfile(UserProfile profile) async => _profile(
    await client.request(
      'PUT',
      '/api/v1/me/profile',
      body: _writeProfile(profile),
    ),
  );

  HealthRecord _record(Json j) => HealthRecord(
    id: decimalId(j['id']),
    type: HealthRecordType.values.byName(j['type']),
    dateTime: instant(j['occurred_at']),
    title: j['title'],
    subtitle: j['subtitle'],
    reason: j['reason'] ?? '',
    summary: j['summary'] ?? '',
    professional: j['professional_text'] ?? '',
    facility: j['facility_text'] ?? '',
    notes: List<String>.from(j['notes'] ?? []),
    documents: objects(
      j['documents'] ?? [],
    ).map((d) => HealthDocument(d['title'], d['content_text'])).toList(),
  );
  HealthOverview _health(Json j) {
    List<HealthItem> items(String key) => objects(j[key])
        .map(
          (i) => HealthItem(
            id: decimalId(i['id']),
            serverId: decimalId(i['id']),
            name: i['name'],
            details: i['details'],
          ),
        )
        .toList();
    return HealthOverview(
      medications: items('medications'),
      allergies: items('allergies'),
      history: _history,
    );
  }

  @override
  Future<HealthOverview> loadHealth() async {
    final results = await Future.wait<Object>([
      client.request('GET', '/api/v1/me/health-items'),
      client.pages('/api/v1/me/health-records'),
    ]);
    _history = (results[1] as List<Json>).map(_record).toList();
    return _health(results[0] as Json);
  }

  @override
  Future<HealthRecord> loadHealthRecord(String id) async => _record(
    await client.request('GET', '/api/v1/me/health-records/${decimalId(id)}'),
  );
  @override
  Future<HealthOverview> saveHealth(
    List<HealthItem> medications,
    List<HealthItem> allergies,
  ) async => _health(
    await client.request(
      'PUT',
      '/api/v1/me/health-items',
      body: {
        for (final entry in {
          'medications': medications,
          'allergies': allergies,
        }.entries)
          entry.key: [
            for (final i in entry.value)
              {
                if (i.serverId != null) 'id': i.serverId,
                'name': i.name,
                'details': i.details,
              },
          ],
      },
    ),
  );
}
