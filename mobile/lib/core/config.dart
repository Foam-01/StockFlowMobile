import 'package:flutter/foundation.dart';

/// Base URL of the NestJS API.
///
/// Override with `--dart-define=API_URL=http://192.168.1.10:3000` when running
/// on a real phone (use your PC's LAN IP).
String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  // The Android emulator reaches the host machine via 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}
