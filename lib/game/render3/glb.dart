import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Minimal, dependency-free glTF/GLB loader + CPU skeletal poser for the
/// in-game 3D heroes.
///
/// One skinned mesh (positions/normals/UVs/joints/weights), its joint
/// hierarchy, inverse bind matrices, embedded base-colour texture and every
/// animation clip are decoded up front; poses are evaluated per frame in
/// [Poser.poseAt] and consumed by the hero 3D painter.
class GlbModel {
  GlbModel({
    required this.positions,
    required this.normals,
    required this.texCoords,
    required this.jointIndices,
    required this.weights,
    required this.indices,
    required this.indexUint16,
    required this.jointNames,
    required this.jointParents,
    required this.jointOrder,
    required this.inverseBinds,
    required this.restGlobal,
    required this.clips,
    required this.baseColor,
    required this.indexCount,
  });

  final int indexCount;

  final Float32List positions; // rest pose, 3 per vertex
  final Float32List normals; // rest pose, 3 per vertex
  final Float32List texCoords; // 2 per vertex
  final Uint8List jointIndices; // 4 per vertex
  final Float32List weights; // 4 per vertex
  final TypedData indices; // Uint16List or Uint32List
  final bool indexUint16;

  final List<String> jointNames;
  final List<int> jointParents; // parent index inside joints, -1 = root
  /// Joint indices sorted so every parent precedes its children.
  final List<int> jointOrder;
  final Float32List inverseBinds; // 16 floats per joint
  final Float32List restGlobal; // rest-pose global matrices, 16 per joint
  final Map<String, HeroClip> clips;
  final ui.Image? baseColor;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indexCount ~/ 3;

  /// Parses a .glb payload and decodes everything the renderer needs.
  static Future<GlbModel> load(Uint8List bytes) async {
    if (bytes.length < 12 || bytes[0] != 0x67 || bytes[1] != 0x6C) {
      throw ArgumentError('Not a GLB file');
    }
    final dv = ByteData.sublistView(bytes);
    var offset = 12;
    String? jsonText;
    Uint8List? bin;
    while (offset + 8 <= bytes.length) {
      final chunkLength = dv.getUint32(offset, Endian.little);
      final chunkType = bytes[offset + 4];
      final start = offset + 8;
      final data = Uint8List.sublistView(bytes, start, start + chunkLength);
      if (chunkType == 0x4A) {
        jsonText = utf8.decode(data);
      } else if (chunkType == 0x42) {
        bin = data;
      }
      offset = start + chunkLength;
    }
    if (jsonText == null || bin == null) {
      throw ArgumentError('GLB is missing its JSON or BIN chunk');
    }
    final gltf = jsonDecode(jsonText) as Map<String, dynamic>;

    final mesh = (gltf['meshes'] as List).first as Map<String, dynamic>;
    final prim = (mesh['primitives'] as List).first as Map<String, dynamic>;
    final attrs = prim['attributes'] as Map<String, dynamic>;
    final positions =
        _readVec(gltf, bin, attrs['POSITION'] as int, 3) as Float32List;
    final normals =
        _readVec(gltf, bin, attrs['NORMAL'] as int, 3) as Float32List;
    final texCoords =
        _readVec(gltf, bin, attrs['TEXCOORD_0'] as int, 2) as Float32List;
    final jointIdxAcc = (gltf['accessors'] as List)[attrs['JOINTS_0'] as int]
        as Map<String, dynamic>;
    final Uint8List joints;
    if (jointIdxAcc['componentType'] == 5121) {
      joints =
          _readVec(gltf, bin, attrs['JOINTS_0'] as int, 4) as Uint8List;
    } else {
      final us = _readVec(gltf, bin, attrs['JOINTS_0'] as int, 4)
          as Uint16List;
      joints = Uint8List(us.length);
      for (var i = 0; i < us.length; i++) {
        joints[i] = us[i];
      }
    }
    final weights =
        _readVec(gltf, bin, attrs['WEIGHTS_0'] as int, 4) as Float32List;

    final idxAcc = (gltf['accessors'] as List)[prim['indices'] as int]
        as Map<String, dynamic>;
    final TypedData indices;
    final bool indexUint16;
    if (idxAcc['componentType'] == 5123) {
      indices = _readVec(gltf, bin, prim['indices'] as int, 1) as Uint16List;
      indexUint16 = true;
    } else {
      indices = _readVec(gltf, bin, prim['indices'] as int, 1) as Uint32List;
      indexUint16 = false;
    }

    final skin = (gltf['skins'] as List).first as Map<String, dynamic>;
    final jointNodes = (skin['joints'] as List).cast<int>();
    final nodes = gltf['nodes'] as List;
    final jointNames = jointNodes.map((i) => nodes[i]['name'] as String).toList();
    final nodeToJoint = <int, int>{};
    for (var i = 0; i < jointNodes.length; i++) {
      nodeToJoint[jointNodes[i]] = i;
    }
    final jointParents = List<int>.filled(jointNodes.length, -1);
    for (var i = 0; i < jointNodes.length; i++) {
      final children = nodes[jointNodes[i]]['children'] as List?;
      if (children == null) continue;
      for (final c in children.cast<int>()) {
        final j = nodeToJoint[c];
        if (j != null) jointParents[j] = i;
      }
    }
    // Topological order: parents before children.
    final jointOrder = <int>[];
    final visited = List<bool>.filled(jointNodes.length, false);
    void visit(int j) {
      if (visited[j]) return;
      visited[j] = true;
      final p = jointParents[j];
      if (p >= 0) visit(p);
      jointOrder.add(j);
    }
    for (var i = 0; i < jointNodes.length; i++) {
      visit(i);
    }

    final inverseBinds = _readVec(
      gltf,
      bin,
      skin['inverseBindMatrices'] as int,
      16,
    ) as Float32List;

    // Rest-pose global matrices (before any animation).
    final localCache = <int, Float32List>{};
    Float32List localOf(int node) {
      return localCache.putIfAbsent(
        node,
        () => _nodeLocalMatrix(nodes[node] as Map<String, dynamic>),
      );
    }

    final nodeGlobal = <int, Float32List>{};
    Float32List globalOf(int node, int? parent) {
      final local = localOf(node);
      if (parent == null) {
        return nodeGlobal[node] = Float32List.fromList(local);
      }
      final g = Float32List(16);
      _mul(g, 0, nodeGlobal[parent]!, 0, local, 0);
      return nodeGlobal[node] = g;
    }

    // Walk the full node graph from scene roots so every node has a global.
    final hasParent = <int>{};
    for (final n in nodes.cast<Map<String, dynamic>>()) {
      for (final c in (n['children'] as List? ?? const []).cast<int>()) {
        hasParent.add(c);
      }
    }
    void walk(int node) {
      final children = nodes[node]['children'] as List?;
      final parent =
          hasParent.contains(node) ? _findParentNode(nodes, node) : null;
      globalOf(node, parent);
      if (children != null) {
        for (final c in children.cast<int>()) {
          walk(c);
        }
      }
    }

    final scene = gltf['scenes']![gltf['scene'] ?? 0] as Map<String, dynamic>;
    for (final root in (scene['nodes'] as List).cast<int>()) {
      walk(root);
    }

    final restGlobal = Float32List(16 * jointNodes.length);
    for (var j = 0; j < jointNodes.length; j++) {
      restGlobal.setRange(j * 16, j * 16 + 16, nodeGlobal[jointNodes[j]]!);
    }

    // --- animations ---
    final clips = <String, HeroClip>{};
    for (final raw in (gltf['animations'] as List).cast<dynamic>()) {
      final anim = raw as Map<String, dynamic>;
      final name = (anim['name'] as String?) ?? 'clip';
      final samplers =
          (anim['samplers'] as List).cast<Map<String, dynamic>>();
      final tracksByNode = <int, Map<String, _Track>>{};
      double maxTime = 0;
      for (final ch in (anim['channels'] as List).cast<Map<String, dynamic>>() ) {
        final node = ch['target']['node'] as int;
        final prop = ch['target']['path'] as String;
        final s = samplers[ch['sampler'] as int];
        final times = _readVec(gltf, bin, s['input'] as int, 1) as Float32List;
        final comps = prop == 'rotation' ? 4 : 3;
        final values =
            _readVec(gltf, bin, s['output'] as int, comps) as Float32List;
        maxTime = math.max(maxTime, times[times.length - 1]);
        tracksByNode
            .putIfAbsent(node, () => {})[prop] = _Track(
          times: times,
          values: values,
          components: comps,
        );
      }
      final jointTracks = <int, _NodeTracks>{};
      tracksByNode.forEach((node, props) {
        final j = nodeToJoint[node];
        if (j == null) return;
        jointTracks[j] = _NodeTracks(
          rotation: props['rotation'],
          translation: props['translation'],
          scale: props['scale'],
        );
      });
      clips[name] = HeroClip(
        durationMs: maxTime * 1000.0,
        jointTracks: jointTracks,
      );
    }

    // --- base-colour texture ---
    ui.Image? baseColor;
    try {
      final material =
          ((gltf['materials'] as List).first as Map<String, dynamic>);
      final pbr =
          material['pbrMetallicRoughness'] as Map<String, dynamic>? ?? {};
      final bct = pbr['baseColorTexture'] as Map<String, dynamic>?;
      if (bct != null) {
        final texture =
            (gltf['textures'] as List)[bct['index'] as int]
                as Map<String, dynamic>;
        final image = (gltf['images'] as List)[texture['source'] as int]
            as Map<String, dynamic>;
        final view = (gltf['bufferViews'] as List)[image['bufferView'] as int]
            as Map<String, dynamic>;
        final start = (view['byteOffset'] as num?)?.toInt() ?? 0;
        final length = (view['byteLength'] as num).toInt();
        final bytes = Uint8List.sublistView(bin, start, start + length);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        baseColor = frame.image;
        codec.dispose();
      }
    } catch (_) {
      baseColor = null; // texture is optional; the painter falls back to white
    }

    return GlbModel(
      positions: positions,
      normals: normals,
      texCoords: texCoords,
      jointIndices: joints,
      weights: weights,
      indices: indices,
      indexUint16: indexUint16,
      jointNames: jointNames,
      jointParents: jointParents,
      jointOrder: jointOrder,
      inverseBinds: inverseBinds,
      restGlobal: restGlobal,
      clips: clips,
      baseColor: baseColor,
      indexCount: idxAcc['count'] as int,
    );
  }
}

/// Finds the parent node index of [node] in [nodesList], or null for roots.
int? _findParentNode(List nodesList, int node) {
  for (var i = 0; i < nodesList.length; i++) {
    final kids = (nodesList[i] as Map<String, dynamic>)['children'] as List?;
    if (kids != null && kids.contains(node)) return i;
  }
  return null;
}

/// One skeletal animation clip: per-joint TRS tracks.
class HeroClip {
  HeroClip({required this.durationMs, required this.jointTracks});
  final double durationMs;
  final Map<int, _NodeTracks> jointTracks;
}

class _NodeTracks {
  _NodeTracks({this.rotation, this.translation, this.scale});
  final _Track? rotation;
  final _Track? translation;
  final _Track? scale;
}

class _Track {
  _Track({required this.times, required this.values, required this.components});
  final Float32List times;
  final Float32List values;
  final int components;

  int findFrame(double t, {required bool loop}) {
    final last = times.length - 1;
    if (last <= 0) return 0;
    var lo = 0;
    var hi = last;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (times[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void sample(double t, Float32List out, int outOffset, {required bool loop}) {
    final last = times.length - 1;
    if (last < 0) return;
    if (last == 0) {
      for (var c = 0; c < components; c++) {
        out[outOffset + c] = values[c];
      }
      return;
    }
    var t2 = t;
    if (loop && t2 > times[last]) {
      t2 %= times[last];
    }
    final i = findFrame(t2, loop: false);
    final t0 = times[i];
    final t1 = times[i + 1];
    final span = t1 - t0;
    final f = span <= 0 ? 0.0 : ((t2 - t0) / span).clamp(0.0, 1.0);
    final o0 = i * components;
    final o1 = (i + 1) * components;
    if (components == 4) {
      // Quaternion slerp (nlerp on close dots, slerp otherwise).
      var q0x = values[o0], q0y = values[o0 + 1];
      var q0z = values[o0 + 2], q0w = values[o0 + 3];
      var q1x = values[o1], q1y = values[o1 + 1];
      var q1z = values[o1 + 2], q1w = values[o1 + 3];
      var dot = q0x * q1x + q0y * q1y + q0z * q1z + q0w * q1w;
      if (dot < 0) {
        q1x = -q1x;
        q1y = -q1y;
        q1z = -q1z;
        q1w = -q1w;
        dot = -dot;
      }
      double a, b;
      if (dot > 0.9995) {
        a = 1 - f;
        b = f;
      } else {
        final theta = math.acos(dot.clamp(-1.0, 1.0));
        final sinT = math.sin(theta);
        a = math.sin((1 - f) * theta) / sinT;
        b = math.sin(f * theta) / sinT;
      }
      out[outOffset] = q0x * a + q1x * b;
      out[outOffset + 1] = q0y * a + q1y * b;
      out[outOffset + 2] = q0z * a + q1z * b;
      out[outOffset + 3] = q0w * a + q1w * b;
    } else {
      for (var c = 0; c < components; c++) {
        out[outOffset + c] = values[o0 + c] * (1 - f) + values[o1 + c] * f;
      }
    }
  }
}

/// Evaluates skeletal poses for one [GlbModel]. Reuses scratch buffers so a
/// frame pose costs no allocations.
class Poser {
  Poser(this.model)
      : local = Float32List(16 * model.jointNames.length),
        global = Float32List(16 * model.jointNames.length),
        skin = Float32List(16 * model.jointNames.length);

  final GlbModel model;
  final Float32List local;
  final Float32List global;
  /// Final skinning matrices (global pose × inverse bind), 16 per joint.
  final Float32List skin;
  final Float32List _trBuffer = Float32List(3);
  final Float32List _rotBuffer = Float32List(4);
  final Float32List _scBuffer = Float32List(3);

  /// Composes the skeleton at [timeMs] of [clipName] and fills [skin].
  void poseAt(
    String clipName,
    double timeMs, {
    required bool loop,
  }) {
    final jointCount = model.jointNames.length;
    final clip = model.clips[clipName];
    if (clip == null) {
      // No such animation: hold the rest pose.
      global.setAll(0, model.restGlobal);
      for (var j = 0; j < jointCount; j++) {
        _mul(skin, j * 16, global, j * 16, model.inverseBinds, j * 16);
      }
      return;
    }
    final t = clip.durationMs <= 0
        ? 0.0
        : loop
            ? timeMs % clip.durationMs
            : timeMs.clamp(0.0, clip.durationMs);

    // Local matrices: animated TRS per joint.
    for (var j = 0; j < jointCount; j++) {
      final base = j * 16;
      final tracks = clip.jointTracks[j];
      final tr = _trBuffer;
      final rot = _rotBuffer;
      final sc = _scBuffer;
      if (tracks == null) {
        tr[0] = tr[1] = tr[2] = 0;
        rot[0] = rot[1] = rot[2] = 0;
        rot[3] = 1;
        sc[0] = sc[1] = sc[2] = 1;
      } else {
        final tt = tracks.translation;
        if (tt != null) {
          tt.sample(t, tr, 0, loop: loop);
        } else {
          tr[0] = tr[1] = tr[2] = 0;
        }
        final trk = tracks.rotation;
        if (trk != null) {
          trk.sample(t, rot, 0, loop: loop);
        } else {
          rot[0] = rot[1] = rot[2] = 0;
          rot[3] = 1;
        }
        final ts = tracks.scale;
        if (ts != null) {
          ts.sample(t, sc, 0, loop: loop);
        } else {
          sc[0] = sc[1] = sc[2] = 1;
        }
      }
      _composeTrs(local, base, tr, rot, sc);
    }

    // Global matrices, parents before children.
    for (final j in model.jointOrder) {
      final base = j * 16;
      final parent = model.jointParents[j];
      if (parent < 0) {
        global.setRange(base, base + 16, local, base);
      } else {
        _mul(global, base, global, parent * 16, local, base);
      }
    }

    // Skin matrices: global × inverseBind.
    for (var j = 0; j < jointCount; j++) {
      _mul(skin, j * 16, global, j * 16, model.inverseBinds, j * 16);
    }
  }
}

// ---------------------------------------------------------------------------
// Column-major 4×4 helpers (glTF order), local to this library.
// ---------------------------------------------------------------------------

Float32List _nodeLocalMatrix(Map<String, dynamic> node) {
  final out = Float32List(16);
  if (node.containsKey('matrix')) {
    out.setAll(0, (node['matrix'] as List).cast<double>());
    return out;
  }
  List<double> trsOf(String key, List<double> fallback) {
    final raw = node[key] as List?;
    if (raw == null) return fallback;
    return raw.map((v) => (v as num).toDouble()).toList();
  }

  final t = trsOf('translation', const [0.0, 0.0, 0.0]);
  final r = trsOf('rotation', const [0.0, 0.0, 0.0, 1.0]);
  final s = trsOf('scale', const [1.0, 1.0, 1.0]);
  _composeTrs(
    out,
    0,
    Float32List.fromList([t[0].toDouble(), t[1].toDouble(), t[2].toDouble()]),
    Float32List.fromList(
      [r[0].toDouble(), r[1].toDouble(), r[2].toDouble(), r[3].toDouble()],
    ),
    Float32List.fromList([s[0].toDouble(), s[1].toDouble(), s[2].toDouble()]),
  );
  return out;
}

void _composeTrs(
  Float32List out,
  int o,
  Float32List t,
  Float32List r,
  Float32List s,
) {
  final x = r[0], y = r[1], z = r[2], w = r[3];
  final x2 = x + x, y2 = y + y, z2 = z + z;
  final xx = x * x2, xy = x * y2, xz = x * z2;
  final yy = y * y2, yz = y * z2, zz = z * z2;
  final wx = w * x2, wy = w * y2, wz = w * z2;
  out[o + 0] = (1 - (yy + zz)) * s[0];
  out[o + 1] = (xy + wz) * s[0];
  out[o + 2] = (xz - wy) * s[0];
  out[o + 3] = 0;
  out[o + 4] = (xy - wz) * s[1];
  out[o + 5] = (1 - (xx + zz)) * s[1];
  out[o + 6] = (yz + wx) * s[1];
  out[o + 7] = 0;
  out[o + 8] = (xz + wy) * s[2];
  out[o + 9] = (yz - wx) * s[2];
  out[o + 10] = (1 - (xx + yy)) * s[2];
  out[o + 11] = 0;
  out[o + 12] = t[0];
  out[o + 13] = t[1];
  out[o + 14] = t[2];
  out[o + 15] = 1;
}

void _mul(
  Float32List out,
  int o,
  Float32List a,
  int ao,
  Float32List b,
  int bo,
) {
  // Column-major: element (row r, col c) is m[c * 4 + r].
  // out_{r,c} = Σ_k a_{r,k} · b_{k,c}
  for (var c = 0; c < 4; c++) {
    for (var r = 0; r < 4; r++) {
      out[o + c * 4 + r] = a[ao + r] * b[bo + c * 4] +
          a[ao + 4 + r] * b[bo + c * 4 + 1] +
          a[ao + 8 + r] * b[bo + c * 4 + 2] +
          a[ao + 12 + r] * b[bo + c * 4 + 3];
    }
  }
}

/// Reads an accessor into a fresh flat typed list ([components] values per
/// element). Copies are one-time at load, so correctness beats zero-copy.
TypedData _readVec(
  Map<String, dynamic> gltf,
  Uint8List bin,
  int accessorIndex,
  int components,
) {
  final accessors = gltf['accessors'] as List;
  final views = gltf['bufferViews'] as List;
  final acc = accessors[accessorIndex] as Map<String, dynamic>;
  final view = views[acc['bufferView'] as int] as Map<String, dynamic>;
  final base =
      (view['byteOffset'] as int? ?? 0) + (acc['byteOffset'] as int? ?? 0);
  final elementCount = (acc['count'] as int) * components;
  final componentType = acc['componentType'] as int;
  final stride = view['byteStride'] as int? ?? 0;
  final dv = ByteData.sublistView(bin);
  switch (componentType) {
    case 5126:
      final out = Float32List(elementCount);
      for (var e = 0; e < elementCount; e++) {
        final i = e ~/ components;
        final c = e % components;
        out[e] = dv.getFloat32(base + i * (stride > 0 ? stride : components * 4) + c * 4, Endian.little);
      }
      return out;
    case 5123:
      final out = Uint16List(elementCount);
      for (var e = 0; e < elementCount; e++) {
        final i = e ~/ components;
        final c = e % components;
        out[e] = dv.getUint16(base + i * (stride > 0 ? stride : components * 2) + c * 2, Endian.little);
      }
      return out;
    case 5125:
      final out = Uint32List(elementCount);
      for (var e = 0; e < elementCount; e++) {
        final i = e ~/ components;
        final c = e % components;
        out[e] = dv.getUint32(base + i * (stride > 0 ? stride : components * 4) + c * 4, Endian.little);
      }
      return out;
    case 5121:
      final out = Uint8List(elementCount);
      for (var e = 0; e < elementCount; e++) {
        final i = e ~/ components;
        final c = e % components;
        out[e] = dv.getUint8(base + i * (stride > 0 ? stride : components) + c);
      }
      return out;
  }
  throw UnsupportedError('componentType $componentType');
}
