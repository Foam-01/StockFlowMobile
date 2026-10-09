import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Default API URL when the user hasn't set one.
///
/// Override at build time with `--dart-define=API_URL=http://192.168.1.10:3000`,
/// or at runtime from the login screen (Server settings).
String get defaultApiBaseUrl {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  // The Android emulator reaches the host machine via 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}

/// Persists the server URL chosen on the login screen.
class ServerUrlStore {
  static const _key = 'api_base_url';
  static const _storage = FlutterSecureStorage();

  static Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null; // storage unavailable: fall back to the default
    }
  }

  static Future<void> write(String? url) => url == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: url);
}

/// URL saved on a previous run; loaded in main() before the app starts.
final savedServerUrlProvider = Provider<String?>((_) => null);

final serverUrlProvider = NotifierProvider<ServerUrl, String>(ServerUrl.new);

class ServerUrl extends Notifier<String> {
  @override
  String build() => ref.watch(savedServerUrlProvider) ?? defaultApiBaseUrl;

  bool get isCustom => state != defaultApiBaseUrl;

  Future<void> set(String url) async {
    final normalized = normalizeServerUrl(url);
    await ServerUrlStore.write(
      normalized == defaultApiBaseUrl ? null : normalized,
    );
    state = normalized;
  }

  Future<void> reset() async {
    await ServerUrlStore.write(null);
    state = defaultApiBaseUrl;
  }
}

/// Adds http:// when missing and drops trailing slashes.
String normalizeServerUrl(String input) {
  var url = input.trim();
  if (!url.contains('://')) url = 'http://$url';
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// Returns an error message, or null if [input] looks like a server URL.
String? validateServerUrl(String input) {
  if (input.trim().isEmpty) return 'Enter the server address';
  final uri = Uri.tryParse(normalizeServerUrl(input));
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return 'e.g. http://192.168.1.10:3000';
  }
  return null;
}
