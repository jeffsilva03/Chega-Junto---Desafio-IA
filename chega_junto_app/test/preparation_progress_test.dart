import 'package:chega_junto_app/data/models/checklist_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Progresso geral usa exatamente quatro macroetapas', () {
    final progress = PreparationProgress({
      PreparationStage.documents,
      PreparationStage.attendance,
      PreparationStage.report,
    });
    expect(progress.totalCount, 4);
    expect(progress.percentage, 75);
    expect(progress.completed.contains(PreparationStage.finalReview), false);
  });
  test('Itens opcionais não alteram o progresso obrigatório', () {
    expect(
      requiredChecklistProgress(const [
        ChecklistItem(
          id: 'foto',
          title: 'Documento',
          isRequired: true,
          isCompleted: true,
        ),
        ChecklistItem(id: 'sus', title: 'Cartão SUS', isRequired: true),
        ChecklistItem(
          id: 'exame',
          title: 'Exames anteriores',
          isRequired: false,
          isCompleted: true,
        ),
      ]),
      .5,
    );
  });
}
