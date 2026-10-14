import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chega_junto_app/core/network/api_client.dart';
import 'package:chega_junto_app/core/network/api_exception.dart';
import 'package:chega_junto_app/data/api/api_clarification_repository.dart';
import 'package:chega_junto_app/data/api/api_mapping.dart';
import 'package:chega_junto_app/data/models/report_clarification.dart';
import 'support/fake_api.dart';

void main() {
  late List<http.Request> requests;
  late ApiClient client;
  late ApiClarificationRepository repository;
  late Json fixture;
  setUp(() {
    requests = [];
    fixture = reportFixture()
      ..addAll({
        'current_source_hash': 'a' * 64,
        'clarifications_current': true,
        'clarifications_completed': false,
        'clarifications': [
          {
            'id': largeId,
            'question_text': 'Quando percebeu?',
            'answer_mode': 'single_choice',
            'options': ['Hoje', 'Antes'],
            'position': 0,
            'answer_kind': null,
            'answer_text': null,
            'answered_at': null,
          },
        ],
      });
    client = ApiClient(
      'https://api.example.test',
      transport: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/next')
                ? {'done': false, 'clarification': fixture['clarifications'][0]}
                : fixture,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = ApiClarificationRepository(client);
  });
  tearDown(() => client.close());
  test(
    'Próxima pergunta faz um POST seguido de leitura canônica e preserva BIGINT',
    () async {
      final report = await repository.next(largeId);
      expect(requests.map((r) => r.method), ['POST', 'GET']);
      expect(
        requests.first.url.path,
        '/api/v1/appointments/$largeId/report/clarifications/next',
      );
      expect(report.clarifications.single.id, largeId);
      expect(report.currentSourceHash, 'a' * 64);
      expect(report.clarifications.single.answered, false);
    },
  );
  for (final kind in ClarificationAnswerKind.values) {
    test('Resposta ${kind.wire} usa PUT isolado com revisão', () async {
      final text =
          [
            ClarificationAnswerKind.text,
            ClarificationAnswerKind.option,
          ].contains(kind)
          ? 'Antes'
          : null;
      await repository.answer(largeId, largeId, kind, text, '42');
      expect(requests.length, 1);
      expect(requests.single.method, 'PUT');
      expect(jsonDecode(requests.single.body), {
        'answer_kind': kind.wire,
        'answer_text': text,
        'expected_revision': '42',
      });
    });
  }
  test('Pular não chama organização nem próxima pergunta', () async {
    await repository.skip(largeId);
    expect(requests.length, 1);
    expect(requests.single.url.path, endsWith('/clarifications/skip'));
  });
  test('Falha não causa retry automático', () async {
    var calls = 0;
    final failing = ApiClient(
      'https://api.example.test',
      transport: MockClient((_) async {
        calls++;
        return http.Response(
          '{"error":{"code":"ai_timeout","message":"Indisponível"}}',
          503,
        );
      }),
    );
    addTearDown(failing.close);
    await expectLater(
      ApiClarificationRepository(failing).next(largeId),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });
  test('DTO V8 sem complemento mantém revisão final e não inventa dados', () {
    final value = reportFromJson(reportFixture());
    expect(value.finalDone, true);
    expect(value.clarifications, isEmpty);
    expect(value.clarificationsCurrent, false);
  });
}
