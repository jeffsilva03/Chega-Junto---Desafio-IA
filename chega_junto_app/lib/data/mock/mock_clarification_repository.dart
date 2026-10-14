import 'dart:convert';
import '../../core/network/api_exception.dart';
import '../models/pre_visit_report.dart';
import '../models/report_clarification.dart';
import '../repositories/clarification_repository.dart';
import '../repositories/preparation_repository.dart';

class MockClarificationRepository implements ClarificationRepository {
  MockClarificationRepository(
    this.preparation, {
    this.delay = const Duration(milliseconds: 300),
  });
  final PreparationRepository preparation;
  final Duration delay;
  String _fingerprint(PreVisitReport report, List<ReportClarification> rows) =>
      'mock:${jsonEncode([
        report.originalText,
        for (final row in rows)
          if (row.answered) [row.questionText, row.answerKind?.wire, row.answerText],
      ])}';
  Future<PreVisitReport> _save(
    PreVisitReport original,
    List<ReportClarification> rows,
    bool done,
  ) async {
    final value = original.copyWith(
      clarifications: List.unmodifiable(rows),
      clarificationsCurrent: true,
      clarificationsCompleted: done,
      clarificationsSourceText: original.originalText,
      contentRevision: '${(int.tryParse(original.contentRevision) ?? 0) + 1}',
      currentSourceHash: _fingerprint(original, rows),
      organizationCurrent: false,
      reviewed: false,
      finalDone: false,
    );
    await preparation.saveReport(value);
    return value;
  }

  @override
  Future<PreVisitReport> next(String appointmentId) async {
    final report = (await preparation.loadReport(appointmentId))!;
    if (report.originalText.trim().isEmpty) {
      throw const ApiException('Escreva seu relato antes de continuar.');
    }
    final rows = report.clarificationsCurrent
        ? report.clarifications
        : <ReportClarification>[];
    if (rows.any((row) => !row.answered) ||
        (report.clarificationsCurrent && report.clarificationsCompleted)) {
      return report;
    }
    if (rows.length >= 2) return _save(report, rows, true);
    await Future<void>.delayed(delay);
    final latest = (await preparation.loadReport(appointmentId))!;
    if (latest.originalText != report.originalText ||
        latest.contentRevision != report.contentRevision) {
      throw const ConflictException();
    }
    return _save(report, [
      ...rows,
      ReportClarification(
        id: 'mock-clarification-${rows.length}',
        position: rows.length,
        questionText: rows.isEmpty
            ? 'Quando você percebeu isso pela primeira vez?'
            : 'Com que frequência você percebe?',
        options: rows.isEmpty
            ? const [
                'Nos últimos dias',
                'Há algumas semanas',
                'Há alguns meses',
              ]
            : const [],
      ),
    ], false);
  }

  @override
  Future<PreVisitReport> answer(
    String appointmentId,
    String clarificationId,
    ClarificationAnswerKind kind,
    String? text,
    String expectedRevision,
  ) async {
    final report = (await preparation.loadReport(appointmentId))!;
    if (report.contentRevision != expectedRevision ||
        !report.clarificationsCurrent) {
      throw const ConflictException();
    }
    final row = report.clarifications.firstWhere(
      (row) => row.id == clarificationId,
    );
    if (kind == ClarificationAnswerKind.option && !row.options.contains(text)) {
      throw const ApiException('Escolha uma opção válida.');
    }
    if (kind == ClarificationAnswerKind.text &&
        (text == null || text.trim().isEmpty || text.length > 2000)) {
      throw const ApiException('Informe uma resposta válida.');
    }
    return _save(report, [
      for (final row in report.clarifications)
        row.id == clarificationId ? row.withAnswer(kind, text?.trim()) : row,
    ], report.clarificationsCompleted);
  }

  @override
  Future<PreVisitReport> skip(String appointmentId) async {
    final report = (await preparation.loadReport(appointmentId))!;
    final rows = report.clarificationsCurrent
        ? report.clarifications
        : <ReportClarification>[];
    return _save(report, [
      for (final row in rows)
        row.answered
            ? row
            : row.withAnswer(ClarificationAnswerKind.preferNotToAnswer, null),
    ], true);
  }
}
