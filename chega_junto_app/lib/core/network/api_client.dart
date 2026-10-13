import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import '../config/data_config.dart';
import 'api_exception.dart';
import 'http_transport.dart' if (dart.library.io) 'http_transport_io.dart';
import '../auth/auth_token_store.dart';

typedef Json = Map<String, dynamic>;

class ApiClient {
  ApiClient(
    String baseUrl, {
    http.Client? transport,
    Duration connectTimeout = DataConfig.connectTimeout,
    this.requestTimeout = DataConfig.requestTimeout,
    this.tokenStore,
    this.onUnauthorized,
  }) : base = Uri.parse(baseUrl),
       _transport = transport ?? createTransport(connectTimeout) {
    if (!['http', 'https'].contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw ArgumentError(
        'API_BASE_URL deve ser a origem HTTP/HTTPS da API, sem credenciais ou caminho.',
      );
    }
  }
  final Uri base;
  final http.Client _transport;
  final Duration requestTimeout;
  final AuthTokenStore? tokenStore;
  Future<void> Function()? onUnauthorized;
  final Set<Completer<void>> _pending = {};
  bool _closed = false;

  Future<Json> request(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
    bool authenticated = true,
    Duration? timeout,
    Uint8List? audioBytes,
  }) async {
    if (_closed) throw const NetworkException();
    final token = authenticated ? await tokenStore?.read() : null;
    if (_closed) throw const NetworkException();
    final abort = Completer<void>();
    _pending.add(abort);
    final http.BaseRequest request;
    final uri = base.replace(path: path, queryParameters: query);
    if (audioBytes != null) {
      request =
          http.AbortableMultipartRequest(
              method,
              uri,
              abortTrigger: abort.future,
            )
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                audioBytes,
                filename: 'recording.wav',
                contentType: MediaType('audio', 'wav'),
              ),
            );
    } else {
      final jsonRequest = http.AbortableRequest(
        method,
        base.replace(path: path, queryParameters: query),
        abortTrigger: abort.future,
      );
      if (body != null) jsonRequest.body = jsonEncode(body);
      request = jsonRequest;
    }
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    });
    request.followRedirects = false;
    try {
      final response =
          await (() async => http.Response.fromStream(
            await _transport.send(request),
          ))().timeout(
            timeout ?? requestTimeout,
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw RequestTimeoutException(uncertain: method != 'GET');
            },
          );
      Json decoded = {};
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Json;
      } catch (_) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw const ApiException(
            'Não foi possível ler a resposta do serviço.',
            code: 'invalid_response',
          );
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      final envelope = decoded['error'];
      final code = envelope is Map && envelope['code'] is String
          ? envelope['code'] as String
          : 'api_error';
      if ({
        'ai_daily_limit_reached',
        'ai_unavailable',
        'ai_invalid_output',
        'audio_invalid',
        'audio_too_large',
        'transcription_failed',
        'transcription_too_long',
      }.contains(code)) {
        throw ApiException(
          switch (code) {
            'ai_daily_limit_reached' =>
              'Limite diário da demonstração atingido. Tente novamente mais tarde.',
            'audio_too_large' => 'O áudio deve ter no máximo 10 MB.',
            'transcription_too_long' =>
              'Transcrição muito longa. Faça uma gravação menor.',
            'audio_invalid' =>
              'Áudio inválido. Grave novamente em um formato compatível.',
            _ =>
              'Não foi possível processar com IA agora. Tente novamente mais tarde.',
          },
          code: code,
          status: response.statusCode,
        );
      }
      if (response.statusCode == 401) {
        if (!_closed &&
            authenticated &&
            token != null &&
            await tokenStore?.read() == token) {
          await onUnauthorized?.call();
        }
        throw UnauthorizedException(code: code);
      }
      throw switch (response.statusCode) {
        400 || 422 => ValidationException(status: response.statusCode),
        404 => const NotFoundException(),
        409 =>
          code == 'email_already_registered'
              ? const EmailAlreadyRegisteredException()
              : ConflictException(code: code),
        503 => const DependencyUnavailableException(),
        _ => ApiException(
          'Não foi possível concluir. Tente novamente em instantes.',
          code: code,
          status: response.statusCode,
        ),
      };
    } on ApiException {
      rethrow;
    } on http.ClientException {
      throw NetworkException(uncertain: method != 'GET');
    } on TimeoutException {
      throw RequestTimeoutException(uncertain: method != 'GET');
    } finally {
      _pending.remove(abort);
    }
  }

  /// UI currently shows complete small lists; pagination stays at this boundary.
  Future<List<Json>> pages(String path, {void Function(Json)? onPage}) async {
    final items = <Json>[];
    for (var offset = 0; offset <= 100000;) {
      final page = await request(
        'GET',
        path,
        query: {'limit': '100', 'offset': '$offset'},
      );
      onPage?.call(page);
      final batch = (page['items'] as List).cast<Json>();
      items.addAll(batch);
      final total = (page['pagination'] as Json)['total'] as int;
      if (items.length >= total) return items;
      if (batch.isEmpty) break;
      offset += batch.length;
    }
    throw const ApiException(
      'Não foi possível carregar a lista completa.',
      code: 'invalid_pagination',
    );
  }

  void close() {
    _closed = true;
    for (final abort in _pending) {
      if (!abort.isCompleted) abort.complete();
    }
    _transport.close();
  }
}
