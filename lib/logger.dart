import 'package:flutter/foundation.dart';

/// Thin wrapper around debugPrint so every log call site is consistently
/// tagged and formatted, and a real logging/crash-reporting backend can be
/// swapped in later (one place to change) instead of touching every
/// scattered debugPrint call.
void log(String tag, String message, {Object? error}) {
  final suffix = error != null ? ' | $error' : '';
  debugPrint('[$tag] $message$suffix');
}
