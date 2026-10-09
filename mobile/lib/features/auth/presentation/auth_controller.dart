import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Current session: `null` = signed out. Loading while restoring on startup.
final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<User?> {
  TokenStorage get _storage => ref.read(tokenStorageProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Restores the session from a saved token.
  @override
  Future<User?> build() async {
    ref.listen(sessionExpiredProvider, (_, _) => logout());

    final token = await _storage.read();
    if (token == null) return null;
    try {
      return await _repo.me();
    } on ApiException catch (e) {
      // Expired/invalid token → signed out. Network errors keep the token.
      if (e.statusCode == 401) await _storage.clear();
      return null;
    }
  }

  /// Throws [ApiException] on failure so the form can show the message.
  Future<void> login(String email, String password) async {
    final (token, user) = await _repo.login(email, password);
    await _storage.write(token);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AsyncData(null);
  }
}
