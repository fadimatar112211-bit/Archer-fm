import 'monster_progression.dart';

/// Durable storage contract for permanent monster progression.
///
/// Implementations may target local files during development or a transactional
/// cloud database in production. The account ID must always come from a
/// server-verified authentication context, never directly from a client field.
abstract interface class MonsterProgressStore {
  Future<Map<String, Object?>> loadData(String trustedAccountId);
  Future<void> save(
    String trustedAccountId,
    MonsterProgression progression,
  );
}
