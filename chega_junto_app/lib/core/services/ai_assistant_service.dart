import '../../data/models/organized_report.dart';

abstract interface class AiAssistantService {
  Future<OrganizedReport> organize(String originalText);
}
