import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Shadow attack clips expose three distinct Twin Fangs hit frames', () {
    final source = File(
      'assets/heroes/shadow/renders/shadow_manifest.json',
    );
    expect(source.existsSync(), isTrue);

    final manifest = HeroManifest.fromJson(
      jsonDecode(source.readAsStringSync()) as Map<String, dynamic>,
    );
    expect(manifest.heroId, 'shadow');

    for (final direction in ['e', 'ne', 'n', 'nw', 'w', 'sw', 's', 'se']) {
      final clip = manifest.clipFor('attack', direction);
      expect(clip, isNotNull, reason: 'missing attack_$direction');

      final events = clip!.events;
      final first = events.where((event) => event.name == 'melee_impact');
      final second = events.where((event) => event.name == 'twin_fangs_hit_2');
      final third = events.where((event) => event.name == 'twin_fangs_hit_3');

      expect(first, hasLength(1), reason: 'attack_$direction');
      expect(second, hasLength(1), reason: 'attack_$direction');
      expect(third, hasLength(1), reason: 'attack_$direction');
      expect(first.single.frame, lessThan(second.single.frame));
      expect(second.single.frame, lessThan(third.single.frame));
      expect(third.single.frame, lessThan(clip.frames.length));
    }
  });
}
