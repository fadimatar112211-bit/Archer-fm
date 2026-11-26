import 'dart:convert';
import 'dart:io';

/// Resolves a Supabase access token to its verified auth.users UUID.
///
/// Validation is delegated to Supabase Auth's authenticated-user endpoint;
/// this class never decodes an unverified JWT or trusts a client-supplied ID.
/// Use only from the trusted game server, with the project anon key stored in
/// server environment configuration (never the service-role key).
class SupabaseAccessTokenVerifier {
  SupabaseAccessTokenVerifier({
    required String supabaseUrl,
    required this.anonKey,
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 5),
  })  : endpoint = _userEndpoint(supabaseUrl),
        _httpClient = httpClient ?? HttpClient();

  final Uri endpoint;
  final String anonKey;
  final HttpClient _httpClient;
  final Duration timeout;

  static Uri _userEndpoint(String value) {
    final base = Uri.tryParse(value);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw ArgumentError.value(
        value,
        'supabaseUrl',
        'A valid HTTPS Supabase project URL is required.',
      );
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/auth/v1/user',
    );
  }

  /// Returns the verified Supabase user UUID, or null for an invalid token.
  Future<String?> verify(String accessToken) async {
    if (anonKey.trim().isEmpty ||
        accessToken.trim().isEmpty ||
        accessToken.length > 8192) {
      return null;
    }

    try {
      final request = await _httpClient.getUrl(endpoint).timeout(timeout);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set('apikey', anonKey)
        ..set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) return null;

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final id = decoded['id'];
      if (id is! String || !_isUuid(id)) return null;
      return id.toLowerCase();
    } on Object {
      return null;
    }
  }

  bool _isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);
}
