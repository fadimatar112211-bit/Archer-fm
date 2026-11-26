import 'package:archer_fm/game/match/match_target_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects the closest enemy among heroes, monsters and crystals', () {
    final snapshot = <String, dynamic>{
      'combat': {
        'heroes': {
          'p1': {'isAlive': true},
          'p2': {'isAlive': true},
        },
        'monsters': [
          {'id': 'monster-near', 'ownerId': 'p3', 'x': 3, 'y': 0},
          {'id': 'monster-far', 'ownerId': 'p4', 'x': 20, 'y': 0},
        ],
      },
      'world': {
        'playerPositions': {
          'p1': {'x': 0, 'y': 0},
          'p2': {'x': 8, 'y': 0},
        },
        'castles': [
          {
            'ownerId': 'p4',
            'crystals': [
              {'id': 'crystal-near', 'x': 2, 'y': 0, 'hp': 100},
            ],
          },
        ],
      },
    };

    expect(
      MatchTargetSelector.nearestEnemyTarget(
        snapshot: snapshot,
        playerId: 'p1',
      ),
      'crystal-near',
    );
  });

  test('ignores own entities, defeated heroes and destroyed crystals', () {
    final snapshot = <String, dynamic>{
      'combat': {
        'heroes': {
          'p1': {'isAlive': true},
          'p2': {'isAlive': false},
        },
        'monsters': [
          {'id': 'own-monster', 'ownerId': 'p1', 'x': 1, 'y': 0},
          {'id': 'enemy-monster', 'ownerId': 'p2', 'x': 4, 'y': 0},
        ],
      },
      'world': {
        'playerPositions': {
          'p1': {'x': 0, 'y': 0},
          'p2': {'x': 2, 'y': 0},
        },
        'castles': [
          {
            'ownerId': 'p2',
            'crystals': [
              {'id': 'destroyed', 'x': 1, 'y': 0, 'hp': 0},
            ],
          },
        ],
      },
    };

    expect(
      MatchTargetSelector.nearestEnemyTarget(
        snapshot: snapshot,
        playerId: 'p1',
      ),
      'enemy-monster',
    );
  });

  test('returns null when own authoritative position is unavailable', () {
    expect(
      MatchTargetSelector.nearestEnemyTarget(
        snapshot: {
          'combat': {'monsters': []},
          'world': {'playerPositions': {}},
        },
        playerId: 'p1',
      ),
      isNull,
    );
  });

  test('orders valid enemy targets by distance for manual cycling', () {
    final snapshot = <String, dynamic>{
      'combat': {
        'heroes': {
          'p1': {'isAlive': true},
          'p2': {'isAlive': true},
        },
        'monsters': [
          {'id': 'monster-far', 'ownerId': 'p3', 'x': 9, 'y': 0},
          {'id': 'monster-near', 'ownerId': 'p3', 'x': 3, 'y': 0},
        ],
      },
      'world': {
        'playerPositions': {
          'p1': {'x': 0, 'y': 0},
          'p2': {'x': 7, 'y': 0},
        },
        'castles': [
          {
            'ownerId': 'p4',
            'crystals': [
              {'id': 'crystal-middle', 'x': 5, 'y': 0, 'hp': 20},
              {'id': 'crystal-dead', 'x': 1, 'y': 0, 'hp': 0},
            ],
          },
        ],
      },
    };

    expect(
      MatchTargetSelector.enemyTargets(snapshot: snapshot, playerId: 'p1'),
      ['monster-near', 'crystal-middle', 'hero_p2', 'monster-far'],
    );
  });

}
