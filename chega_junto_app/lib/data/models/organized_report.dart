class ReportSection {
  const ReportSection({
    required this.id,
    required this.title,
    required this.text,
  });
  final String id, title, text;
  ReportSection withText(String value) =>
      ReportSection(id: id, title: title, text: value);
}

class ConsultationQuestion {
  const ConsultationQuestion({
    required this.id,
    required this.text,
    this.selected = true,
  });
  final String id, text;
  final bool selected;
  ConsultationQuestion copyWith({String? text, bool? selected}) =>
      ConsultationQuestion(
        id: id,
        text: text ?? this.text,
        selected: selected ?? this.selected,
      );
}

class OrganizedReport {
  OrganizedReport({
    required List<ReportSection> sections,
    required List<ConsultationQuestion> questions,
  }) : sections = List.unmodifiable(sections),
       questions = List.unmodifiable(questions);
  final List<ReportSection> sections;
  final List<ConsultationQuestion> questions;
}
