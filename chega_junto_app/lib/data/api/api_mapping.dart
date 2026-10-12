import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/appointment.dart';
import '../models/appointment_reminder.dart';
import '../models/checklist_item.dart';
import '../models/organized_report.dart';
import '../models/pre_visit_report.dart';

String decimalId(Object? value) {
  if (value is! String || !RegExp(r'^[0-9]+$').hasMatch(value)) {
    throw const ApiException(
      'Não foi possível ler a resposta do serviço.',
      code: 'invalid_identifier',
    );
  }
  return value;
}

DateTime instant(Object? value) {
  final parsed = DateTime.parse(value as String);
  if (!parsed.isUtc) throw const FormatException('Expected UTC instant');
  return parsed.toLocal();
}

DateTime civilDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

List<Json> objects(Object? value) => (value as List).cast<Json>();

Appointment appointmentFromJson(Json j) => Appointment(
  id: decimalId(j['id']),
  title: j['title'],
  specialty: j['specialty'],
  professionalName: j['professional_name'],
  dateTime: instant(j['scheduled_at']),
  facilityName: j['facility']['name'],
  address: j['facility']['address_text'],
  instructions: List<String>.from(j['instructions'] ?? []),
  confirmationStatus: ConfirmationStatus.values.byName(j['attendance_status']),
  type: j['type'] == 'return'
      ? AppointmentType.followUp
      : AppointmentType.values.byName(j['type']),
  status: AppointmentStatus.values.byName(j['status'] ?? 'scheduled'),
);
AppointmentReminder reminderFromJson(Json j) => AppointmentReminder(
  id: decimalId(j['id']),
  title: j['title'],
  dateTime: instant(j['remind_at']),
  appointmentId: j['appointment_id'] == null
      ? null
      : decimalId(j['appointment_id']),
);
ChecklistItem checklistFromJson(Json j) => ChecklistItem(
  id: decimalId(j['id']),
  title: j['title'],
  isRequired: j['is_required'],
  isCompleted: j['is_completed'],
  section: ChecklistSection.values.byName(j['section']),
);
PreparationProgress progressFromJson(Json j) => PreparationProgress(
  {
    if (j['documents_done']) PreparationStage.documents,
    if (j['attendance_done']) PreparationStage.attendance,
    if (j['report_done']) PreparationStage.report,
    if (j['final_done']) PreparationStage.finalReview,
  },
  completedCount: j['completed_count'],
  totalCount: j['total_count'],
  fraction: (j['fraction'] as num).toDouble(),
  percentage: j['percentage'],
);

PreVisitReport reportFromJson(Json j) {
  final sections = objects(j['sections'])
      .map(
        (s) => ReportSection(
          id: s['section_key'],
          sectionKey: s['section_key'],
          serverId: decimalId(s['id']),
          title: s['title'],
          text: s['text'],
        ),
      )
      .toList();
  final questions = objects(j['questions'])
      .map(
        (q) => ConsultationQuestion(
          id: decimalId(q['id']),
          serverId: decimalId(q['id']),
          text: q['text'],
          selected: q['is_selected'],
        ),
      )
      .toList();
  return PreVisitReport(
    appointmentId: decimalId(j['appointment_id']),
    originalText: j['original_text'],
    updatedAt: instant(j['updated_at']),
    contentRevision: decimalId(j['content_revision']),
    sections: List.unmodifiable(sections),
    questions: List.unmodifiable(questions),
    organizedSummary: sections
        .where((s) => s.text.trim().isNotEmpty)
        .map((s) => '${s.title}\n${s.text}')
        .join('\n\n'),
    suggestedQuestions: questions
        .where((q) => q.selected)
        .map((q) => q.text)
        .toList(),
    organizationCurrent: j['organization_current'],
    reviewed: j['reviewed'],
    finalDone: j['final_done'],
    reviewedRevision: j['reviewed_revision'] == null
        ? null
        : decimalId(j['reviewed_revision']),
    reviewedAt: j['reviewed_at'] == null ? null : instant(j['reviewed_at']),
    finalReviewRevision: j['final_review_revision'] == null
        ? null
        : decimalId(j['final_review_revision']),
    finalReviewAt: j['final_review_at'] == null
        ? null
        : instant(j['final_review_at']),
  );
}

Json reportToJson(
  PreVisitReport report, {
  String intent = 'edit',
  String? organizationSourceText,
}) => {
  'expected_revision': report.contentRevision,
  'original_text': report.originalText,
  'intent': intent,
  if (intent == 'organize') 'organization_source_text': organizationSourceText,
  'sections': [
    for (final s in report.sections)
      {
        if (s.serverId != null) 'id': s.serverId,
        'section_key': s.sectionKey,
        'title': s.title,
        'text': s.text,
      },
  ],
  'questions': [
    for (final q in report.questions)
      {
        if (q.serverId != null) 'id': q.serverId,
        'text': q.text,
        'is_selected': q.selected,
      },
  ],
};
