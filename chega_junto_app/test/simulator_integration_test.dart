import 'package:flutter_test/flutter_test.dart';
import 'package:chega_junto_app/core/state/preparation_controller.dart';
import 'package:chega_junto_app/data/api/api_mapping.dart';
import 'package:chega_junto_app/data/api/api_preparation_repository.dart';
import 'package:chega_junto_app/data/models/appointment.dart';
import 'support/fake_api.dart';

void main() {
  test('Status and return type parse without losing IDs or attendance', () {
    final item = appointmentFromJson({
      ...appointmentFixture(),
      'status': 'cancelled',
      'type': 'return',
    });
    expect(item.id, largeId);
    expect(item.status, AppointmentStatus.cancelled);
    expect(item.type, AppointmentType.followUp);
    expect(
      item.withConfirmation(ConfirmationStatus.unable).status,
      AppointmentStatus.cancelled,
    );
    expect(
      item.withConfirmation(ConfirmationStatus.unable).type,
      AppointmentType.followUp,
    );
  });

  test(
    'Reload replaces empty overview with first canonical appointment and checklist',
    () async {
      final api = FakeApi()..emptyOverview = true;
      api.intercept = (request) async =>
          request.url.path == '/api/v1/appointments' && api.emptyOverview
          ? response(page([]))
          : null;
      final state = PreparationController(ApiPreparationRepository(api.client));
      addTearDown(state.dispose);
      addTearDown(api.close);
      await state.load();
      expect(state.overview!.hasNextAppointment, false);
      expect(state.appointments, isEmpty);
      api.emptyOverview = false;
      api.appointment['status'] = 'scheduled';
      await state.load();
      expect(state.overview!.nextAppointment.id, largeId);
      expect(state.overview!.checklist.single.isRequired, true);
      expect(state.appointments.single.id, largeId);
      expect(api.mutations, isEmpty);
    },
  );

  test(
    'Reload invalidates stale details and cancelled appointment leaves Home',
    () async {
      final api = FakeApi();
      final state = PreparationController(ApiPreparationRepository(api.client));
      addTearDown(state.dispose);
      addTearDown(api.close);
      await state.load();
      expect(
        (await state.loadAppointment(largeId)).status,
        AppointmentStatus.scheduled,
      );
      api.appointment = {
        ...api.appointment,
        'status': 'cancelled',
        'professional_name': 'Dra. Ana Teste',
      };
      api.emptyOverview = true;
      await state.load();
      expect(state.overview!.hasNextAppointment, false);
      expect(state.appointments.single.status, AppointmentStatus.cancelled);
      final detail = await state.loadAppointment(largeId);
      expect(detail.status, AppointmentStatus.cancelled);
      expect(detail.professionalName, 'Dra. Ana Teste');
    },
  );
}
