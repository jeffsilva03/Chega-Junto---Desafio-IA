import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chega_junto_app/core/network/api_client.dart';
import 'package:chega_junto_app/core/auth/auth_token_store.dart';

const largeId = '18446744073709551615';
const stamp = '2026-10-09T11:00:00Z';
Json profileFixture() => {
  'id': largeId,
  'full_name': 'Pessoa fictícia da API',
  'email': 'demo@example.test',
  'phone': '11999999999',
  'birth_date': '1985-04-12',
  'cpf': '12345678900',
  'postcode': '01000000',
  'street': 'Rua fictícia',
  'number': '123',
  'complement': null,
  'neighborhood': 'Centro',
  'city': 'São Paulo',
  'state_code': 'SP',
  'emergency_name': 'Contato fictício',
  'emergency_relationship': 'Familiar',
  'emergency_phone': '11988880000',
  'sus_card_number': '700123456789012',
  'created_at': stamp,
  'updated_at': stamp,
};
Json appointmentFixture() => {
  'id': largeId,
  'type': 'consultation',
  'title': 'Consulta fictícia API',
  'specialty': 'Clínica geral',
  'professional_name': 'Profissional fictício',
  'scheduled_at': stamp,
  'timezone': 'America/Sao_Paulo',
  'facility': {
    'id': '2',
    'name': 'Unidade fictícia API',
    'address_text': 'Endereço fictício',
    'is_active': true,
  },
  'attendance_status': 'confirmed',
  'instructions': ['Orientação fictícia.'],
  'attendance_responded_at': stamp,
};
Json progressFixture({bool finalDone = false, bool documentsDone = true}) => {
  'documents_done': documentsDone,
  'attendance_done': true,
  'report_done': true,
  'final_done': finalDone,
  'completed_count': (documentsDone ? 3 : 2) + (finalDone ? 1 : 0),
  'total_count': 4,
  'fraction': ((documentsDone ? 3 : 2) + (finalDone ? 1 : 0)) / 4,
  'percentage': ((documentsDone ? 3 : 2) + (finalDone ? 1 : 0)) * 25,
};
Json reportFixture({String revision = '1'}) => {
  'id': '8',
  'appointment_id': largeId,
  'original_text': 'Texto fictício original.',
  'organized_at': stamp,
  'content_revision': revision,
  'reviewed_revision': revision,
  'reviewed_at': stamp,
  'final_review_revision': revision,
  'final_review_at': stamp,
  'updated_at': stamp,
  'organization_current': true,
  'has_content': true,
  'reviewed': true,
  'final_done': true,
  'sections': [
    {
      'id': largeId,
      'section_key': 'reason',
      'title': 'Motivo',
      'text': 'Minha edição preservada.',
      'position': 0,
    },
    {
      'id': '5',
      'section_key': 'other',
      'title': 'Outras informações',
      'text': '',
      'position': 1,
    },
  ],
  'questions': [
    {
      'id': '11',
      'text': 'Pergunta não selecionada?',
      'is_selected': false,
      'position': 0,
    },
    {
      'id': '10',
      'text': 'Pergunta selecionada?',
      'is_selected': true,
      'position': 1,
    },
  ],
};
Json notificationFixture() => {
  'id': largeId,
  'title': 'Aviso fictício API',
  'message': 'Mensagem fictícia.',
  'published_at': stamp,
  'category': 'consultation',
  'destination': 'appointment',
  'appointment_id': largeId,
  'health_record_id': null,
  'reminder_id': null,
  'read_at': null,
  'is_read': false,
};
Json healthFixture() => {
  'medications': [
    {
      'id': largeId,
      'name': 'Item fictício',
      'details': 'Uso informado',
      'position': 0,
    },
  ],
  'allergies': [
    {
      'id': '7',
      'name': 'Alergia fictícia',
      'details': 'Reação informada',
      'position': 0,
    },
  ],
};
Json recordFixture({bool detail = false}) => {
  'id': largeId,
  'type': 'exam',
  'occurred_at': '2026-10-06T11:00:00Z',
  'title': 'Histórico fictício API',
  'subtitle': 'Registro anterior',
  if (detail) ...{
    'professional_text': 'Profissional fictício',
    'facility_text': 'Unidade fictícia',
    'reason': 'Motivo informado',
    'summary': 'Resumo informado',
    'notes': ['Nota fictícia'],
    'documents': [
      {
        'id': '2',
        'title': 'Documento textual',
        'content_text': 'Conteúdo fictício',
        'position': 0,
      },
    ],
  },
};
Json accessibilityFixture() => {
  'text_size': 'medium',
  'appearance': 'light',
  'high_contrast': false,
  'speech': false,
  'descriptions': true,
  'simple_language': true,
  'haptics': true,
  'reduce_motion': false,
};
Json preferencesFixture() => {
  'active': true,
  'appointments': true,
  'exams': true,
  'medications': true,
  'documents': true,
  'confirmations': true,
  'system': false,
  'in_app': true,
};
Json page(List<Json> items, {int? total, int offset = 0, int? unread}) => {
  'items': items,
  'pagination': {
    'total': total ?? items.length,
    'limit': 100,
    'offset': offset,
  },
  'unread_count': ?unread,
};
http.Response response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response failure(int status, [String code = 'test_error']) => response({
  'error': {
    'code': code,
    'message': 'Internal details must never appear in UI',
  },
}, status);

/// In-memory HTTP contract fixture. Never reads .env or reaches Aiven.
class FakeApi {
  FakeApi({AuthTokenStore? tokenStore}) {
    transport = MockClient(_handle);
    client = ApiClient(
      'http://api.example.test',
      transport: transport,
      tokenStore: tokenStore,
    );
  }
  late final http.Client transport;
  late final ApiClient client;
  final List<http.Request> requests = [];
  Future<http.Response?> Function(http.Request request)? intercept;
  Json profile = profileFixture(),
      health = healthFixture(),
      report = reportFixture(),
      notification = notificationFixture();
  Json accessibility = accessibilityFixture(),
      preferences = preferencesFixture();
  Json appointment = appointmentFixture();
  Json progress = progressFixture(finalDone: true);
  bool reportAbsent = false, emptyOverview = false;
  final List<Json> reminders = [];
  int _revisionIndex = 1;
  Json checklist() => {
    'items': [
      {
        'id': '3',
        'item_key': 'document',
        'title': 'Documento',
        'section': 'documents',
        'is_required': true,
        'is_completed': progress['documents_done'],
        'position': 0,
      },
    ],
    'fraction': progress['documents_done'] ? 1.0 : 0.0,
    'percentage': progress['documents_done'] ? 100 : 0,
    'required_count': 1,
    'required_completed_count': progress['documents_done'] ? 1 : 0,
    'progress': progress,
  };
  Json preparation() => {
    'appointment': appointment,
    'progress': progress,
    'checklist': checklist(),
    'attendance': {
      'appointment_id': largeId,
      'attendance_status': appointment['attendance_status'],
      'attendance_responded_at': stamp,
    },
    'report': {
      'organization_current': report['organization_current'],
      'has_content': report['has_content'],
      'reviewed': report['reviewed'],
      'final_done': report['final_done'],
    },
  };
  Json overview() => {
    'user': {
      'id': '1',
      'full_name': profile['full_name'],
      'first_name': 'Pessoa',
      'timezone': 'America/Sao_Paulo',
    },
    'reference_date': '2026-10-09',
    'next_appointment': emptyOverview ? null : appointment,
    'preparation': emptyOverview ? null : preparation(),
  };
  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final override = await intercept?.call(request);
    if (override != null) return override;
    final path = request.url.path;
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Json;
    if (path == '/health') return response({'status': 'ok', 'database': 'ok'});
    if (path == '/api/v1/me/profile') {
      if (request.method == 'PUT') {
        profile = {
          ...profile,
          ...body,
          'full_name': (body['full_name'] as String).trim(),
        };
      }
      return response(profile);
    }
    if (path == '/api/v1/me/health-items') {
      if (request.method == 'PUT') {
        health = {
          for (final key in ['medications', 'allergies'])
            key: [
              for (final (index, item) in (body[key] as List).indexed)
                {...item as Json, 'id': item['id'] ?? '999', 'position': index},
            ],
        };
      }
      return response(health);
    }
    if (path == '/api/v1/me/health-records') {
      return response(page([recordFixture()]));
    }
    if (path.startsWith('/api/v1/me/health-records/')) {
      return response(recordFixture(detail: true));
    }
    if (path == '/api/v1/me/accessibility-preferences') {
      if (request.method == 'PUT') accessibility = body;
      return response(accessibility);
    }
    if (path == '/api/v1/me/notification-preferences') {
      if (request.method == 'PUT') preferences = body;
      return response(preferences);
    }
    if (path == '/api/v1/me/notifications') {
      return response(
        page(
          preferences['active'] ? [notification] : [],
          unread: preferences['active'] && !notification['is_read'] ? 1 : 0,
        ),
      );
    }
    if (path.startsWith('/api/v1/me/notifications/')) {
      notification = {...notification, 'is_read': true, 'read_at': stamp};
      return response(notification);
    }
    if (path == '/api/v1/appointments') return response(page([appointment]));
    if (path == '/api/v1/preparation/overview') return response(overview());
    if (path == '/api/v1/reminders') {
      if (request.method == 'POST') {
        final created = {
          ...body,
          'id': '99',
          'created_at': stamp,
          'appointment_id': body['appointment_id'],
        };
        reminders.add(created);
        return response(created, 201);
      }
      return response(page(reminders));
    }
    if (path.endsWith('/preparation')) return response(preparation());
    if (path.endsWith('/attendance')) {
      if (request.method == 'PUT') appointment = {...appointment, ...body};
      return response({
        'appointment_id': largeId,
        'attendance_status': appointment['attendance_status'],
        'attendance_responded_at': stamp,
      });
    }
    if (path.contains('/checklist')) {
      if (request.method == 'PATCH') {
        progress = progressFixture(documentsDone: body['is_completed']);
      }
      return response(checklist());
    }
    if (path.endsWith('/report') && request.method == 'GET') {
      return reportAbsent
          ? failure(404, 'resource_not_found')
          : response(report);
    }
    if (path.contains('/report') || path.endsWith('/final-review')) {
      final expected =
          body['expected_revision'] ??
          request.url.queryParameters['expected_revision'];
      if (expected != (reportAbsent ? '0' : report['content_revision'])) {
        return failure(409, 'revision_conflict');
      }
      if (path.endsWith('/report') && request.method == 'PUT') {
        reportAbsent = false;
        report = {
          ...report,
          'original_text': body['original_text'],
          'content_revision': '${++_revisionIndex}',
          'reviewed': false,
          'final_done': false,
          'organization_current':
              body['intent'] == 'organize' ||
              report['organization_current'] &&
                  body['original_text'] == report['original_text'],
          'sections': [
            for (final (index, s) in (body['sections'] as List).indexed)
              {
                ...s as Json,
                'id': s['id'] ?? '${100 + index}',
                'position': index,
              },
          ],
          'questions': [
            for (final (index, q) in (body['questions'] as List).indexed)
              {
                ...q as Json,
                'id': q['id'] ?? '${200 + index}',
                'position': index,
              },
          ],
        };
        report['has_content'] = (report['sections'] as List).any(
          (s) => (s['text'] as String).trim().isNotEmpty,
        );
      } else if (path.endsWith('/summary')) {
        report = {
          ...report,
          'sections': [
            for (final s in report['sections']) {...s as Json, 'text': ''},
          ],
          'questions': [],
          'organization_current': false,
          'has_content': false,
          'reviewed': false,
          'final_done': false,
        };
      } else if (path.endsWith('/review')) {
        report = {
          ...report,
          'reviewed': true,
          'reviewed_revision': expected,
          'reviewed_at': stamp,
        };
      } else if (path.endsWith('/final-review')) {
        report = {
          ...report,
          'final_done': body['completed'],
          'final_review_revision': body['completed'] ? expected : null,
          'final_review_at': body['completed'] ? stamp : null,
        };
      }
      progress = progressFixture(finalDone: report['final_done']);
      return response(report);
    }
    return response(appointment);
  }

  List<http.Request> get mutations =>
      requests.where((r) => r.method != 'GET').toList();
  void close() => client.close();
}
