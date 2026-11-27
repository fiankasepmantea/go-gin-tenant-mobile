/// One field problem from a `validation_failed` answer.
class FieldDetail {
  const FieldDetail(this.field, this.rule);

  final String field;
  final String rule;
}

/// Every failed call surfaces as this exception, so screens deal with one type. `code` is the stable machine
/// readable code of the API (see docs/http-api.md in the backend); the message text is never used for decisions.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.details = const <FieldDetail>[],
    this.requestId,
    this.retryAfter,
  });

  /// The server cannot be reached (no connection, DNS, refused).
  const ApiException.network()
      : this(status: 0, code: networkCode, message: 'The server cannot be reached.');

  /// The server did not answer in time.
  const ApiException.timeout()
      : this(status: 0, code: timeoutCode, message: 'The server did not answer in time.');

  /// The body of an answer was not what this app expects.
  const ApiException.unexpected()
      : this(status: 500, code: 'internal_error', message: 'Unexpected answer from the server.');

  static const String networkCode = 'network_error';
  static const String timeoutCode = 'timeout';

  final int status;
  final String code;
  final String message;
  final List<FieldDetail> details;
  final String? requestId;

  /// Seconds from the `Retry-After` header of a 429.
  final int? retryAfter;

  bool get isNetwork => code == networkCode || code == timeoutCode;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status $code: $message)';
}
