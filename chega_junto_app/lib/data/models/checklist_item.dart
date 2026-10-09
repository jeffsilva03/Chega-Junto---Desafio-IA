enum ChecklistSection { documents, reminders, conversation }

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    required this.isRequired,
    this.isCompleted = false,
    this.section = ChecklistSection.documents,
  });
  final String id;
  final String title;
  final bool isRequired;
  final bool isCompleted;
  final ChecklistSection section;

  ChecklistItem withCompleted(bool completed) => ChecklistItem(
    id: id,
    title: title,
    isRequired: isRequired,
    isCompleted: completed,
    section: section,
  );
}

enum PreparationStage { documents, attendance, report, finalReview }

class PreparationProgress {
  PreparationProgress(
    Set<PreparationStage> completed, {
    int? completedCount,
    int? totalCount,
    double? fraction,
    int? percentage,
  }) : completed = Set.unmodifiable(completed),
       _count = completedCount,
       _total = totalCount,
       _fraction = fraction,
       _percentage = percentage;
  final Set<PreparationStage> completed;
  final int? _count, _total, _percentage;
  final double? _fraction;
  int get completedCount => _count ?? completed.length;
  int get totalCount => _total ?? PreparationStage.values.length;
  double get fraction => _fraction ?? completedCount / totalCount;
  int get percentage => _percentage ?? (fraction * 100).round();
}

double requiredChecklistProgress(List<ChecklistItem> items) {
  final required = items.where((item) => item.isRequired).toList();
  if (required.isEmpty) return 1;
  return required.where((item) => item.isCompleted).length / required.length;
}
