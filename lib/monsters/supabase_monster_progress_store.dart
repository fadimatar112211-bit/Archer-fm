import 'monster_models.dart';
import 'monster_progression.dart';
import 'monster_progress_store.dart';
import '../game/network/supabase_rest_client.dart';

/// Cloud implementation of [MonsterProgressStore].
///
/// The service-role client is server-only. Optimistic revision conflicts are
/// returned as errors; the store never silently overwrites another server's
/// newer progression state.
class SupabaseMonsterProgressStore implements MonsterProgressStore {
  SupabaseMonsterProgressStore(this.client);

  final SupabaseRestClient client;
  final Map<String, int> _revisions = {};

  @override
  Future<Map<String, Object?>> loadData(String trustedAccountId) async {
    final row = await client.loadProgressionRow(
      table: 'monster_progress',
      trustedAccountId: trustedAccountId,
    );
    if (row == null) {
      _revisions[trustedAccountId] = 0;
      return {
        'version': MonsterProgression.saveSchemaVersion,
        'levels': {for (final type in MonsterType.values) type.name: 1},
      };
    }
    final revision = row['revision'];
    final data = row['data'];
    if (revision is! num || data is! Map) {
      throw const FormatException('Invalid cloud monster progression record.');
    }
    final decoded = <String, Object?>{};
    for (final entry in data.entries) {
      if (entry.key is! String) {
        throw const FormatException('Cloud monster progression keys must be strings.');
      }
      decoded[entry.key as String] = entry.value;
    }
    _revisions[trustedAccountId] = revision.toInt();
    return decoded;
  }

  @override
  Future<void> save(
    String trustedAccountId,
    MonsterProgression progression,
  ) async {
    final expectedRevision = _revisions[trustedAccountId] ??
        await _readRevision(trustedAccountId);
    final nextRevision = await client.saveProgression(
      rpc: 'save_monster_progress',
      trustedAccountId: trustedAccountId,
      data: progression.toSaveData(),
      expectedRevision: expectedRevision,
    );
    _revisions[trustedAccountId] = nextRevision;
  }

  Future<int> _readRevision(String trustedAccountId) async {
    final row = await client.loadProgressionRow(
      table: 'monster_progress',
      trustedAccountId: trustedAccountId,
    );
    if (row == null) return 0;
    final revision = row['revision'];
    if (revision is! num) {
      throw const FormatException('Invalid cloud monster progression revision.');
    }
    return revision.toInt();
  }
}
