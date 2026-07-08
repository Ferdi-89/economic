import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/supabase_config.dart';
import '../models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(SupabaseConfig.client);
});

class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<User?> signInWithEmail(String email, String password) async {
    final res = await _client.auth.signInWithPassword(email: email, password: password);
    return res.user;
  }

  Future<User?> signUp(String email, String password, {String? fullName}) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
    return res.user;
  }

  Future<void> signOut() async => await _client.auth.signOut();

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<UserProfile?> getProfile(String userId) async {
    final res = await _client.from('profiles').select().eq('id', userId).single();
    return UserProfile.fromJson(res);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', userId);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'financier://login-callback',
    );
  }
}
