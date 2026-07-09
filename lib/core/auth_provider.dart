import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Raw Supabase auth state stream ─────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// ── Current User (null = guest) ─────────────────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// ── Profile data (display_name, avatar_url, role) ──────────────────────────
class UserProfile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'user' | 'admin'

  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: (map['display_name'] as String?) ?? 'User',
      avatarUrl: map['avatar_url'] as String?,
      role: (map['role'] as String?) ?? 'user',
    );
  }
}

// ── UserProfile async provider — re-fetches on auth changes ────────────────
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Re-run whenever auth state changes
  ref.watch(authStateProvider);

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  } catch (_) {
    return null;
  }
});

// ── Convenience bool: is the current user an admin? ────────────────────────
final isAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile.valueOrNull?.isAdmin ?? false;
});

// ── Auth service — sign-in / sign-up / sign-out helpers ─────────────────────
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AuthResponse> signUpWithEmail(String email, String password, {String? displayName}) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'full_name': displayName} : null,
    );
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle({String? redirectTo}) async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> updateDisplayName(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').update({'display_name': name}).eq('id', user.id);
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
