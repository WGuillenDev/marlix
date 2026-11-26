/// Typed failures from the Marlix API. Messages come from the API contract.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends ApiException {
  const NetworkException(super.message);
}

/// A cold backend can take up to a minute to respond.
class ApiTimeoutException extends ApiException {
  const ApiTimeoutException(super.message);
}

class InvalidResponseException extends ApiException {
  const InvalidResponseException(super.message);
}

sealed class ApiErrorException extends ApiException {
  const ApiErrorException({required this.statusCode, required this.code, required String message})
    : super(message);

  final int statusCode;

  final String code;
}

/// Validation may fail without identifying individual fields.
class ValidationException extends ApiErrorException {
  const ValidationException({required super.message, this.fields = const {}})
    : super(statusCode: 400, code: 'VALIDATION_ERROR');

  final Map<String, String> fields;
}

class UnauthorizedException extends ApiErrorException {
  const UnauthorizedException({required super.message})
    : super(statusCode: 401, code: 'UNAUTHORIZED');
}

/// The session is valid, but a sensitive action requires a recent sign-in.
class ReauthenticationRequiredException extends ApiErrorException {
  const ReauthenticationRequiredException({required super.message})
    : super(statusCode: 401, code: 'REAUTHENTICATION_REQUIRED');
}

class NotFoundException extends ApiErrorException {
  const NotFoundException({required super.message}) : super(statusCode: 404, code: 'NOT_FOUND');
}

/// Another device may have completed onboarding concurrently.
class OnboardingAlreadyCompletedException extends ApiErrorException {
  const OnboardingAlreadyCompletedException({required super.message})
    : super(statusCode: 409, code: 'ONBOARDING_ALREADY_COMPLETED');
}

/// A daily limit never disables access to help.
class DailyLimitReachedException extends ApiErrorException {
  const DailyLimitReachedException({required super.message, required this.resetsAt})
    : super(statusCode: 429, code: 'DAILY_LIMIT_REACHED');

  final DateTime resetsAt;
}

class RateLimitedException extends ApiErrorException {
  const RateLimitedException({required super.message, required this.retryAfter})
    : super(statusCode: 429, code: 'RATE_LIMITED');

  final Duration retryAfter;
}

/// Keep the unsent text so the user can retry the turn.
class LlmUnavailableException extends ApiErrorException {
  const LlmUnavailableException({required super.message, this.retryAfter})
    : super(statusCode: 503, code: 'LLM_UNAVAILABLE');

  final Duration? retryAfter;
}

class UnexpectedApiException extends ApiErrorException {
  const UnexpectedApiException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}
