class ReportSection {
  const ReportSection({
    required this.id,
    required this.title,
    required this.text,
    String? sectionKey,
    this.serverId,
  }) : sectionKey = sectionKey ?? id;
  final String id, title, text;
  final String sectionKey;
  final String? serverId;
  ReportSection withText(String value) => ReportSection(
    id: id,
    title: title,
    text: value,
    sectionKey: sectionKey,
    serverId: serverId,
  );
}

class ConsultationQuestion {
  const ConsultationQuestion({
    required this.id,
    required this.text,
    this.selected = true,
    this.serverId,
  });
  final String id, text;
  final bool selected;
  final String? serverId;
  ConsultationQuestion copyWith({String? text, bool? selected}) =>
      ConsultationQuestion(
        id: id,
        text: text ?? this.text,
        selected: selected ?? this.selected,
        serverId: serverId,
      );
}

class OrganizedReport {
  OrganizedReport({
    required List<ReportSection> sections,
    required List<ConsultationQuestion> questions,
    this.sourceHash,
  }) : sections = List.unmodifiable(sections),
       questions = List.unmodifiable(questions);
  final List<ReportSection> sections;
  final List<ConsultationQuestion> questions;
  final String? sourceHash;
}
