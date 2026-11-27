import 'hero_progress.dart';

/// Durable storage contract for permanent hero progression.
///
/// Implementations may target local files during development or a transactional
/// cloud database in production. The account ID must always come from a
/// server-verified authentication context, never directly from a client field.
abstract interface class HeroProgressStore {
  Future<HeroProgress> load(String trustedAccountId);
  Future<void> save(String trustedAccountId, HeroProgress progress);
}
