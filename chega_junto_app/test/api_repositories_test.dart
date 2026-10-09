import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chega_junto_app/app/app_dependencies.dart';
import 'package:chega_junto_app/core/config/data_config.dart';
import 'package:chega_junto_app/core/network/api_client.dart';
import 'package:chega_junto_app/core/network/api_exception.dart';
import 'package:chega_junto_app/data/api/api_mapping.dart';
import 'package:chega_junto_app/data/api/api_profile_repository.dart';
import 'package:chega_junto_app/data/api/api_preparation_repository.dart';
import 'package:chega_junto_app/data/api/api_notification_repository.dart';
import 'package:chega_junto_app/data/api/api_preferences_repository.dart';
import 'package:chega_junto_app/data/mock/mock_preparation_repository.dart';
import 'package:chega_junto_app/data/models/appointment.dart';
import 'package:chega_junto_app/data/models/appointment_reminder.dart';
import 'package:chega_junto_app/data/models/health_record.dart';
import 'package:chega_junto_app/data/models/pre_visit_report.dart';
import 'package:chega_junto_app/data/models/profile_preferences.dart';
import 'support/fake_api.dart';

void main() {
  late FakeApi api;
  setUp(() => api = FakeApi());
  tearDown(() => api.close());
  test('Composition selects one source and mock needs no API URL', () {
    final mock = AppDependencies(const DataConfig());
    expect(mock.preparation, isA<MockPreparationRepository>());
    mock.dispose();
    final real = AppDependencies(
      const DataConfig(mode: DataSourceMode.api),
      client: api.client,
    );
    expect(real.preparation, isA<ApiPreparationRepository>());
    expect(real.profile, isA<ApiProfileRepository>());
    expect(real.preferences, isA<ApiPreferencesRepository>());
    expect(real.notifications, isA<ApiNotificationRepository>());
    real.dispose();
  });
  test('Base URL forbids credentials and needs explicit HTTP origin', () {
    for (final url in [
      '',
      'mysql://example.test',
      'http://name:secret@example.test',
      'http://example.test/api/v1',
      'http://example.test?secret=x',
    ]) {
      expect(
        () => ApiClient(url, transport: MockClient((_) async => response({}))),
        throwsArgumentError,
      );
    }
  });
  test(
    'Profile maps civil birth date, city/UF and canonical response',
    () async {
      final repo = ApiProfileRepository(api.client);
      final loaded = await repo.loadProfile();
      expect(loaded.birthDate, '12/04/1985');
      expect(loaded.city, 'São Paulo - SP');
      final saved = await repo.saveProfile(
        loaded.copyWith(fullName: '  Edição fictícia  ', complement: ''),
      );
      expect(saved.fullName, 'Edição fictícia');
      final sent = jsonDecode(api.mutations.single.body) as Json;
      expect(sent['birth_date'], '1985-04-12');
      expect(sent['city'], 'São Paulo');
      expect(sent['state_code'], 'SP');
      expect(sent['complement'], isNull);
      for (final key in [
        'id',
        'user_id',
        'sus_card_number',
        'created_at',
        'updated_at',
      ]) {
        expect(sent.containsKey(key), false);
      }
      expect(sent.length, 15);
      expect(
        api.mutations.single.headers['content-type'],
        contains('application/json'),
      );
      expect(api.mutations.single.headers['accept'], 'application/json');
    },
  );
  test(
    'Health saves both complete lists, preserves existing IDs and receives new IDs',
    () async {
      final repo = ApiProfileRepository(api.client);
      final loaded = await repo.loadHealth();
      expect(loaded.medications.single.id, largeId);
      final saved = await repo.saveHealth([
        ...loaded.medications,
        const HealthItem(
          id: '12345678901234567890',
          name: 'Novo fictício',
          details: 'Uso informado',
        ),
      ], []);
      final sent = jsonDecode(api.mutations.single.body) as Json;
      expect(sent.keys, unorderedEquals(['medications', 'allergies']));
      expect(sent['medications'][0]['id'], largeId);
      expect(sent['medications'][1].containsKey('id'), false);
      expect(sent['allergies'], isEmpty);
      expect(saved.medications.last.id, '999');
      expect(saved.medications.last.serverId, '999');
      expect(saved.history.single.id, largeId);
    },
  );
  test(
    'History list paginates without fetching documents; detail loads on demand',
    () async {
      final repo = ApiProfileRepository(api.client);
      final loaded = await repo.loadHealth();
      expect(loaded.history.single.documents, isEmpty);
      expect(
        api.requests.where((r) => r.url.path.contains('/health-records/')),
        isEmpty,
      );
      final record = await repo.loadHealthRecord(largeId);
      expect(record.documents.single.content, 'Conteúdo fictício');
      expect(record.dateTime.toUtc(), DateTime.utc(2026, 10, 6, 11));
    },
  );
  test('Pagination follows offsets and refuses a stalled response', () async {
    api.intercept = (r) async {
      if (r.url.path != '/api/v1/appointments') return null;
      final offset = r.url.queryParameters['offset'];
      return response(
        page([appointmentFixture()], total: 2, offset: offset == '0' ? 0 : 1),
      );
    };
    final repo = ApiPreparationRepository(api.client);
    expect(await repo.loadAppointments(), hasLength(2));
    expect(api.requests.map((r) => r.url.queryParameters['offset']), [
      '0',
      '1',
    ]);
    api.intercept = (_) async => response(page([], total: 1));
    await expectLater(repo.loadAppointments(), throwsA(isA<ApiException>()));
  });
  test(
    'Overview accepts no next appointment without inventing demo records',
    () async {
      api.emptyOverview = true;
      final overview = await ApiPreparationRepository(
        api.client,
      ).loadOverview();
      expect(overview.hasNextAppointment, false);
      expect(api.requests, hasLength(1));
      expect(api.mutations, isEmpty);
    },
  );
  test(
    'Overview/progress, checklist mutation and attendance use canonical backend data',
    () async {
      final repo = ApiPreparationRepository(api.client);
      final overview = await repo.loadOverview();
      expect(overview.nextAppointment.id, largeId);
      expect(overview.progress.percentage, 100);
      expect(
        overview.nextAppointment.dateTime.toUtc(),
        DateTime.utc(2026, 10, 9, 11),
      );
      expect(overview.referenceDate, DateTime(2026, 10, 9));
      final updated = await repo.setChecklistItem(largeId, '3', false);
      expect(updated.checklist.single.isCompleted, false);
      expect(updated.progress.percentage, 50);
      expect(jsonDecode(api.mutations.single.body), {'is_completed': false});
      expect(updated.checklistFraction, 0);
      await repo.setAttendance(largeId, ConfirmationStatus.unable);
      expect(jsonDecode(api.mutations.last.body), {
        'attendance_status': 'unable',
      });
      expect(await repo.loadAttendance(largeId), ConfirmationStatus.unable);
      expect(
        (await repo.loadPreparation(largeId))['appointment']['id'],
        largeId,
      );
      expect((await repo.loadAppointment(largeId)).instructions, [
        'Orientação fictícia.',
      ]);
    },
  );
  test(
    'Reminder POST uses UTC, omits local ID and retains returned canonical ID',
    () async {
      final repo = ApiPreparationRepository(api.client);
      await repo.addReminder(
        AppointmentReminder(
          id: 'local-temp',
          title: 'Fictício',
          dateTime: DateTime.utc(2026, 10, 8, 11),
          appointmentId: largeId,
        ),
      );
      final sent = jsonDecode(api.mutations.single.body) as Json;
      expect(
        sent.keys,
        unorderedEquals(['title', 'remind_at', 'appointment_id']),
      );
      expect(sent['remind_at'], '2026-10-08T11:00:00.000Z');
      expect(sent['appointment_id'], largeId);
      expect(repo.lastCreatedReminder!.id, '99');
      expect((await repo.loadReminders()).single.id, '99');
    },
  );
  test(
    'An uncertain POST is attempted once and never retried automatically',
    () async {
      api.intercept = (r) async =>
          throw http.ClientException('private transport details');
      await expectLater(
        ApiPreparationRepository(api.client).addReminder(
          AppointmentReminder(
            id: 'local',
            title: 'Fictício',
            dateTime: DateTime.utc(2026, 10, 8),
          ),
        ),
        throwsA(
          isA<NetworkException>().having((e) => e.uncertain, 'uncertain', true),
        ),
      );
      expect(api.requests, hasLength(1));
    },
  );
  test(
    'Report restores IDs, empty sections, unselected questions, order and markers',
    () async {
      final report = (await ApiPreparationRepository(
        api.client,
      ).loadReport(largeId))!;
      expect(report.contentRevision, '1');
      expect(report.sections.last.text, isEmpty);
      expect(report.sections.first.serverId, largeId);
      expect(report.questions.map((q) => q.id), ['11', '10']);
      expect(report.questions.first.selected, false);
      expect(report.reviewed, true);
      expect(report.finalDone, true);
      expect(report.reviewedRevision, '1');
      expect(report.finalReviewRevision, '1');
      expect(report.reviewedAt!.toUtc(), DateTime.utc(2026, 10, 9, 11));
    },
  );
  test(
    'Report absent 404 creates with revision zero; network error remains an error',
    () async {
      final repo = ApiPreparationRepository(api.client);
      api.reportAbsent = true;
      expect(await repo.loadReport(largeId), isNull);
      await repo.writeReport(
        PreVisitReport(
          appointmentId: largeId,
          originalText: 'Novo fictício',
          updatedAt: DateTime.now(),
        ),
      );
      expect(jsonDecode(api.mutations.single.body)['expected_revision'], '0');
      api.intercept = (_) async => throw http.ClientException('network');
      await expectLater(
        repo.loadReport(largeId),
        throwsA(isA<NetworkException>()),
      );
    },
  );
  test(
    'Report edit/organize/review/final/DELETE send current string revision only',
    () async {
      final repo = ApiPreparationRepository(api.client);
      var report = (await repo.loadReport(largeId))!;
      report = await repo.writeReport(report);
      var sent = jsonDecode(api.mutations.last.body) as Json;
      expect(sent['expected_revision'], '1');
      expect(sent['intent'], 'edit');
      expect(sent.containsKey('organization_source_text'), false);
      expect(sent['sections'][0]['id'], largeId);
      expect(sent['questions'][0], {
        'id': '11',
        'text': 'Pergunta não selecionada?',
        'is_selected': false,
      });
      expect(
        sent.keys,
        unorderedEquals([
          'expected_revision',
          'original_text',
          'sections',
          'questions',
          'intent',
        ]),
      );
      report = await repo.writeReport(
        report,
        intent: 'organize',
        organizationSourceText: report.originalText,
      );
      sent = jsonDecode(api.mutations.last.body);
      expect(sent['organization_source_text'], report.originalText);
      report = await repo.reviewReport(largeId, report.contentRevision);
      expect(jsonDecode(api.mutations.last.body), {
        'expected_revision': report.contentRevision,
      });
      await repo.setFinalReview(largeId, false);
      expect(api.mutations.last.url.path, endsWith('/final-review'));
      expect(jsonDecode(api.mutations.last.body), {
        'expected_revision': report.contentRevision,
        'completed': false,
      });
      report = await repo.clearReportSummary(largeId, report.contentRevision);
      expect(api.mutations.last.method, 'DELETE');
      expect(
        api.mutations.last.url.queryParameters['expected_revision'],
        report.contentRevision,
      );
      expect(api.mutations.last.body, isEmpty);
      expect(report.originalText, 'Texto fictício original.');
      expect(report.questions, isEmpty);
      expect(report.sections.every((s) => s.text.isEmpty), true);
    },
  );
  test(
    'Notifications use server global unread_count and PATCH canonical read state',
    () async {
      final repo = ApiNotificationRepository(api.client);
      api.intercept = (r) async => r.url.path == '/api/v1/me/notifications'
          ? response(page([notificationFixture()], unread: 42))
          : null;
      final inbox = await repo.load();
      expect(inbox.unreadCount, 42);
      expect(inbox.items.single.id, largeId);
      expect((await repo.markRead(largeId)).unread, false);
      expect(jsonDecode(api.mutations.single.body), {'is_read': true});
    },
  );
  test(
    'Preferences round trip all settings including extra_large and in_app',
    () async {
      final repo = ApiPreferencesRepository(api.client);
      final original = await repo.loadAccessibility();
      final saved = await repo.saveAccessibility(
        original.copyWith(
          textSize: AppTextSize.extraLarge,
          appearance: AppAppearance.system,
          highContrast: true,
          speech: true,
          descriptions: false,
          simpleLanguage: false,
          haptics: false,
          reduceMotion: true,
        ),
      );
      expect(saved.textSize, AppTextSize.extraLarge);
      expect(saved.appearance, AppAppearance.system);
      final body = jsonDecode(api.mutations.last.body);
      expect(body, {
        'text_size': 'extra_large',
        'appearance': 'system',
        'high_contrast': true,
        'speech': true,
        'descriptions': false,
        'simple_language': false,
        'haptics': false,
        'reduce_motion': true,
      });
      final notificationPrefs = await repo.loadNotifications();
      expect(
        (await repo.saveNotifications(
          notificationPrefs.change(NotificationOption.inApp, false),
        )).enabled(NotificationOption.inApp),
        false,
      );
      expect(jsonDecode(api.mutations.last.body).containsKey('inApp'), false);
    },
  );
  for (final status in [400, 404, 409, 422, 500, 503]) {
    test(
      'HTTP $status yields typed safe error, not raw backend JSON',
      () async {
        api.intercept = (_) async => failure(status, 'revision_conflict');
        final expected = switch (status) {
          400 || 422 => isA<ValidationException>(),
          404 => isA<NotFoundException>(),
          409 => isA<ConflictException>(),
          503 => isA<DependencyUnavailableException>(),
          _ => isA<ApiException>(),
        };
        await expectLater(
          api.client.request('GET', '/api/v1/me/profile'),
          throwsA(
            expected.having(
              (e) => e.toString(),
              'safe message',
              isNot(contains('Internal details')),
            ),
          ),
        );
        expect(api.requests, hasLength(1));
      },
    );
  }
  test(
    'Malformed JSON is a safe error and numeric IDs are rejected without conversion',
    () async {
      expect(() => decimalId(9007199254740992), throwsA(isA<ApiException>()));
      api.intercept = (_) async => http.Response('<private trace>', 200);
      await expectLater(
        api.client.request('GET', '/x'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    },
  );
  test('Deadline aborts the request and flags uncertain writes', () async {
    final blocking = _BlockingClient();
    final client = ApiClient(
      'http://api.example.test',
      transport: blocking,
      requestTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(client.close);
    await expectLater(
      client.request('POST', '/api/v1/reminders', body: {}),
      throwsA(
        isA<RequestTimeoutException>().having(
          (e) => e.uncertain,
          'uncertain',
          true,
        ),
      ),
    );
    await blocking.aborted.future;
  });
}

class _BlockingClient extends http.BaseClient {
  final aborted = Completer<void>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await (request as http.AbortableRequest).abortTrigger;
    aborted.complete();
    throw http.RequestAbortedException(request.url);
  }
}
