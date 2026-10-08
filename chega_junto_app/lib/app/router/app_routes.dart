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
  static const personalData = '/perfil/dados-pessoais';
  static const medications = '/perfil/medicamentos-alergias';
  static const healthHistory = '/perfil/historico';
  static const notificationSettings = '/notificacoes/configuracoes';
  static const accessibility = '/perfil/acessibilidade';
  static const help = '/perfil/ajuda';
  static String historyDetails(String id) => '/perfil/historico/$id';
  static String appointmentDetails(String id) => '/atendimentos/$id';
}
