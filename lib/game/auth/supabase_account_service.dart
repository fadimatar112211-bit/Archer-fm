import 'package:supabase_flutter/supabase_flutter.dart';

import 'player_account_data_service.dart';

/// Mobile account/session adapter for Supabase Auth.
///
/// The publishable key is safe for mobile distribution when Row Level Security
/// is enabled. Never put a Supabase secret/service-role key in this app.
class SupabaseAccountService {
  SupabaseAccountService._(this._client);

  final SupabaseClient _client;
  static SupabaseAccountService? _instance;

  static SupabaseAccountService? get instance => _instance;

  static Future<SupabaseAccountService?> initializeFromEnvironment() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || publishableKey.isEmpty) return null;
    return initialize(url: url, publishableKey: publishableKey);
  }

  static Future<SupabaseAccountService> initialize({
    required String url,
    required String publishableKey,
  }) async {
    if (url.trim().isEmpty || publishableKey.trim().isEmpty) {
      throw ArgumentError('Supabase URL and publishable key are required.');
    }
    final existing = _instance;
    if (existing != null) return existing;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    final service = SupabaseAccountService._(Supabase.instance.client);
    _instance = service;
    return service;
  }

  PlayerAccountDataService get playerData => PlayerAccountDataService(_client);

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// The game client calls this before every socket handshake and reconnect,
  /// allowing the Supabase SDK to refresh an expired access token first.
  Future<String?> accessToken() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    final expiresAt = session.expiresAt;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiresAt != null && expiresAt <= nowSeconds + 30) {
      final refreshed = await _client.auth.refreshSession();
      return refreshed.session?.accessToken;
    }
    return session.accessToken;
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _client.auth.signUp(email: email.trim(), password: password);

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

  Future<void> signOut() => _client.auth.signOut();
}
