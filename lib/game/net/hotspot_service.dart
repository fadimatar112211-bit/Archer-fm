import 'dart:io';

import '../social/account_service.dart';
import 'online_match_client.dart';
import 'online_match_server.dart';

/// Default LAN port used by a hosting phone. Only one hotspot match runs per
/// host, so a fixed port keeps joining simple (no discovery service exists).
const int hotspotPort = 40404;

/// A finished match kept on the device while there is no internet. The
/// specification asks for local results to be synchronized to the account once
/// connectivity returns; a real cloud backend is still an open decision.
class PendingMatchRecord {
  const PendingMatchRecord({
    required this.id,
    required this.username,
    required this.won,
    required this.kills,
    required this.score,
    required this.reason,
    required this.hotspot,
    required this.createdAtMs,
    this.synced = false,
  });

  final String id;
  final String username;
  final bool won;
  final int kills;
  final int score;
  final String reason;
  final bool hotspot;
  final int createdAtMs;
  final bool synced;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'won': won,
        'kills': kills,
        'score': score,
        'reason': reason,
        'hotspot': hotspot,
        'createdAtMs': createdAtMs,
        'synced': synced,
      };

  static PendingMatchRecord? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    final created = json['createdAtMs'];
    if (id is! String || username is! String || created is! int) return null;
    return PendingMatchRecord(
      id: id,
      username: username,
      won: json['won'] == true,
      kills: json['kills'] is int ? json['kills'] as int : 0,
      score: json['score'] is int ? json['score'] as int : 0,
      reason: json['reason'] is String ? json['reason'] as String : '',
      hotspot: json['hotspot'] == true,
      createdAtMs: created,
      synced: json['synced'] == true,
    );
  }
}

/// Local queue of match results. Uses the same storage contract as accounts so
/// tests can run without platform channels.
class PendingResultStore {
  PendingResultStore({SocialStore? store}) : _store = store ?? SharedPreferencesSocialStore();

  final SocialStore _store;
  static const _key = 'pending_results';

  Future<List<PendingMatchRecord>> all() async {
    final raw = await _store.read(_key);
    final items = raw?['items'];
    if (items is! List) return <PendingMatchRecord>[];
    final records = <PendingMatchRecord>[];
    for (final value in items) {
      if (value is! Map<String, dynamic>) continue;
      final record = PendingMatchRecord.fromJson(value);
      if (record != null) records.add(record);
    }
    return records;
  }

  Future<void> save(PendingMatchRecord record) async {
    final records = await all();
    records.removeWhere((item) => item.id == record.id);
    records.add(record);
    await _write(records);
  }

  Future<void> markSynced(String id) async {
    final records = await all();
    for (var i = 0; i < records.length; i++) {
      if (records[i].id == id) {
        records[i] = PendingMatchRecord(
          id: records[i].id,
          username: records[i].username,
          won: records[i].won,
          kills: records[i].kills,
          score: records[i].score,
          reason: records[i].reason,
          hotspot: records[i].hotspot,
          createdAtMs: records[i].createdAtMs,
          synced: true,
        );
      }
    }
    await _write(records);
  }

  Future<int> unsyncedCount() async =>
      (await all()).where((record) => !record.synced).length;

  /// Applies locally saved results to the signed-in account once internet
  /// access returns, then marks them synced. Cloud synchronization itself is
  /// left open in PROJECT_STATUS.md §5 because no backend is chosen yet.
  Future<int> syncToAccount(SocialService social) async {
    var applied = 0;
    for (final record in await all()) {
      if (record.synced || record.username != social.currentUsername) continue;
      await social.recordMatch(won: record.won, kills: record.kills);
      await markSynced(record.id);
      applied++;
    }
    return applied;
  }

  Future<void> _write(List<PendingMatchRecord> records) => _store.write(
        _key,
        {'items': [for (final record in records) record.toJson()]},
      );
}

/// Hosts a four-device hotspot match on the local network. The same
/// authoritative server powers online play; only binding and joining differ.
class HotspotService {
  HotspotService({this.port = hotspotPort, OnlineMatchServer? server})
      : server = server ?? OnlineMatchServer();

  final int port;
  final OnlineMatchServer server;

  bool get hosting => server.port > 0;

  Future<List<InternetAddress>> hostAddresses() async {
    final addresses = <InternetAddress>[];
    for (final interface in await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    )) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) addresses.add(address);
      }
    }
    return addresses;
  }

  Future<void> startHosting() => server.start(
        address: InternetAddress.anyIPv4,
        port: port,
      );

  Future<void> stopHosting() => server.close();

  Future<OnlineMatchClient> join({
    required String host,
    required String username,
    required String heroId,
    void Function(String type, Map<String, dynamic> data)? onEvent,
  }) =>
      OnlineMatchClient.connect(
        host: host,
        port: port,
        username: username,
        heroId: heroId,
        onEvent: onEvent,
      );
}
