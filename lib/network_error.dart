import 'dart:io';

/// Whether [error] (as caught from an http call) indicates the device is
/// offline, rather than some other failure (bad response, parsing error).
/// A SocketException from dart:io covers most cases directly, but the
/// package:http client sometimes wraps it in a ClientException whose
/// message still carries the underlying "Failed host lookup" text - check
/// for both instead of just the exception type.
bool isOffline(Object error) {
  return error is SocketException ||
      error.toString().contains('Failed host lookup');
}
