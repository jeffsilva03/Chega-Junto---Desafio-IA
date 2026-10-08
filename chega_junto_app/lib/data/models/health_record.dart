enum HealthRecordType {
  consultation('Consulta'),
  exam('Exame'),
  medication('Medicamento'),
  allergy('Alergia'),
  diagnosis('Diagnóstico registrado');

  const HealthRecordType(this.label);
  final String label;
}

class HealthItem {
  const HealthItem({
    required this.id,
    required this.name,
    required this.details,
  });
  final String id, name, details;
}

class HealthDocument {
  const HealthDocument(this.title, this.content);
  final String title, content;
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.type,
    required this.dateTime,
    required this.title,
    required this.subtitle,
    required this.reason,
    required this.summary,
    this.professional = '',
    this.facility = '',
    this.notes = const [],
    this.documents = const [],
  });
  final String id, title, subtitle, professional, facility, reason, summary;
  final HealthRecordType type;
  final DateTime dateTime;
  final List<String> notes;
  final List<HealthDocument> documents;
}

class HealthOverview {
  HealthOverview({
    required List<HealthItem> medications,
    required List<HealthItem> allergies,
    required List<HealthRecord> history,
  }) : medications = List.unmodifiable(medications),
       allergies = List.unmodifiable(allergies),
       history = List.unmodifiable(history);
  final List<HealthItem> medications, allergies;
  final List<HealthRecord> history;
  HealthOverview withItems(
    List<HealthItem> medications,
    List<HealthItem> allergies,
  ) => HealthOverview(
    medications: medications,
    allergies: allergies,
    history: history,
  );
}
