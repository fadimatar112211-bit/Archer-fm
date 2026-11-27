import 'hero_progress.dart';
import 'hero_progress_store.dart';
import '../network/supabase_rest_client.dart';

/// Cloud implementation of [HeroProgressStore].
///
/// The server-only service-role client must never be constructed in Flutter.
/// A revision conflict is surfaced to the caller rather than overwriting a
/// newer save from another server instance.
class SupabaseHeroProgressStore implements HeroProgressStore {
  SupabaseHeroProgressStore(this.client);

  final SupabaseRestClient client;
  final Map<String, int> _revisions = {};

  /// Drop a cached revision after another atomic server RPC changes the row.
  void invalidateRevision(String trustedAccountId) {
    _revisions.remove(trustedAccountId);
  }

  @override
  Future<HeroProgress> load(String trustedAccountId) async {
    final row = await client.loadProgressionRow(
      table: 'hero_progress',
      trustedAccountId: trustedAccountId,
    );
    if (row == null) {
      _revisions[trustedAccountId] = 0;
      return HeroProgress.fresh();
    }
    final revision = row['revision'];
    final data = row['data'];
    if (revision is! num || data is! Map<String, dynamic>) {
      throw const FormatException('Invalid cloud hero progression record.');
    }
    _revisions[trustedAccountId] = revision.toInt();
    return HeroProgress.fromJson(data);
  }

  @override
  Future<void> save(String trustedAccountId, HeroProgress progress) async {
    final expectedRevision = _revisions[trustedAccountId] ??
        await _readRevision(trustedAccountId);
    final nextRevision = await client.saveProgression(
      rpc: 'save_hero_progress',
      trustedAccountId: trustedAccountId,
      data: progress.toJson(),
      expectedRevision: expectedRevision,
    );
    _revisions[trustedAccountId] = nextRevision;
  }

  Future<int> _readRevision(String trustedAccountId) async {
    final row = await client.loadProgressionRow(
      table: 'hero_progress',
      trustedAccountId: trustedAccountId,
    );
    if (row == null) return 0;
    final revision = row['revision'];
    if (revision is! num) {
      throw const FormatException('Invalid cloud hero progression revision.');
    }
    return revision.toInt();
  }
}
