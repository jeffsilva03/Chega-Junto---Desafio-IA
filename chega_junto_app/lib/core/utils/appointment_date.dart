abstract final class AppointmentDate {
  static const _months = [
    'jan.',
    'fev.',
    'mar.',
    'abr.',
    'mai.',
    'jun.',
    'jul.',
    'ago.',
    'set.',
    'out.',
    'nov.',
    'dez.',
  ];
  static const _weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  static String shortDate(DateTime date) =>
      '${date.day} de ${_months[date.month - 1]}';
  static String weekday(DateTime date) => _weekdays[date.weekday - 1];
  static const _fullMonths = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  static String fullDate(DateTime date) =>
      '${date.day} de ${_fullMonths[date.month - 1]} de ${date.year}';
  static String groupDate(DateTime date) =>
      '${_weekdays[date.weekday - 1].split('-').first}, ${date.day} de ${_fullMonths[date.month - 1]}';
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
