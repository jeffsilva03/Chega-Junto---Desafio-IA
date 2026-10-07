import 'package:chega_junto_app/data/models/appointment_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Horários relativos usam data completa mesmo ao mudar o mês', () {
    final appointment = DateTime(2026, 11, 1, 1);
    expect(
      ReminderTiming.dayBefore.dateFor(appointment),
      DateTime(2026, 10, 31, 1),
    );
    expect(
      ReminderTiming.twoHoursBefore.dateFor(appointment),
      DateTime(2026, 10, 31, 23),
    );
    expect(ReminderTiming.atAppointment.dateFor(appointment), appointment);
  });
}
