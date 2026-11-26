import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const heroes = ['ranger', 'flame', 'shadow', 'storm'];
  const requiredStates = [
    'idle',
    'walk',
    'run',
    'attack',
    'skill',
    'dodge',
    'hit',
    'death',
  ];

  test('all four hero GLBs contain a skinned rig and eight distinct actions', () {
    for (final hero in heroes) {
      final path = 'assets/heroes/$hero/model/${hero}_animated.glb';
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(100000), reason: '$path is suspiciously small');
      expect(ascii.decode(bytes.sublist(0, 4)), 'glTF', reason: '$path is not GLB');
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      expect(data.getUint32(4, Endian.little), 2, reason: '$path is not glTF 2.0');
      expect(data.getUint32(8, Endian.little), bytes.length,
          reason: '$path header length mismatch');

      final jsonLength = data.getUint32(12, Endian.little);
      expect(data.getUint32(16, Endian.little), 0x4E4F534A,
          reason: '$path first chunk is not JSON');
      final document = jsonDecode(
        utf8.decode(bytes.sublist(20, 20 + jsonLength)),
      ) as Map<String, dynamic>;

      final meshes = document['meshes'] as List? ?? const [];
      final skins = document['skins'] as List? ?? const [];
      expect(meshes, isNotEmpty, reason: '$hero has no mesh');
      expect(skins, isNotEmpty, reason: '$hero has no armature skin');
      final joints = (skins.first as Map)['joints'] as List? ?? const [];
      expect(joints.length, greaterThanOrEqualTo(15),
          reason: '$hero rig has fewer than 15 joints');

      final animations = document['animations'] as List? ?? const [];
      final normalizedNames = animations
          .map((entry) => (entry as Map)['name']?.toString().toLowerCase() ?? '')
          .map((name) => name.replaceAll(RegExp(r'[^a-z]'), ''))
          .toList(growable: false);
      final matched = <String, String>{};
      for (final state in requiredStates) {
        final match = normalizedNames.where((name) => name.contains(state));
        expect(match, isNotEmpty, reason: '$hero is missing $state animation');
        matched[state] = match.first;
      }
      expect(matched.values.toSet(), hasLength(8),
          reason: '$hero animation states are not eight distinct clips: $matched');
    }
  });
}
