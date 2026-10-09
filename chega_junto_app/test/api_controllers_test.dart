import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:chega_junto_app/core/network/api_exception.dart';
import 'package:chega_junto_app/core/state/preparation_controller.dart';
import 'package:chega_junto_app/core/state/profile_controller.dart';
import 'package:chega_junto_app/core/state/report_controller.dart';
import 'package:chega_junto_app/data/api/api_preparation_repository.dart';
import 'package:chega_junto_app/data/api/api_profile_repository.dart';
import 'package:chega_junto_app/data/api/api_notification_repository.dart';
import 'package:chega_junto_app/data/api/api_preferences_repository.dart';
import 'package:chega_junto_app/data/mock/mock_ai_assistant_service.dart';
import 'package:chega_junto_app/data/mock/mock_audio_draft_service.dart';
import 'package:chega_junto_app/data/models/appointment.dart';
import 'package:chega_junto_app/data/models/appointment_reminder.dart';
import 'package:chega_junto_app/data/models/profile_preferences.dart';
import 'support/fake_api.dart';

void main() {
  late FakeApi api;
  late PreparationController preparation;
  late ProfileController profile;
  setUp(() {
    api = FakeApi();
    preparation = PreparationController(
      ApiPreparationRepository(api.client),
      persistDraftInvalidation: false,
    );
    profile = ProfileController(
      ApiProfileRepository(api.client),
      preferences: ApiPreferencesRepository(api.client),
      notificationRepository: ApiNotificationRepository(api.client),
    );
    preparation.onChanged = profile.reloadNotifications;
  });
  tearDown(() {
    preparation.dispose();
    profile.dispose();
    api.close();
  });
  ReportController draft({Duration? delay}) {
    final state = ReportController(
      preparation,
      const MockAiAssistantService(delay: Duration.zero),
      const MockAudioDraftService(delay: Duration.zero),
      autosaveDelay: delay,
    );
    addTearDown(state.dispose);
    return state;
  }

  test(
    'Profile loading, failure and retry use asynchronous API repositories',
    () async {
      final gate = Completer<void>();
      api.intercept = (r) async {
        await gate.future;
        return null;
      };
      final pending = profile.load();
      expect(profile.loading, true);
      expect(profile.profile, isNull);
      gate.complete();
      await pending;
      expect(profile.loading, false);
      expect(profile.failed, false);
      expect(profile.profile!.fullName, 'Pessoa fictícia da API');
      api.intercept = (_) async => throw http.ClientException('network');
      await profile.load();
      expect(profile.failed, true);
      expect(profile.error, isA<NetworkException>());
      api.intercept = null;
      await profile.load();
      expect(profile.failed, false);
    },
  );
  test(
    'Profile and health saves replace local state with canonical responses',
    () async {
      await profile.load();
      await profile.saveProfile(
        profile.profile!.copyWith(fullName: '  Edição fictícia  '),
      );
      expect(profile.profile!.fullName, 'Edição fictícia');
      final original = profile.health!;
      api.intercept = (r) async =>
          r.method == 'PUT' && r.url.path.endsWith('/health-items')
          ? response({
              'medications': [
                {
                  'id': '9999',
                  'name': 'Nome canônico',
                  'details': 'Dados fictícios',
                  'position': 0,
                },
              ],
              'allergies': [],
            })
          : null;
      await profile.saveHealth(original.medications, original.allergies);
      expect(profile.health!.medications.single.id, '9999');
      expect(profile.health!.medications.single.name, 'Nome canônico');
      expect(profile.health!.allergies, isEmpty);
    },
  );
  test('Failed save preserves prior profile and health state', () async {
    await profile.load();
    final old = profile.profile, health = profile.health;
    api.intercept = (r) async => r.method == 'PUT' ? failure(503) : null;
    await expectLater(
      profile.saveProfile(old!.copyWith(fullName: 'Outro fictício')),
      throwsA(isA<DependencyUnavailableException>()),
    );
    await expectLater(
      profile.saveHealth([], []),
      throwsA(isA<DependencyUnavailableException>()),
    );
    expect(profile.profile, same(old));
    expect(profile.health, same(health));
  });
  test(
    'Preparation loading failure and retry preserve source without fallback',
    () async {
      api.intercept = (_) async => failure(503);
      await preparation.load();
      expect(preparation.failed, true);
      expect(preparation.overview, isNull);
      api.intercept = null;
      await preparation.load();
      expect(preparation.failed, false);
      expect(preparation.overview!.nextAppointment.id, largeId);
    },
  );
  test(
    'Checklist waits for successful canonical data, and failure keeps it unchanged',
    () async {
      await preparation.load();
      api.intercept = (r) async => r.method == 'PATCH' ? failure(503) : null;
      await expectLater(
        preparation.setChecklistItem('3', false),
        throwsA(isA<DependencyUnavailableException>()),
      );
      expect(preparation.overview!.checklist.single.isCompleted, true);
      expect(preparation.saving, false);
      api.intercept = null;
      await preparation.setChecklistItem('3', false);
      expect(preparation.overview!.checklist.single.isCompleted, false);
      expect(preparation.overview!.progress.percentage, 50);
    },
  );
  test(
    'Attendance and reminder refresh canonical agenda and notifications',
    () async {
      await Future.wait([preparation.load(), profile.load()]);
      final count = api.requests
          .where((r) => r.url.path.endsWith('/notifications'))
          .length;
      await preparation.setAttendance(ConfirmationStatus.undecided);
      expect(
        preparation.appointments.single.confirmationStatus,
        ConfirmationStatus.undecided,
      );
      await preparation.addReminder(
        AppointmentReminder(
          id: 'local',
          title: 'Fictício',
          dateTime: DateTime.utc(2026, 10, 8),
          appointmentId: largeId,
        ),
      );
      expect(preparation.reminders.single.id, '99');
      expect(
        api.requests.where((r) => r.url.path.endsWith('/notifications')).length,
        greaterThan(count),
      );
    },
  );
  test(
    'Report hydration is complete and read-only, including unselected questions',
    () async {
      final report = draft();
      await preparation.load();
      expect(report.text, 'Texto fictício original.');
      expect(report.sections.last.text, '');
      expect(report.questions.first.selected, false);
      expect(report.questions.first.id, '11');
      expect(report.reviewed, true);
      expect(report.contentRevision, '1');
      expect(report.finalReviewRevision, '1');
      expect(report.summaryOutdated, false);
      expect(api.mutations, isEmpty);
    },
  );
  test(
    'Absent report loads normally and first draft write sends expected_revision zero',
    () async {
      api.reportAbsent = true;
      await preparation.load();
      final report = draft();
      expect(report.contentRevision, '0');
      report.setText('Primeiro relato fictício');
      await report.saveDraft();
      expect(jsonDecode(api.mutations.first.body)['expected_revision'], '0');
      expect(report.contentRevision, api.report['content_revision']);
      expect(report.hasUnsavedChanges, false);
    },
  );
  test(
    'Organization stays local/mock, persists exact source, and canonical IDs are reused',
    () async {
      await preparation.load();
      final report = draft();
      report.setText('Meu texto fictício exato.');
      expect(await report.organize(), true);
      final organized = jsonDecode(api.mutations.first.body);
      expect(organized['intent'], 'organize');
      expect(
        organized['organization_source_text'],
        'Meu texto fictício exato.',
      );
      expect(organized['sections'].first.containsKey('id'), false);
      final canonical = report.sections.first.serverId;
      report.editSection('reason', 'Minha edição fictícia.');
      report.selectQuestion(report.questions.first.id, false);
      await report.saveDraft();
      final sent = jsonDecode(api.mutations.last.body);
      expect(sent['sections'].first['id'], canonical);
      expect(sent['intent'], 'edit');
      expect(sent['questions'].first['is_selected'], false);
      expect(report.contentRevision, api.report['content_revision']);
    },
  );
  test(
    'Conflict preserves local edits, blocks retries and allows explicit canonical reload',
    () async {
      await preparation.load();
      final report = draft();
      report.setText('Rascunho local que não pode sumir.');
      api.report['content_revision'] = '9';
      api.report['original_text'] = 'Versão remota fictícia.';
      await expectLater(report.saveDraft(), throwsA(isA<ConflictException>()));
      expect(report.conflict, true);
      expect(report.text, 'Rascunho local que não pode sumir.');
      expect(report.contentRevision, '1');
      final mutations = api.mutations.length;
      await expectLater(report.saveDraft(), throwsA(isA<ConflictException>()));
      expect(api.mutations.length, mutations);
      await report.reloadLatest();
      expect(report.text, 'Versão remota fictícia.');
      expect(report.contentRevision, '9');
      expect(
        report.preservedDraft!.originalText,
        'Rascunho local que não pode sumir.',
      );
      expect(report.conflict, false);
      report.restorePreservedDraft();
      expect(report.text, 'Rascunho local que não pode sumir.');
      expect(report.contentRevision, '9');
      expect(report.hasUnsavedChanges, true);
      expect(api.mutations.length, mutations);
    },
  );
  test(
    'An edit made while HTTP is pending survives and next write uses returned revision',
    () async {
      await preparation.load();
      final report = draft();
      final gate = Completer<void>(), started = Completer<void>();
      api.intercept = (r) async {
        if (r.method == 'PUT' && r.url.path.endsWith('/report')) {
          if (!started.isCompleted) started.complete();
          await gate.future;
        }
        return null;
      };
      report.setText('Primeira edição fictícia');
      final pending = report.saveDraft();
      await started.future;
      report.setText('Segunda edição fictícia durante HTTP');
      gate.complete();
      await pending;
      expect(report.text, 'Segunda edição fictícia durante HTTP');
      expect(report.hasUnsavedChanges, true);
      final received = report.contentRevision;
      await report.saveDraft();
      expect(
        jsonDecode(api.mutations.last.body)['expected_revision'],
        received,
      );
      expect(
        api.report['original_text'],
        'Segunda edição fictícia durante HTTP',
      );
      expect(report.hasUnsavedChanges, false);
    },
  );
  test(
    'Review/final persist current revision and a fresh controller restores completion',
    () async {
      await preparation.load();
      final report = draft();
      report.editSection('reason', 'Revisão fictícia humana.');
      await report.finishReview();
      expect(report.reviewed, true);
      expect(report.reviewedRevision, report.contentRevision);
      await report.completePreparation();
      expect(preparation.overview!.progress.percentage, 100);
      expect(report.finalReviewRevision, report.contentRevision);
      final next = PreparationController(
        ApiPreparationRepository(api.client),
        persistDraftInvalidation: false,
      );
      addTearDown(next.dispose);
      await next.load();
      final reopened = ReportController(
        next,
        const MockAiAssistantService(),
        const MockAudioDraftService(),
      );
      addTearDown(reopened.dispose);
      expect(reopened.sections.first.text, 'Revisão fictícia humana.');
      expect(reopened.reviewed, true);
      expect(next.finalReviewCompleted, true);
      expect(reopened.questions.first.selected, false);
    },
  );
  test(
    'Review and final conflicts cannot announce success or discard the draft',
    () async {
      await preparation.load();
      final report = draft();
      api.intercept = (r) async =>
          r.method == 'POST' && r.url.path.endsWith('/review')
          ? failure(409, 'revision_conflict')
          : null;
      await expectLater(
        report.finishReview(),
        throwsA(isA<ConflictException>()),
      );
      expect(report.conflict, true);
      expect(report.text, 'Texto fictício original.');
      api.intercept = null;
      await report.reloadLatest();
      api.intercept = (r) async => r.url.path.endsWith('/final-review')
          ? failure(409, 'revision_conflict')
          : null;
      await expectLater(
        report.completePreparation(),
        throwsA(isA<ConflictException>()),
      );
      expect(report.conflict, true);
    },
  );
  test(
    'Removing summary uses DELETE, preserves original and updates canonical state',
    () async {
      await preparation.load();
      final report = draft();
      final original = report.text;
      report.clearSummary();
      await report.saveDraft();
      expect(api.mutations.last.method, 'DELETE');
      expect(report.text, original);
      expect(report.questions, isEmpty);
      expect(report.hasContent, false);
      expect(report.reviewed, false);
    },
  );
  test(
    'Notification read waits for PATCH and failures preserve unread badge',
    () async {
      await profile.load();
      expect(profile.inbox.unreadCount, 1);
      api.intercept = (r) async => r.method == 'PATCH' ? failure(503) : null;
      await expectLater(
        profile.markRead(largeId),
        throwsA(isA<DependencyUnavailableException>()),
      );
      expect(profile.isRead(largeId), false);
      expect(profile.inbox.unreadCount, 1);
      api.intercept = null;
      await profile.markRead(largeId);
      expect(profile.isRead(largeId), true);
      expect(profile.inbox.unreadCount, 0);
      await profile.markRead(largeId);
      expect(profile.inbox.unreadCount, 0);
    },
  );
  test(
    'Notification loading failure has a retry independent of Profile loading',
    () async {
      await profile.load();
      api.intercept = (r) async =>
          r.url.path.endsWith('/notifications') ? failure(503) : null;
      await profile.reloadNotifications();
      expect(profile.notificationError, isA<DependencyUnavailableException>());
      expect(profile.failed, false);
      expect(profile.notificationsLoading, false);
      api.intercept = null;
      await profile.reloadNotifications();
      expect(profile.notificationError, isNull);
    },
  );
  test(
    'Preference saves persist, rollback failures, and retry the requested value',
    () async {
      await profile.load();
      final original = profile.accessibility;
      api.intercept = (r) async => r.method == 'PUT' ? failure(503) : null;
      await profile.setAccessibility(original.copyWith(highContrast: true));
      expect(profile.accessibility.highContrast, false);
      expect(profile.preferenceError, isA<DependencyUnavailableException>());
      api.intercept = null;
      await profile.retryPreferences();
      expect(profile.accessibility.highContrast, true);
      await profile.setNotification(NotificationOption.active, false);
      expect(profile.inbox.unreadCount, 0);
      await profile.load();
      expect(profile.accessibility.highContrast, true);
      expect(profile.notifications.enabled(NotificationOption.active), false);
      expect(profile.preferencesSaving, false);
    },
  );
  test(
    'Confirmed reminder is not offered as a failed POST when subsequent GET fails',
    () async {
      await preparation.load();
      api.intercept = (r) async =>
          r.method == 'GET' && r.url.path.endsWith('/reminders')
          ? failure(503)
          : null;
      await preparation.addReminder(
        AppointmentReminder(
          id: 'local',
          title: 'Fictício confirmado',
          dateTime: DateTime.utc(2026, 10, 8),
        ),
      );
      expect(preparation.reminders.single.id, '99');
      expect(
        preparation.reminderRefreshError,
        isA<DependencyUnavailableException>(),
      );
      expect(api.mutations.where((r) => r.method == 'POST'), hasLength(1));
    },
  );
  test(
    'Final review uses the revision actually reviewed, even if a later GET sees another version',
    () async {
      await preparation.load();
      final report = draft();
      api.intercept = (r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/review')) {
          final old = {...api.report};
          api.report['content_revision'] = '9';
          return response(old);
        }
        return null;
      };
      await expectLater(
        report.completePreparation(),
        throwsA(isA<ConflictException>()),
      );
      expect(jsonDecode(api.mutations.last.body)['expected_revision'], '1');
      expect(report.conflict, true);
    },
  );
  test(
    'API draft debounce persists text without review or navigation',
    () async {
      await preparation.load();
      final started = Completer<void>();
      api.intercept = (r) async {
        if (r.method == 'PUT' && r.url.path.endsWith('/report')) {
          started.complete();
        }
        return null;
      };
      final report = draft(delay: const Duration(milliseconds: 10));
      report.setText('Rascunho fictício persistido sozinho');
      expect(api.mutations, isEmpty);
      await started.future.timeout(const Duration(seconds: 3));
      await report.saveDraft();
      expect(
        api.report['original_text'],
        'Rascunho fictício persistido sozinho',
      );
      expect(report.hasUnsavedChanges, false);
      expect(api.mutations, hasLength(1));
    },
  );
}
