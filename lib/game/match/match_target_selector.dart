/// Chooses the closest visible enemy entity from an authoritative match snapshot.
///
/// The server remains responsible for range, ownership and damage validation;
/// this helper only chooses a target ID for the player's tap action.
class MatchTargetSelector {
  const MatchTargetSelector._();

  static String? nearestEnemyTarget({
    required Map<String, dynamic> snapshot,
    required String playerId,
  }) {
    final combat = snapshot['combat'];
    final world = snapshot['world'];
    if (combat is! Map || world is! Map) return null;
    final positions = world['playerPositions'];
    if (positions is! Map || positions[playerId] is! Map) return null;
    final ownPosition = positions[playerId] as Map;
    final originX = ownPosition['x'];
    final originY = ownPosition['y'];
    if (originX is! num || originY is! num) return null;

    String? nearestId;
    var nearestDistance = double.infinity;
    void consider(String id, String ownerId, Object? x, Object? y) {
      if (ownerId == playerId || x is! num || y is! num) return;
      final dx = x.toDouble() - originX.toDouble();
      final dy = y.toDouble() - originY.toDouble();
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = id;
      }
    }

    final heroes = combat['heroes'];
    if (heroes is Map) {
      for (final entry in heroes.entries) {
        if (entry.value is! Map) continue;
        final enemyId = entry.key.toString();
        final position = positions[enemyId];
        final hero = entry.value as Map;
        if (position is Map && hero['isAlive'] == true) {
          consider('hero_$enemyId', enemyId, position['x'], position['y']);
        }
      }
    }

    final monsters = combat['monsters'];
    if (monsters is List) {
      for (final monster in monsters) {
        if (monster is Map &&
            monster['id'] is String &&
            monster['ownerId'] is String) {
          consider(
            monster['id'] as String,
            monster['ownerId'] as String,
            monster['x'],
            monster['y'],
          );
        }
      }
    }

    final castles = world['castles'];
    if (castles is List) {
      for (final castle in castles) {
        if (castle is! Map || castle['ownerId'] is! String) continue;
        final ownerId = castle['ownerId'] as String;
        final crystals = castle['crystals'];
        if (crystals is! List) continue;
        for (final crystal in crystals) {
          if (crystal is Map &&
              crystal['id'] is String &&
              crystal['hp'] is num &&
              (crystal['hp'] as num) > 0) {
            consider(
              crystal['id'] as String,
              ownerId,
              crystal['x'],
              crystal['y'],
            );
          }
        }
      }
    }
    return nearestId;
  }
}
