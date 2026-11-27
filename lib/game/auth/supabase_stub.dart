/// Stub for supabase_flutter when package resolution is unavailable offline.
/// Replace imports with package:supabase_flutter/supabase_flutter.dart when deps resolve.
import 'dart:async';

class Supabase {
  Supabase._();
  static final Supabase instance = Supabase._();
  SupabaseClient client = SupabaseClient();
  static Future<Supabase> initialize({required String url, required String anonKey, String? publishableKey, dynamic authOptions, dynamic postgrestOptions, dynamic realtimeClientOptions, dynamic storageOptions}) async {
    instance.client = SupabaseClient();
    return instance;
  }
}

class SupabaseClient {
  final GoTrueClient auth = GoTrueClient();
  SupabaseQueryBuilder from(String table) => SupabaseQueryBuilder();
  SupabaseStorageClient get storage => SupabaseStorageClient();
  RealtimeClient get realtime => RealtimeClient();
  FunctionsClient get functions => FunctionsClient();
  PostgrestClient rest = PostgrestClient();
  Future<dynamic> rpc(String fn, {Map<dynamic, dynamic>? params}) async => null;
}

class SupabaseQueryBuilder {
  SupabaseQueryBuilder select([String columns = '*']) => this;
  SupabaseQueryBuilder insert(dynamic values) => this;
  SupabaseQueryBuilder upsert(dynamic values, {String? onConflict, bool? ignoreDuplicates}) => this;
  SupabaseQueryBuilder update(Map<dynamic, dynamic> values) => this;
  SupabaseQueryBuilder delete() => this;
  SupabaseQueryBuilder eq(String column, dynamic value) => this;
  SupabaseQueryBuilder neq(String column, dynamic value) => this;
  SupabaseQueryBuilder inFilter(String column, List values) => this;
  SupabaseQueryBuilder order(String column, {bool ascending = false}) => this;
  SupabaseQueryBuilder limit(int count) => this;
  SupabaseQueryBuilder maybeSingle() => this;
  SupabaseQueryBuilder single() => this;
  Future<dynamic> then(dynamic Function(dynamic) onValue, {Function? onError}) async => onValue(null);
}

class GoTrueClient {
  User? get currentUser => null;
  Session? get currentSession => null;
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  Future<AuthResponse> signUp({required String email, required String password, dynamic data}) async => AuthResponse();
  Future<AuthResponse> signInWithPassword({required String email, required String password}) async => AuthResponse();
  Future<void> signOut() async {}
  Future<AuthResponse> refreshSession() async => AuthResponse();
  Future<UserResponse> updateUser(UserAttributes attributes) async => UserResponse();
}

class User { final String id; final String? email; User({this.id = '', this.email}); }
class Session { final String accessToken; final User? user; final int? expiresAt; Session({this.accessToken = '', this.user, this.expiresAt}); }
class AuthState { final AuthChangeEvent event; final Session? session; AuthState(this.event, this.session); }
enum AuthChangeEvent { signedIn, signedOut, tokenRefreshed, userUpdated, passwordRecovery }
class AuthResponse { final User? user; final Session? session; AuthResponse({this.user, this.session}); }
class UserResponse { final User? user; UserResponse({this.user}); }
class UserAttributes { final String? email; final String? password; final Map<String, dynamic>? data; UserAttributes({this.email, this.password, this.data}); }
class SupabaseStorageClient {}
class RealtimeClient {}
class FunctionsClient {}
class PostgrestClient {}
