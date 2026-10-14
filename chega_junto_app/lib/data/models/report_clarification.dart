enum ClarificationAnswerKind {
  text,
  option,
  dontKnow,
  dontRemember,
  preferNotToAnswer,
}

extension ClarificationAnswerWire on ClarificationAnswerKind {
  String get wire => switch (this) {
    ClarificationAnswerKind.text => 'text',
    ClarificationAnswerKind.option => 'option',
    ClarificationAnswerKind.dontKnow => 'dont_know',
    ClarificationAnswerKind.dontRemember => 'dont_remember',
    ClarificationAnswerKind.preferNotToAnswer => 'prefer_not_to_answer',
  };
  String get label => switch (this) {
    ClarificationAnswerKind.dontKnow => 'Não sei informar',
    ClarificationAnswerKind.dontRemember => 'Não lembro',
    ClarificationAnswerKind.preferNotToAnswer => 'Prefiro não responder',
    _ => '',
  };
}

class ReportClarification {
  const ReportClarification({
    required this.id,
    required this.questionText,
    required this.position,
    this.options = const [],
    this.answerKind,
    this.answerText,
    this.answeredAt,
  });
  final String id, questionText;
  final int position;
  final List<String> options;
  final ClarificationAnswerKind? answerKind;
  final String? answerText;
  final DateTime? answeredAt;
  bool get answered => answerKind != null;
  String get answerLabel => answerText ?? answerKind?.label ?? '';
  ReportClarification withAnswer(ClarificationAnswerKind kind, String? value) =>
      ReportClarification(
        id: id,
        questionText: questionText,
        position: position,
        options: options,
        answerKind: kind,
        answerText: value,
        answeredAt: DateTime.now(),
      );
}
