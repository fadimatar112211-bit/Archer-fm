import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ids = ['bog-monster', 'werewolf', 'stone-golem', 'blind-stalker'];
  const requiredAnims = ['Idle','Walk','Run','Attack','Roar','Hit','Die'];

  test('monster GLB files exist and contain required animations', () {
    for (final id in ids) {
      final path = 'assets/monsters/$id/$id.glb';
      final f = File(path);
      expect(f.existsSync(), isTrue, reason: '$path missing');
      final b = f.readAsBytesSync();
      expect(String.fromCharCodes(b.sublist(0,4)), 'glTF');
      // parse JSON chunk
      final bd = ByteData.sublistView(Uint8List.fromList(b));
      final chunkLen = bd.getUint32(12, Endian.little);
      final chunkType = bd.getUint32(16, Endian.little);
      expect(chunkType, 0x4E4F534A);
      final jsonStr = utf8.decode(b.sublist(20, 20 + chunkLen));
      final j = jsonDecode(jsonStr) as Map<String, dynamic>;
      final anims = (j['animations'] as List).map((a) => a['name']).toSet();
      for (final a in requiredAnims) {
        expect(anims.contains(a), isTrue, reason: '$id missing anim $a');
      }
      // skeleton check
      final skins = j['skins'] as List;
      expect(skins, isNotEmpty, reason: '$id has no skin');
      final joints = (skins[0]['joints'] as List);
      expect(joints.length, greaterThan(10), reason: '$id skeleton too small');
    }
  });

  test('monster bin files exist and are loadable format', () {
    for (final id in ids) {
      final p = 'assets/monsters/$id/$id.bin';
      final b = File(p).readAsBytesSync();
      final hl = ByteData.sublistView(Uint8List.fromList(b)).getUint32(0, Endian.little);
      final head = jsonDecode(utf8.decode(b.sublist(4, 4+hl))) as Map<String, dynamic>;
      expect(head['n'], greaterThan(0));
      expect(head['t'], greaterThan(0));
      expect(head['bc'], greaterThan(10));
      final clips = (head['clips'] as Map<String, dynamic>).keys.toSet();
      for (final a in requiredAnims) {
        expect(clips.contains(a), isTrue, reason: '$id bin missing $a');
      }
    }
  });
}
