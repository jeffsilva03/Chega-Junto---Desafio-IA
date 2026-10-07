import 'package:chega_junto_app/core/state/preparation_controller.dart';
import 'package:chega_junto_app/data/mock/mock_preparation_repository.dart';
import 'package:chega_junto_app/data/models/appointment.dart';
import 'package:chega_junto_app/data/models/appointment_reminder.dart';
import 'package:chega_junto_app/data/models/checklist_item.dart';
import 'package:chega_junto_app/data/models/preparation_overview.dart';
import 'package:flutter_test/flutter_test.dart';

class _AttendanceFailureRepository extends MockPreparationRepository {
  bool fail = true;
  @override
  Future<PreparationOverview> setAttendance(
    String appointmentId,
    ConfirmationStatus status,
  ) {
    if (fail) throw StateError('Falha simulada');
    return super.setAttendance(appointmentId, status);
  }
}

class _UnavailableRepository extends MockPreparationRepository {
  bool unavailable = true;
  @override
  Future<List<Appointment>> loadAppointments() async {
    if (unavailable) throw StateError('Falha simulada');
    return super.loadAppointments();
  }
}

void main() {
  test(
    'Resposta de presença mantém consulta e progresso consistentes',
    () async {
      final controller = PreparationController(MockPreparationRepository());
      await controller.load();
      for (final status in [
        ConfirmationStatus.unable,
        ConfirmationStatus.undecided,
        ConfirmationStatus.confirmed,
      ]) {
        await controller.setAttendance(status);
        await controller.load();
        final overview = controller.overview!;
        expect(overview.nextAppointment.confirmationStatus, status);
        expect(
          controller.appointmentById(overview.nextAppointment.id),
          same(overview.nextAppointment),
        );
        expect(
          overview.progress.percentage,
          status == ConfirmationStatus.confirmed ? 75 : 50,
        );
        expect(requiredChecklistProgress(overview.checklist), 1);
      }
      controller.dispose();
    },
  );

  test(
    'Erro ao salvar presença preserva dados e permite nova tentativa',
    () async {
      final repository = _AttendanceFailureRepository();
      final controller = PreparationController(repository);
      await controller.load();
      await expectLater(
        controller.setAttendance(ConfirmationStatus.unable),
        throwsStateError,
      );
      expect(controller.saving, false);
      expect(
        controller.overview!.nextAppointment.confirmationStatus,
        ConfirmationStatus.confirmed,
      );
      repository.fail = false;
      await controller.setAttendance(ConfirmationStatus.unable);
      expect(
        controller.overview!.nextAppointment.confirmationStatus,
        ConfirmationStatus.unable,
      );
      controller.dispose();
    },
  );
  test(
    'Alterações obrigatórias e opcionais são mantidas ao recarregar',
    () async {
      final controller = PreparationController(MockPreparationRepository());
      await controller.load();
      expect(controller.overview!.progress.percentage, 75);
      expect(
        controller.appointmentById(controller.overview!.nextAppointment.id),
        same(controller.overview!.nextAppointment),
      );
      await controller.setChecklistItem('documento', false);
      expect(controller.overview!.progress.percentage, 50);
      expect(requiredChecklistProgress(controller.overview!.checklist), .5);
      await controller.setChecklistItem('exames', false);
      expect(controller.overview!.progress.percentage, 50);
      expect(requiredChecklistProgress(controller.overview!.checklist), .5);
      await controller.load();
      expect(controller.overview!.checklist.first.isCompleted, false);
      await controller.setChecklistItem('documento', true);
      expect(controller.overview!.progress.percentage, 75);
      expect(requiredChecklistProgress(controller.overview!.checklist), 1);
      controller.dispose();
    },
  );

  test('Lembrete local aparece no estado compartilhado', () async {
    final controller = PreparationController(MockPreparationRepository());
    await controller.load();
    final before = controller.reminders.length;
    await controller.addReminder(
      AppointmentReminder(
        id: 'teste',
        title: 'Separar anotações',
        dateTime: DateTime(2026, 10, 9, 7),
      ),
    );
    expect(controller.reminders.length, before + 1);
    await controller.load();
    expect(controller.reminders.last.title, 'Separar anotações');
    controller.dispose();
  });

  test('Erro de carregamento permite nova tentativa', () async {
    final repository = _UnavailableRepository();
    final controller = PreparationController(repository);
    await controller.load();
    expect(controller.failed, true);
    expect(controller.loading, false);
    repository.unavailable = false;
    await controller.load();
    expect(controller.failed, false);
    expect(controller.overview, isNotNull);
    controller.dispose();
  });
}
