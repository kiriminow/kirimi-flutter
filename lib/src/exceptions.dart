/// Base exception for all Kirimi SDK errors.
class KirimiException implements Exception {
  final String message;

  const KirimiException(this.message);

  @override
  String toString() => 'KirimiException: $message';
}

/// Thrown when the API returns a non-2xx HTTP status code.
class KirimiApiException extends KirimiException {
  final int statusCode;
  final dynamic responseData;

  const KirimiApiException(
    this.statusCode,
    super.message, {
    this.responseData,
  });

  @override
  String toString() =>
      'KirimiApiException($statusCode): $message';
}

/// Thrown when a network-level error occurs (no response received).
class KirimiNetworkException extends KirimiException {
  final Object? cause;

  const KirimiNetworkException(super.message, {this.cause});

  @override
  String toString() => 'KirimiNetworkException: $message';
}
