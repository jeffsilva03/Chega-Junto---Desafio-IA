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
  PreparationProgress(Set<PreparationStage> completed)
    : completed = Set.unmodifiable(completed);
  final Set<PreparationStage> completed;
  int get completedCount => completed.length;
  int get totalCount => PreparationStage.values.length;
  double get fraction => completedCount / totalCount;
  int get percentage => (fraction * 100).round();
}

double requiredChecklistProgress(List<ChecklistItem> items) {
  final required = items.where((item) => item.isRequired).toList();
  if (required.isEmpty) return 1;
  return required.where((item) => item.isCompleted).length / required.length;
}
