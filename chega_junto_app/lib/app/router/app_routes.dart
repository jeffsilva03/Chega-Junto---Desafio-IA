abstract final class AppRoutes {
  static const welcome = '/';
  static const login = '/login';
  static const home = '/inicio';
  static const agenda = '/agenda';
  static const checklist = '/atendimentos/consulta-demo-01/checklist';
  static const profile = '/perfil';
  static const details = '/atendimentos/consulta-demo-01';
  static const attendance = '/atendimentos/consulta-demo-01/presenca';
  static const report = '/atendimentos/consulta-demo-01/relato';
  static const summary = '/atendimentos/consulta-demo-01/resumo';
  static const notifications = '/notificacoes';
  static String appointmentDetails(String id) => '/atendimentos/$id';
}
