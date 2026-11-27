import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'supabase_account_service.dart';

/// Mobile client for the authenticated game-server purchase route.
/// It sends only the requested catalog ID and an idempotency key; prices,
/// account IDs and progression revisions are server-owned.
class PlayerProgressionPurchaseClient {
  PlayerProgressionPurchaseClient({
    required this.accountService,
    String? apiUrl,
    HttpClient? httpClient,
  })  : _apiUrl = apiUrl ?? const String.fromEnvironment('ARCHER_FM_API_URL'),
        _httpClient = httpClient ?? HttpClient();

  final SupabaseAccountService accountService;
  final String _apiUrl;
  final HttpClient _httpClient;

  Future<ProgressionPurchaseReceipt> purchase({
    required String purchaseType,
    required String targetId,
  }) async {
    if (!const {'weapon_unlock', 'weapon_upgrade', 'monster_upgrade'}
        .contains(purchaseType) ||
        targetId.isEmpty || targetId.length > 96) {
      throw ArgumentError('Invalid progression purchase.');
    }
    final token = await accountService.accessToken();
    if (token == null || token.isEmpty) {
      throw const ProgressionPurchaseException('unauthorized');
    }
    final base = Uri.tryParse(_apiUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) {
      throw const ProgressionPurchaseException('purchase_service_not_configured');
    }
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/v1/account/progression/purchase',
    );
    final idempotencyKey = _newIdempotencyKey();
    final request = await _httpClient.postUrl(uri);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..contentType = ContentType.json;
    request.write(jsonEncode({
      'purchaseType': purchaseType,
      'targetId': targetId,
      'idempotencyKey': idempotencyKey,
    }));
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join()
        .timeout(const Duration(seconds: 12));
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      decoded = value;
    } on FormatException {
      throw const ProgressionPurchaseException('invalid_server_response');
    }
    if (response.statusCode != HttpStatus.ok) {
      final error = decoded['error'];
      throw ProgressionPurchaseException(
        error is String && error.length <= 64 ? error : 'purchase_failed',
      );
    }
    return ProgressionPurchaseReceipt.fromJson(decoded);
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(16))
        .map((value) => value.toRadixString(16)).join();
  }

  void close() => _httpClient.close(force: true);
}

class ProgressionPurchaseReceipt {
  const ProgressionPurchaseReceipt({
    required this.currencyBalance,
    required this.heroRevision,
    required this.monsterRevision,
    required this.resultingLevel,
    required this.alreadyApplied,
  });

  final int currencyBalance;
  final int heroRevision;
  final int monsterRevision;
  final int resultingLevel;
  final bool alreadyApplied;

  factory ProgressionPurchaseReceipt.fromJson(Map<String, dynamic> json) {
    int integer(String key) {
      final value = json[key];
      if (value is! num || value != value.toInt() || value < 0) {
        throw FormatException('Invalid purchase result field: $key.');
      }
      return value.toInt();
    }
    final alreadyApplied = json['already_applied'];
    if (json['type'] != 'purchase_result' || alreadyApplied is! bool) {
      throw const FormatException('Invalid progression purchase receipt.');
    }
    return ProgressionPurchaseReceipt(
      currencyBalance: integer('currency_balance'),
      heroRevision: integer('hero_revision'),
      monsterRevision: integer('monster_revision'),
      resultingLevel: integer('resulting_level'),
      alreadyApplied: alreadyApplied,
    );
  }
}

class ProgressionPurchaseException implements Exception {
  const ProgressionPurchaseException(this.code);
  final String code;
  @override
  String toString() => code;
}
