class TalkLynkException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  TalkLynkException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() {
    return 'TalkLynkException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}

class WebRTCException extends TalkLynkException {
  WebRTCException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class AuthenticationException extends TalkLynkException {
  AuthenticationException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class NetworkException extends TalkLynkException {
  NetworkException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}
