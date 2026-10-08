import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';
import '../models/health_record.dart';

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository();
  UserProfile _profile = const UserProfile(
    fullName: 'Maria da Silva',
    email: 'maria@example.test',
    phone: '(11) 99999-9999',
    susCardNumber: '700 1234 5678 9012',
    birthDate: '12/04/1985',
    cpf: '123.456.789-00',
    postcode: '01000-000',
    street: 'Av. das Flores',
    number: '123',
    complement: 'Apto 12',
    neighborhood: 'Centro',
    city: 'São Paulo - SP',
    emergencyName: 'João da Silva',
    emergencyRelationship: 'Familiar',
    emergencyPhone: '(11) 98888-0000',
  );
  HealthOverview _health = HealthOverview(
    medications: const [
      HealthItem(id: 'med-1', name: 'Losartana', details: '50 mg • 1x ao dia'),
      HealthItem(
        id: 'med-2',
        name: 'Metformina',
        details: '850 mg • 2x ao dia',
      ),
      HealthItem(id: 'med-3', name: 'Omeprazol', details: '20 mg • pela manhã'),
      HealthItem(
        id: 'med-4',
        name: 'Vitamina D',
        details: '1 cápsula por semana',
      ),
    ],
    allergies: const [
      HealthItem(id: 'all-1', name: 'Dipirona', details: 'Reação: coceira'),
      HealthItem(
        id: 'all-2',
        name: 'Frutos do mar',
        details: 'Reação: inchaço',
      ),
      HealthItem(
        id: 'all-3',
        name: 'Látex',
        details: 'Reação: irritação na pele',
      ),
    ],
    history: [
      HealthRecord(
        id: 'hist-consulta-01',
        type: HealthRecordType.consultation,
        dateTime: DateTime(2026, 10, 6, 8),
        title: 'Clínica geral',
        subtitle: 'UBS Centro – Dra. Ana Beatriz Souza',
        professional: 'Dra. Ana Beatriz Souza',
        facility: 'UBS Centro',
        reason: 'Conversa sobre rotina e dúvidas anotadas para o atendimento.',
        summary:
            'Registro fictício de um atendimento anterior. A consulta futura de 9 de outubro permanece na Agenda.',
        notes: [
          'Anotar o que deseja conversar no próximo atendimento.',
          'Guardar os documentos recebidos.',
        ],
        documents: const [
          HealthDocument(
            'Anotações do atendimento',
            'Exemplo fictício: atendimento em 6 de outubro de 2026 na UBS Centro. Espaço para anotações pessoais.',
          ),
          HealthDocument(
            'Documentos do atendimento',
            'Exemplo fictício, sem receita, laudo ou encaminhamento válido. Nenhum arquivo de serviço de saúde foi importado.',
          ),
        ],
      ),
      HealthRecord(
        id: 'hist-exame-01',
        type: HealthRecordType.exam,
        dateTime: DateTime(2026, 10, 4, 10),
        title: 'Exame de sangue (hemograma)',
        subtitle: 'Laboratório Municipal',
        facility: 'Laboratório Municipal',
        reason: 'Registro de exame anterior.',
        summary:
            'Exame fictício registrado para organização pessoal. Nenhum resultado é interpretado pelo aplicativo.',
      ),
      HealthRecord(
        id: 'hist-med-01',
        type: HealthRecordType.medication,
        dateTime: DateTime(2026, 10, 3, 9),
        title: 'Losartana 50 mg',
        subtitle: 'Informação cadastrada',
        reason: 'Registro pessoal de medicamento.',
        summary:
            'Exemplo fictício informado no cadastro. O aplicativo não prescreve nem recomenda doses.',
      ),
      HealthRecord(
        id: 'hist-all-01',
        type: HealthRecordType.allergy,
        dateTime: DateTime(2026, 10, 2, 11),
        title: 'Alergia a Dipirona',
        subtitle: 'Reação informada: coceira',
        reason: 'Informação pessoal cadastrada.',
        summary:
            'Registro fictício para lembrar de conversar com o profissional. Não é uma avaliação produzida pelo aplicativo.',
      ),
      HealthRecord(
        id: 'hist-diagnostico-01',
        type: HealthRecordType.diagnosis,
        dateTime: DateTime(2026, 10, 1, 14),
        title: 'Hipertensão arterial',
        subtitle: 'Informação histórica já registrada',
        reason: 'Diagnóstico preexistente informado no cadastro fictício.',
        summary:
            'Informação histórica já registrada. O Chega Junto e a IA não produzem diagnósticos nem definem condutas.',
      ),
      HealthRecord(
        id: 'hist-exame-02',
        type: HealthRecordType.exam,
        dateTime: DateTime(2026, 10, 1, 8),
        title: 'Raio-X de tórax',
        subtitle: 'Laboratório Municipal',
        facility: 'Laboratório Municipal',
        reason: 'Registro de exame anterior.',
        summary:
            'Registro fictício sem laudo anexado ou interpretação de exame.',
      ),
    ],
  );
  @override
  Future<UserProfile> loadProfile() async => _profile;
  @override
  Future<UserProfile> saveProfile(UserProfile profile) async =>
      _profile = profile;
  @override
  Future<HealthOverview> loadHealth() async => _health;
  @override
  Future<HealthOverview> saveHealth(
    List<HealthItem> medications,
    List<HealthItem> allergies,
  ) async => _health = _health.withItems(medications, allergies);
}
