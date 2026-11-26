import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void _validateGltfMaterials(
  Map<String, dynamic> document,
  String assetPath,
) {
  final materials = document['materials'] as List? ?? const [];
  expect(materials, isNotEmpty, reason: '$assetPath has no material definitions');

  final meshes = document['meshes'] as List? ?? const [];
  for (final mesh in meshes) {
    final primitives = (mesh as Map)['primitives'] as List? ?? const [];
    for (final primitive in primitives) {
      final materialIndex = (primitive as Map)['material'] as int?;
      if (materialIndex != null) {
        expect(materialIndex, inInclusiveRange(0, materials.length - 1),
            reason: '$assetPath references a missing material');
      }
    }
  }

  final textures = document['textures'] as List? ?? const [];
  final images = document['images'] as List? ?? const [];
  final bufferViews = document['bufferViews'] as List? ?? const [];
  for (final texture in textures) {
    final source = (texture as Map)['source'] as int?;
    if (source != null) {
      expect(source, inInclusiveRange(0, images.length - 1),
          reason: '$assetPath references a missing texture image');
    }
  }

  for (final image in images) {
    final data = image as Map;
    final uri = data['uri'];
    final bufferView = data['bufferView'];
    expect(uri != null || bufferView != null, isTrue,
        reason: '$assetPath has an image with no data source');
    if (uri is String && !uri.startsWith('data:')) {
      expect(File('${File(assetPath).parent.path}/$uri').existsSync(), isTrue,
          reason: '$assetPath is missing external texture $uri');
    }
    if (bufferView is int) {
      expect(bufferView, inInclusiveRange(0, bufferViews.length - 1),
          reason: '$assetPath references a missing embedded image bufferView');
    }
  }
}

void main() {
  const ids = ['bog-monster', 'werewolf', 'stone-golem', 'blind-stalker'];
  const requiredAnims = ['Idle', 'Walk', 'Run', 'Attack', 'Roar', 'Hit', 'Die'];

  test('monster GLBs contain valid materials, rigs and required animations', () {
    for (final id in ids) {
      final path = 'assets/monsters/$id/$id.glb';
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path missing');
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(100000), reason: '$path is suspiciously small');
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'glTF');
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      expect(data.getUint32(4, Endian.little), 2, reason: '$path is not glTF 2.0');
      expect(data.getUint32(8, Endian.little), bytes.length,
          reason: '$path header length mismatch');
      final chunkLength = data.getUint32(12, Endian.little);
      expect(data.getUint32(16, Endian.little), 0x4E4F534A);
      expect(20 + chunkLength, lessThanOrEqualTo(bytes.length));
      final document = jsonDecode(
        utf8.decode(bytes.sublist(20, 20 + chunkLength)),
      ) as Map<String, dynamic>;

      final animations = document['animations'] as List? ?? const [];
      final names = animations.map((entry) => (entry as Map)['name']).toSet();
      for (final animation in requiredAnims) {
        expect(names.contains(animation), isTrue, reason: '$id missing animation $animation');
      }

      final skins = document['skins'] as List? ?? const [];
      expect(skins, isNotEmpty, reason: '$id has no skin');
      final joints = (skins.first as Map)['joints'] as List? ?? const [];
      expect(joints.length, greaterThan(10), reason: '$id skeleton too small');
      _validateGltfMaterials(document, path);
    }
  });

  test('monster bin files contain valid geometry and all seven runtime clips', () {
    for (final id in ids) {
      final path = 'assets/monsters/$id/$id.bin';
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path missing');
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(32), reason: '$path is empty');
      final headerLength = ByteData.sublistView(Uint8List.fromList(bytes))
          .getUint32(0, Endian.little);
      expect(4 + headerLength, lessThanOrEqualTo(bytes.length),
          reason: '$path header exceeds file length');
      final header = jsonDecode(
        utf8.decode(bytes.sublist(4, 4 + headerLength)),
      ) as Map<String, dynamic>;
      expect(header['n'], greaterThan(0));
      expect(header['t'], greaterThan(0));
      expect(header['bc'], greaterThan(10));
      final clips = (header['clips'] as Map<String, dynamic>).keys.toSet();
      for (final animation in requiredAnims) {
        expect(clips.contains(animation), isTrue,
            reason: '$id bin missing $animation');
      }
    }
  });
}
