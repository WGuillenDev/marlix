import '../../application/api_exception.dart';
import '../../json_reader.dart';

ApiErrorException decodeApiError(
  Map<String, Object?> json, {
  required int statusCode,
  Duration? retryAfter,
}) {
  try {
    final error = json.requireObject('error');
    final code = error.requireString('code');
    final message = error.requireString('message');
    final details = error['details'] is Map<String, Object?>
        ? error['details']! as Map<String, Object?>
        : const <String, Object?>{};
    return switch (code) {
      'VALIDATION_ERROR' => ValidationException(message: message, fields: _fields(details)),
      'UNAUTHORIZED' => UnauthorizedException(message: message),
      'REAUTHENTICATION_REQUIRED' => ReauthenticationRequiredException(message: message),
      'NOT_FOUND' => NotFoundException(message: message),
      'ONBOARDING_ALREADY_COMPLETED' => OnboardingAlreadyCompletedException(message: message),
      'DAILY_LIMIT_REACHED' => DailyLimitReachedException(
        message: message,
        resetsAt: details.requireDateTime('resetsAt'),
      ),
      'RATE_LIMITED' => RateLimitedException(
        message: message,
        retryAfter: retryAfter ?? const Duration(seconds: 60),
      ),
      'LLM_UNAVAILABLE' => LlmUnavailableException(message: message, retryAfter: retryAfter),
      _ => UnexpectedApiException(statusCode: statusCode, code: code, message: message),
    };
  } on InvalidJsonException catch (error) {
    throw InvalidResponseException('Error $statusCode with an invalid body: $error');
  }
}

Map<String, String> _fields(Map<String, Object?> details) {
  final fields = details['fields'];
  if (fields is! List<Object?>) return const {};
  return {
    for (final field in fields.whereType<Map<String, Object?>>())
      if (field['field'] case final String name) name: field['message'] as String? ?? '',
  };
}
