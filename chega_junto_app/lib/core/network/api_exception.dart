class ApiException implements Exception {
  const ApiException(this.message, {this.code = 'api_error', this.status});
  final String message, code;
  final int? status;
  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException({this.uncertain = false})
    : super(
        'Não foi possível conectar. Verifique sua conexão e tente novamente.',
        code: 'network_error',
      );
  final bool uncertain;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({String code = 'invalid_token'})
    : super(
        code == 'invalid_credentials'
            ? 'E-mail ou senha inválidos.'
            : 'Sua sessão expirou. Entre novamente.',
        code: code,
        status: 401,
      );
}

class EmailAlreadyRegisteredException extends ApiException {
  const EmailAlreadyRegisteredException()
    : super(
        'Já existe uma conta com este e-mail.',
        code: 'email_already_registered',
        status: 409,
      );
}

class RequestTimeoutException extends NetworkException {
  const RequestTimeoutException({super.uncertain});
}

class ValidationException extends ApiException {
  const ValidationException({int? status})
    : super(
        'Confira os dados informados antes de salvar.',
        code: 'validation_error',
        status: status,
      );
}

class NotFoundException extends ApiException {
  const NotFoundException()
    : super('Recurso não encontrado.', code: 'resource_not_found', status: 404);
}

class ConflictException extends ApiException {
  const ConflictException({String code = 'conflict'})
    : super(
        'Seu relato foi atualizado em outro momento. Recarregue a versão mais recente antes de salvar novamente. Seu rascunho foi preservado.',
        code: code,
        status: 409,
      );
}

class DependencyUnavailableException extends ApiException {
  const DependencyUnavailableException()
    : super(
        'O serviço está temporariamente indisponível. Tente novamente em instantes.',
        code: 'dependency_unavailable',
        status: 503,
      );
}

String userError(
  Object? error, [
  String fallback = 'Não foi possível concluir. Tente novamente.',
]) => error is ApiException ? error.message : fallback;
