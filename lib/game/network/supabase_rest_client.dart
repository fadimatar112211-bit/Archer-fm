import 'dart:convert';
import 'dart:io';

/// Minimal server-only Supabase PostgREST client.
///
/// Construct this only in trusted server code with SUPABASE_SERVICE_ROLE_KEY.
/// Never import this class from Flutter UI or ship its key in the app.
class SupabaseRestClient {
  SupabaseRestClient({
    required String supabaseUrl,
    required this.serviceRoleKey,
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 8),
  })  : baseUri = _validateBaseUrl(supabaseUrl),
        _httpClient = httpClient ?? HttpClient();

  final Uri baseUri;
  final String serviceRoleKey;
  final HttpClient _httpClient;
  final Duration timeout;

  static Uri _validateBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(value, 'supabaseUrl', 'A valid HTTPS URL is required.');
    }
    return uri;
  }

  Future<Map<String, dynamic>?> loadProgressionRow({
    required String table,
    required String trustedAccountId,
  }) async {
    if (table != 'hero_progress' && table != 'monster_progress') {
      throw ArgumentError.value(table, 'table');
    }
    if (!_isUuid(trustedAccountId)) {
      throw ArgumentError.value(trustedAccountId, 'trustedAccountId');
    }
    final uri = baseUri.replace(
      path: '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/rest/v1/$table',
      queryParameters: {
        'user_id': 'eq.${trustedAccountId.toLowerCase()}',
        'select': 'data,revision',
        'limit': '1',
      },
    );
    final decoded = await _request('GET', uri);
    if (decoded is! List || decoded.isEmpty) return null;
    final row = decoded.first;
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid progression row from Supabase.');
    }
    return row;
  }

  Future<int> saveProgression({
    required String rpc,
    required String trustedAccountId,
    required Map<String, Object?> data,
    required int expectedRevision,
  }) async {
    if (rpc != 'save_hero_progress' && rpc != 'save_monster_progress') {
      throw ArgumentError.value(rpc, 'rpc');
    }
    if (!_isUuid(trustedAccountId) || expectedRevision < 0) {
      throw ArgumentError('Invalid account ID or progression revision.');
    }
    final decoded = await _request(
      'POST',
      baseUri.replace(
        path: '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/rest/v1/rpc/$rpc',
      ),
      body: {
        'p_user_id': trustedAccountId.toLowerCase(),
        'p_data': data,
        'p_expected_revision': expectedRevision,
      },
    );
    if (decoded is int) return decoded;
    if (decoded is num && decoded == decoded.toInt()) return decoded.toInt();
    throw const FormatException('Supabase did not return a progression revision.');
  }


  /// Atomically records a match result and applies its server-calculated reward.
  /// The account UUID must come from the verified access-token subject.
  Future<Map<String, dynamic>> finalizeMatchPlayerResult({
    required String matchId,
    required String trustedAccountId,
    required int placement,
    required int score,
    required int crystalsRemaining,
    required String finishReason,
    required int rewardAmount,
    required String idempotencyKey,
  }) async {
    if (!_isUuid(trustedAccountId) ||
        matchId.isEmpty || matchId.length > 128 ||
        placement < 1 || placement > 4 ||
        score < 0 ||
        crystalsRemaining < 0 || crystalsRemaining > 7 ||
        finishReason.isEmpty || finishReason.length > 48 ||
        rewardAmount < 0 ||
        idempotencyKey.isEmpty || idempotencyKey.length > 128) {
      throw ArgumentError('Invalid match settlement input.');
    }
    final decoded = await _request(
      'POST',
      baseUri.replace(
        path: '${baseUri.path.replaceFirst(RegExp(r'/+
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final request = await _httpClient.openUrl(method, uri).timeout(timeout);
    request.headers
      ..set('apikey', serviceRoleKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $serviceRoleKey')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Keep credentials out of exception messages and logs.
      throw HttpException(
        'Supabase request failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    if (responseBody.isEmpty) return null;
    return jsonDecode(responseBody);
  }

  bool _isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  void close() => _httpClient.close(force: true);
}
), '')}/rest/v1/rpc/finalize_match_player_result',
      ),
      body: {
        'p_match_id': matchId,
        'p_user_id': trustedAccountId.toLowerCase(),
        'p_placement': placement,
        'p_score': score,
        'p_crystals_remaining': crystalsRemaining,
        'p_finish_reason': finishReason,
        'p_reward_amount': rewardAmount,
        'p_idempotency_key': idempotencyKey,
      },
    );
    if (decoded is List && decoded.length == 1 && decoded.single is Map) {
      return Map<String, dynamic>.from(decoded.single as Map);
    }
    throw const FormatException('Supabase did not return one match settlement.');
  }

  Future<dynamic> _request(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final request = await _httpClient.openUrl(method, uri).timeout(timeout);
    request.headers
      ..set('apikey', serviceRoleKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $serviceRoleKey')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Keep credentials out of exception messages and logs.
      throw HttpException(
        'Supabase request failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    if (responseBody.isEmpty) return null;
    return jsonDecode(responseBody);
  }

  bool _isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  void close() => _httpClient.close(force: true);
}
