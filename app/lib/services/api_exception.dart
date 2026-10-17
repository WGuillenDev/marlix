/// Everything [MarlixApi] can fail with. Screens switch on the type to decide
/// what to show; [message] is for logs, never for the user.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// No connection, DNS failure or the connection dropped.
class NetworkException extends ApiException {
  const NetworkException(super.message);
}

/// The backend did not answer in time. The free Render plan can take up to a
/// minute to wake up.
class ApiTimeoutException extends ApiException {
  const ApiTimeoutException(super.message);
}

/// The response does not match the API contract.
class InvalidResponseException extends ApiException {
  const InvalidResponseException(super.message);
}

/// The backend answered with the contract's error body.
sealed class ApiErrorException extends ApiException {
  const ApiErrorException({required this.statusCode, required this.code, required String message})
    : super(message);

  final int statusCode;

  /// The contract's stable `error.code`.
  final String code;
}

/// `400 VALIDATION_ERROR`. [fields] maps each invalid field to its problem;
/// it is empty when the body as a whole was rejected.
class ValidationException extends ApiErrorException {
  const ValidationException({required super.message, this.fields = const {}})
    : super(statusCode: 400, code: 'VALIDATION_ERROR');

  final Map<String, String> fields;
}

/// `401 UNAUTHORIZED`: missing, invalid or expired token.
class UnauthorizedException extends ApiErrorException {
  const UnauthorizedException({required super.message})
    : super(statusCode: 401, code: 'UNAUTHORIZED');
}

/// `404 NOT_FOUND`: the memory or message does not exist, or is not the person's.
class NotFoundException extends ApiErrorException {
  const NotFoundException({required super.message}) : super(statusCode: 404, code: 'NOT_FOUND');
}

/// `429 DAILY_LIMIT_REACHED`. The help screen stays available.
class DailyLimitReachedException extends ApiErrorException {
  const DailyLimitReachedException({required super.message, required this.resetsAt})
    : super(statusCode: 429, code: 'DAILY_LIMIT_REACHED');

  /// The next midnight in Costa Rica, in UTC.
  final DateTime resetsAt;
}

/// `429 RATE_LIMITED`: too many messages in a short time.
class RateLimitedException extends ApiErrorException {
  const RateLimitedException({required super.message, required this.retryAfter})
    : super(statusCode: 429, code: 'RATE_LIMITED');

  final Duration retryAfter;
}

/// `503 LLM_UNAVAILABLE`: the model failed. Nothing was saved or counted, so
/// the app keeps the text and offers a retry.
class LlmUnavailableException extends ApiErrorException {
  const LlmUnavailableException({required super.message, this.retryAfter})
    : super(statusCode: 503, code: 'LLM_UNAVAILABLE');

  final Duration? retryAfter;
}

/// Any other error code: `INTERNAL_ERROR` or one added to the
/// contract after this build.
class UnexpectedApiException extends ApiErrorException {
  const UnexpectedApiException({
    required super.statusCode,
    required super.code,
    required super.message,
  });
}
