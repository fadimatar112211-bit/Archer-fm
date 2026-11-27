import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'supabase_account_service.dart';

/// Mobile client for the authenticated game-server purchase route.
/// It sends only catalog IDs and an idempotency key; prices, account IDs and
/// progression revisions are owned by the server.
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
  static final Map<String, String> _pendingIdempotencyKeys = {};

  Future<ProgressionPurchaseCatalog> loadCatalog() async {
    final token = await _accessToken();
    final base = _baseUri();
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/v1/account/progression/catalog',
    );
    final request = await _httpClient.getUrl(uri);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join()
        .timeout(const Duration(seconds: 12));
    final decoded = _decodeResponse(body);
    if (response.statusCode != HttpStatus.ok) {
      throw ProgressionPurchaseException(_errorCode(decoded, 'catalog_failed'));
    }
    return ProgressionPurchaseCatalog.fromJson(decoded);
  }

  Future<ProgressionPurchaseReceipt> purchase({
    required String purchaseType,
    required String targetId,
    required int quotedCost,
  }) async {
    if (!const {'weapon_unlock', 'weapon_upgrade', 'monster_upgrade'}
        .contains(purchaseType) ||
        targetId.isEmpty || targetId.length > 96 || quotedCost <= 0) {
      throw ArgumentError('Invalid progression purchase.');
    }
    final token = await _accessToken();
    final base = _baseUri();
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/v1/account/progression/purchase',
    );
    final operationKey = '${accountService.currentUser?.id ?? 'signed-out'}:$purchaseType:$targetId';
    final idempotencyKey = _pendingIdempotencyKeys.putIfAbsent(
      operationKey,
      _newIdempotencyKey,
    );
    final request = await _httpClient.postUrl(uri);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..contentType = ContentType.json;
    request.write(jsonEncode({
      'purchaseType': purchaseType,
      'targetId': targetId,
      'idempotencyKey': idempotencyKey,
      'quotedCost': quotedCost,
    }));
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join()
        .timeout(const Duration(seconds: 12));
    final decoded = _decodeResponse(body);
    if (response.statusCode != HttpStatus.ok) {
      final code = _errorCode(decoded, 'purchase_failed');
      if (code == 'idempotency_conflict') {
        _pendingIdempotencyKeys.remove(operationKey);
      }
      throw ProgressionPurchaseException(code);
    }
    final receipt = ProgressionPurchaseReceipt.fromJson(decoded);
    _pendingIdempotencyKeys.remove(operationKey);
    return receipt;
  }

  Future<String> _accessToken() async {
    final token = await accountService.accessToken();
    if (token == null || token.isEmpty) {
      throw const ProgressionPurchaseException('unauthorized');
    }
    return token;
  }

  Uri _baseUri() {
    final base = Uri.tryParse(_apiUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) {
      throw const ProgressionPurchaseException('purchase_service_not_configured');
    }
    return base;
  }

  Map<String, dynamic> _decodeResponse(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      // Converted below to a stable client-facing error code.
    }
    throw const ProgressionPurchaseException('invalid_server_response');
  }

  String _errorCode(Map<String, dynamic> json, String fallback) {
    final error = json['error'];
    return error is String && error.length <= 64 ? error : fallback;
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

class ProgressionPurchaseCatalog {
  const ProgressionPurchaseCatalog({
    required this.weapons,
    required this.monsters,
  });

  final List<Map<String, dynamic>> weapons;
  final List<Map<String, dynamic>> monsters;

  factory ProgressionPurchaseCatalog.fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'progression_catalog' ||
        json['weapons'] is! List || json['monsters'] is! List) {
      throw const FormatException('Invalid progression catalog.');
    }
    List<Map<String, dynamic>> rows(Object? value) =>
        (value as List).map((item) {
          if (item is! Map) throw const FormatException('Invalid catalog item.');
          return Map<String, dynamic>.from(item);
        }).toList(growable: false);
    return ProgressionPurchaseCatalog(
      weapons: rows(json['weapons']),
      monsters: rows(json['monsters']),
    );
  }
}

class ProgressionPurchaseException implements Exception {
  const ProgressionPurchaseException(this.code);
  final String code;
  @override
  String toString() => code;
}
