import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archer_fm/game/render3/glb.dart';
import 'package:flutter/material.dart';

/// Renders one skinned GLB hero into the arena canvas with a tilted top-down
/// camera, replacing the sprite-atlas frame for the playable character while
/// keeping the hero's gameplay position exactly aligned with the 2D arena.
///
/// Pipeline per frame: CPU skinning → model yaw → camera tilt → perspective
/// divide → backface cull → depth buckets → `Canvas.drawVertices` with the
/// model's embedded base-colour texture and per-vertex lambert shading.
class Hero3DModel {
  Hero3DModel(this.model)
      : poser = Poser(model),
        _skinned = Float32List(model.vertexCount * 3),
        _skinnedNormals = Float32List(model.vertexCount * 3),
        _restBbox = _bboxOf(model.positions) {
    // Single shared triangle-soup buffers, depth-bucketed at draw time.
    final triCount = model.triangleCount;
    _bucketPositions = Float32List(triCount * 6);
    _bucketUvs = Float32List(triCount * 6);
    _bucketColors = Int32List(triCount * 3);
    _triBucket = Uint8List(triCount);
    _triScreen = Float32List(triCount * 6);
    _triDepth = Float32List(triCount);
    _triMark = Int32List(triCount);
  }

  static const int _depthBuckets = 48;

  final GlbModel model;
  final Poser poser;

  final Float32List _skinned;
  final Float32List _skinnedNormals;
  late final Float32List _bucketPositions;
  late final Float32List _bucketUvs;
  late final Int32List _bucketColors;
  late final Uint8List _triBucket;
  late final Float32List _triScreen;
  late final Float32List _triDepth;
  int _triMarkValue = 0;
  late final Int32List _triMark;
  final Float32List _restBbox;

  double _lastPoseMs = -1;
  String _lastClip = '';

  /// Lowest skinned Y this frame (feet level); used to seat the feet on the
  /// gameplay anchor.
  double _skinnedMinY = 0;

  /// Highest skinned Y this frame (head level).
  double _skinnedMaxY = 0;

  /// Height of the standing idle pose, measured once for scale calibration.
  double? _standingHeight;

  double get modelHeight =>
      _restBbox[4] - _restBbox[1]; // y span of the rest pose

  /// Scale factor that makes the standing hero occupy [pixelHeight] px on
  /// screen (compensating for the camera tilt and perspective). Calibrated
  /// against the measured idle-pose height, not the rest bbox, because baked
  /// animations pose the skeleton slightly differently from the rest nodes.
  double scaleForPixelHeight(double pixelHeight) {
    final standing = _standingHeight ?? modelHeight;
    final sBar = _fieldOfViewScale / _cameraDistance;
    // Empirical 0.885 factor: perspective + the depth extent of the body make
    // the drawn height overshoot the planar estimate.
    return pixelHeight /
        (standing * math.cos(_tiltRadians) * sBar) * 0.885;
  }

  /// Measures the idle pose once so [scaleForPixelHeight] is accurate.
  /// Call after loading, before the first frame.
  void calibrate() {
    poser.poseAt('idle', 0, loop: true);
    _lastClip = '';
    _lastPoseMs = -1;
    skin();
    final h = _skinnedMaxY - _skinnedMinY;
    if (h > 0) _standingHeight = h;
  }

  /// Skinned vertex buffer (exposed for debugging/tests).
  Float32List get skinnedPositions => _skinned;

  /// Largest |coordinate| drawn last frame (debug/tests).
  double get lastDrawnExtent {
    var m = 0.0;
    for (final v in _bucketPositions) {
      final a = v.abs();
      if (a > m && a < 1e9) m = a;
    }
    return m;
  }

  /// Bounding box of drawn triangle soup (debug/tests).
  List<double> get drawnBounds {
    double mnx = 1e9, mny = 1e9, mxx = -1e9, mxy = -1e9;
    for (var b = 0; b < _depthBuckets; b++) {
      final start = _bucketStart[b];
      final end = _bucketFill[b];
      for (var tri = start; tri < end; tri++) {
        for (var vi = 0; vi < 3; vi++) {
          final x = _bucketPositions[tri * 6 + vi * 2];
          final y = _bucketPositions[tri * 6 + vi * 2 + 1];
          if (x < mnx) mnx = x;
          if (y < mny) mny = y;
          if (x > mxx) mxx = x;
          if (y > mxy) mxy = y;
        }
      }
    }
    return [mnx, mny, mxx, mxy];
  }

  /// First emitted UVs (debug/tests).
  List<double> get uvSample {
    for (var b = 0; b < _depthBuckets; b++) {
      if (_bucketFill[b] > _bucketStart[b]) {
        final s = _bucketStart[b] * 6;
        return _bucketUvs.sublist(s, s + 12).toList();
      }
    }
    return const [];
  }

  int get drawnTriangles {
    var n = 0;
    for (var b = 0; b < _depthBuckets; b++) {
      n += _bucketFill[b] - _bucketStart[b];
    }
    return n;
  }

  static Float32List _bboxOf(Float32List positions) {
    final out = Float32List(6);
    out[0] = out[3] = positions[0];
    out[1] = out[4] = positions[1];
    out[2] = out[5] = positions[2];
    for (var i = 3; i < positions.length; i += 3) {
      for (var c = 0; c < 3; c++) {
        final v = positions[i + c];
        if (v < out[c]) out[c] = v;
        if (v > out[3 + c]) out[3 + c] = v;
      }
    }
    return out;
  }

  /// Evaluates the skeleton (skipped when the same pose is requested twice).
  void pose(String clip, double timeMs, {required bool loop}) {
    if (clip == _lastClip && timeMs == _lastPoseMs) return;
    poser.poseAt(clip, timeMs, loop: loop);
    _lastClip = clip;
    _lastPoseMs = timeMs;
  }

  /// Skins every vertex with the poser's current matrices.
  void skin() {
    _skinnedMinY = double.infinity;
    _skinnedMaxY = double.negativeInfinity;
    final m = model;
    final joints = m.jointIndices;
    final weights = m.weights;
    final skinMats = poser.skin;
    final pos = m.positions;
    final nor = m.normals;
    final sk = _skinned;
    final skN = _skinnedNormals;
    for (var v = 0; v < m.vertexCount; v++) {
      final j0 = joints[v * 4] * 16;
      final j1 = joints[v * 4 + 1] * 16;
      final j2 = joints[v * 4 + 2] * 16;
      final j3 = joints[v * 4 + 3] * 16;
      final w0 = weights[v * 4];
      final w1 = weights[v * 4 + 1];
      final w2 = weights[v * 4 + 2];
      final w3 = weights[v * 4 + 3];
      final x = pos[v * 3], y = pos[v * 3 + 1], z = pos[v * 3 + 2];
      var ox = 0.0, oy = 0.0, oz = 0.0;
      double nx = 0, ny = 0, nz = 0;
      if (w0 > 0) {
        ox += (skinMats[j0] * x + skinMats[j0 + 4] * y +
                skinMats[j0 + 8] * z + skinMats[j0 + 12]) * w0;
        oy += (skinMats[j0 + 1] * x + skinMats[j0 + 5] * y +
                skinMats[j0 + 9] * z + skinMats[j0 + 13]) * w0;
        oz += (skinMats[j0 + 2] * x + skinMats[j0 + 6] * y +
                skinMats[j0 + 10] * z + skinMats[j0 + 14]) * w0;
        final nxv = nor[v * 3], nyv = nor[v * 3 + 1], nzv = nor[v * 3 + 2];
        nx += (skinMats[j0] * nxv + skinMats[j0 + 4] * nyv +
                skinMats[j0 + 8] * nzv) * w0;
        ny += (skinMats[j0 + 1] * nxv + skinMats[j0 + 5] * nyv +
                skinMats[j0 + 9] * nzv) * w0;
        nz += (skinMats[j0 + 2] * nxv + skinMats[j0 + 6] * nyv +
                skinMats[j0 + 10] * nzv) * w0;
      }
      if (w1 > 0) {
        ox += (skinMats[j1] * x + skinMats[j1 + 4] * y +
                skinMats[j1 + 8] * z + skinMats[j1 + 12]) * w1;
        oy += (skinMats[j1 + 1] * x + skinMats[j1 + 5] * y +
                skinMats[j1 + 9] * z + skinMats[j1 + 13]) * w1;
        oz += (skinMats[j1 + 2] * x + skinMats[j1 + 6] * y +
                skinMats[j1 + 10] * z + skinMats[j1 + 14]) * w1;
        final nxv = nor[v * 3], nyv = nor[v * 3 + 1], nzv = nor[v * 3 + 2];
        nx += (skinMats[j1] * nxv + skinMats[j1 + 4] * nyv +
                skinMats[j1 + 8] * nzv) * w1;
        ny += (skinMats[j1 + 1] * nxv + skinMats[j1 + 5] * nyv +
                skinMats[j1 + 9] * nzv) * w1;
        nz += (skinMats[j1 + 2] * nxv + skinMats[j1 + 6] * nyv +
                skinMats[j1 + 10] * nzv) * w1;
      }
      if (w2 > 0) {
        ox += (skinMats[j2] * x + skinMats[j2 + 4] * y +
                skinMats[j2 + 8] * z + skinMats[j2 + 12]) * w2;
        oy += (skinMats[j2 + 1] * x + skinMats[j2 + 5] * y +
                skinMats[j2 + 9] * z + skinMats[j2 + 13]) * w2;
        oz += (skinMats[j2 + 2] * x + skinMats[j2 + 6] * y +
                skinMats[j2 + 10] * z + skinMats[j2 + 14]) * w2;
        final nxv = nor[v * 3], nyv = nor[v * 3 + 1], nzv = nor[v * 3 + 2];
        nx += (skinMats[j2] * nxv + skinMats[j2 + 4] * nyv +
                skinMats[j2 + 8] * nzv) * w2;
        ny += (skinMats[j2 + 1] * nxv + skinMats[j2 + 5] * nyv +
                skinMats[j2 + 9] * nzv) * w2;
        nz += (skinMats[j2 + 2] * nxv + skinMats[j2 + 6] * nyv +
                skinMats[j2 + 10] * nzv) * w2;
      }
      if (w3 > 0) {
        ox += (skinMats[j3] * x + skinMats[j3 + 4] * y +
                skinMats[j3 + 8] * z + skinMats[j3 + 12]) * w3;
        oy += (skinMats[j3 + 1] * x + skinMats[j3 + 5] * y +
                skinMats[j3 + 9] * z + skinMats[j3 + 13]) * w3;
        oz += (skinMats[j3 + 2] * x + skinMats[j3 + 6] * y +
                skinMats[j3 + 10] * z + skinMats[j3 + 14]) * w3;
        final nxv = nor[v * 3], nyv = nor[v * 3 + 1], nzv = nor[v * 3 + 2];
        nx += (skinMats[j3] * nxv + skinMats[j3 + 4] * nyv +
                skinMats[j3 + 8] * nzv) * w3;
        ny += (skinMats[j3 + 1] * nxv + skinMats[j3 + 5] * nyv +
                skinMats[j3 + 9] * nzv) * w3;
        nz += (skinMats[j3 + 2] * nxv + skinMats[j3 + 6] * nyv +
                skinMats[j3 + 10] * nzv) * w3;
      }
      sk[v * 3] = ox;
      sk[v * 3 + 1] = oy;
      sk[v * 3 + 2] = oz;
      if (oy < _skinnedMinY) _skinnedMinY = oy;
      if (oy > _skinnedMaxY) _skinnedMaxY = oy;
      // Normalise; degenerate normals fall back to up.
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 1e-9) {
        skN[v * 3] = nx / len;
        skN[v * 3 + 1] = ny / len;
        skN[v * 3 + 2] = nz / len;
      } else {
        skN[v * 3] = 0;
        skN[v * 3 + 1] = 1;
        skN[v * 3 + 2] = 0;
      }
    }
  }

  /// Draws the currently posed + skinned hero at [anchor] (feet) on the
  /// canvas, facing [yaw] radians, [scale] px per model unit.
  ///
  /// [tint] multiplies the texture (used for hit flashes / veil translucency
  /// via [alpha]).
  void paint(
    Canvas canvas, {
    required Offset anchor,
    required double yaw,
    required double scale,
    double alphaParam = 1,
    Color? tint,
  }) {
    final m = model;
    final tex = m.baseColor;
    final alpha = alphaParam.clamp(0.0, 1.0);
    final tintColor = tint ?? const Color(0xFFFFFFFF);
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Color.fromRGBO(
        (tintColor.r * 255.0).round() & 0xff,
        (tintColor.g * 255.0).round() & 0xff,
        (tintColor.b * 255.0).round() & 0xff,
        alpha,
      );

    // Camera: tilt about the X axis (looking down at the arena), perspective
    // divide. Arena +x = screen +x, arena depth (z) recedes up-screen.
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final tilt = _tiltRadians;
    final cosT = math.cos(tilt);
    final sinT = math.sin(tilt);

    final camDist = _cameraDistance;
    final focal = _fieldOfViewScale;

    final counts = _bucketCounts;
    final texW = tex?.width.toDouble() ?? 1;
    final texH = tex?.height.toDouble() ?? 1;

    final tc = m.texCoords;
    final sk = _skinned;
    final skN = _skinnedNormals;
    final indices = m.indices;
    final nTris = m.triangleCount;
    final is16 = m.indexUint16;
    final idx16 = is16 ? indices as Uint16List : null;
    final idx32 = is16 ? null : indices as Uint32List;

    // Light direction in view space (from above and slightly south).
    final lx = 0.25, ly = 0.85, lz = 0.45;
    final ln = 1 / math.sqrt(lx * lx + ly * ly + lz * lz);

    final baseR = (tintColor.r * 255.0).round() & 0xff;
    final baseG = (tintColor.g * 255.0).round() & 0xff;
    final baseB = (tintColor.b * 255.0).round() & 0xff;

    for (var b = 0; b < _depthBuckets; b++) {
      counts[b] = 0;
    }

    // Pass A: project, cull and bucket every triangle; keep its screen
    // coordinates so pass B only reorders.
    _triMarkValue++;
    final view = _viewScratch; // per-vertex view coords: x,y,depth
    var visible = 0;
    for (var t = 0; t < nTris; t++) {
      final i0 = is16 ? idx16![t * 3] : idx32![t * 3];
      final i1 = is16 ? idx16![t * 3 + 1] : idx32![t * 3 + 1];
      final i2 = is16 ? idx16![t * 3 + 2] : idx32![t * 3 + 2];

      // Project the 3 vertices.
      var ok = true;
      for (var vi = 0; vi < 3; vi++) {
        final v = vi == 0 ? i0 : (vi == 1 ? i1 : i2);
        final x = sk[v * 3] * scale;
        final y = (sk[v * 3 + 1] - _skinnedMinY) * scale;
        final z = sk[v * 3 + 2] * scale;
        // Model yaw about the up axis (Y).
        final wx = x * cosY + z * sinY;
        final wz = -x * sinY + z * cosY;
        // Camera tilt: ground recedes up-screen with depth.
        final vy = y * cosT - wz * sinT;
        final vz = y * sinT + wz * cosT;
        final denom = camDist + vz;
        if (denom < 1) {
          ok = false;
          break;
        }
        final s = focal / denom;
        view[vi * 3] = anchor.dx + s * wx;
        view[vi * 3 + 1] = anchor.dy - s * vy;
        view[vi * 3 + 2] = denom; // larger = farther
      }
      if (!ok) continue;

      // Backface cull in screen space (signed area; canvas y is down).
      final ax = view[3] - view[0];
      final ay = view[4] - view[1];
      final bx = view[6] - view[0];
      final by = view[7] - view[1];
      final area = ax * by - ay * bx;
      if (_cullMode == 1 ? area <= 0 : _cullMode == 2 ? area >= 0 : false) {
        continue;
      }

      // Depth bucket from the triangle centroid.
      final centroid = (view[2] + view[5] + view[8]) / 3;
      final bucket = ((centroid - camDist) / _bucketSpan)
          .floor()
          .clamp(0, _depthBuckets - 1)
          .toInt();

      _triMark[t] = _triMarkValue;
      for (var vi = 0; vi < 3; vi++) {
        _triScreen[t * 6 + vi * 2] = view[vi * 3];
        _triScreen[t * 6 + vi * 2 + 1] = view[vi * 3 + 1];
      }
      _triDepth[t] = centroid;
      _triBucket[t] = bucket;
      counts[bucket]++;
      visible++;
    }

    // Bucket start offsets (stable, in original triangle order).
    var running = 0;
    for (var b = 0; b < _depthBuckets; b++) {
      _bucketStart[b] = running;
      _bucketFill[b] = running;
      running += counts[b];
    }

    // Pass B: emit visible triangles, bucket by bucket (far→near fill order
    // does not matter — drawing order below decides occlusion).
    for (var t = 0; t < nTris; t++) {
      if (_triMark[t] != _triMarkValue) continue; // culled or stale
      final bucket = _triBucket[t];
      final slot = _bucketFill[bucket];
      {
        // Visible triangle: copy screen coords + UVs + shaded colors.
        final o = slot * 6;
        for (var vi = 0; vi < 3; vi++) {
          final v = is16
              ? (idx16![t * 3 + vi])
              : (idx32![t * 3 + vi]);
          _bucketPositions[o + vi * 2] = _triScreen[t * 6 + vi * 2];
          _bucketPositions[o + vi * 2 + 1] = _triScreen[t * 6 + vi * 2 + 1];
          // This Skia build samples the ImageShader in image-pixel space with
          // an identity matrix, so UVs are scaled to texels here.
          _bucketUvs[o + vi * 2] = tc[v * 2] * texW;
          _bucketUvs[o + vi * 2 + 1] = tc[v * 2 + 1] * texH;
          final nx = skN[v * 3], ny = skN[v * 3 + 1], nz = skN[v * 3 + 2];
          var shade = (nx * lx + ny * ly + nz * lz) * ln;
          // Slightly stronger ambient fill keeps reference faces, eyes and
          // armor readable under the elevated arena camera without flattening
          // the remaining directional light.
          shade = 0.73 + 0.27 * shade.clamp(0.0, 1.0);
          final co = slot * 3 + vi;
          // Per-vertex material base colour (white for texture-driven
          // models — the texture carries the colouring instead).
          final mc = model.materialColors;
          _bucketColors[co] = 0xFF000000 |
              ((shade * baseR * mc[v * 3]).round().clamp(0, 255) << 16) |
              ((shade * baseG * mc[v * 3 + 1]).round().clamp(0, 255) << 8) |
              ((shade * baseB * mc[v * 3 + 2]).round().clamp(0, 255));
        }
        _bucketFill[bucket] = slot + 1;
      }
    }
    if (visible == 0) return;
    // _bucketFill now equals bucket ends after pass B.

    // Draw buckets far → near. Single character, 48 draws max.
    final shader = tex == null
        ? null
        : ui.ImageShader(
            tex,
            TileMode.clamp,
            TileMode.clamp,
            _identityMatrix(),
            filterQuality: FilterQuality.low,
          );
    if (shader != null) paint.shader = shader;
    for (var b = _depthBuckets - 1; b >= 0; b--) {
      final start = _bucketStart[b];
      final count = _bucketFill[b] - start;
      if (count <= 0) continue;
      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.sublistView(_bucketPositions, start * 6, (start + count) * 6),
        textureCoordinates: shader == null
            ? null
            : Float32List.sublistView(_bucketUvs, start * 6, (start + count) * 6),
        colors: Int32List.sublistView(_bucketColors, start * 3, (start + count) * 3),
      );
      canvas.drawVertices(vertices, BlendMode.modulate, paint);
      vertices.dispose();
    }
    shader?.dispose();
  }

  // Camera parameters, tuned so a ~1.7-unit hero occupies a phone-screen-
  // sized sprite footprint at the same anchor the atlas used.
  static const double _tiltRadians = 0.9; // ~52° from horizontal
  static const double _cameraDistance = 900;
  static const double _fieldOfViewScale = 620;
  static const double _bucketSpan = 12;

  /// 0 = no cull (debug), 1 = keep area > 0, 2 = keep area < 0.
  int _cullMode = 1;
  set cullFlipped(bool? v) =>
      _cullMode = v == null ? 0 : (v ? 1 : 2);

  final List<int> _bucketCounts = List<int>.filled(_depthBuckets, 0);
  final List<int> _bucketStart = List<int>.filled(_depthBuckets, 0);
  final List<int> _bucketFill = List<int>.filled(_depthBuckets, 0);
  final Float32List _viewScratch = Float32List(9);
}

Float64List _identityMatrix() {
  final m = Float64List(16);
  m[0] = m[5] = m[10] = m[15] = 1;
  return m;
}
