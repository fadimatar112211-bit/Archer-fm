// Monster3D: CPU skinned renderer for monster .bin assets.
// Format: same as Hero3D .bin but with variable bone count (bc) and clipMeta.
// Clips: Idle, Walk, Run, Attack, Roar, Hit, Die
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;

class MonsterClip {
  final int frames;
  final double secs;
  final bool loop;
  const MonsterClip(this.frames, this.secs, this.loop);
}

class Monster3D {
  Monster3D(this.id, {this.height = 90});
  final String id;

  double height;
  ui.Offset position = ui.Offset.zero; // feet position
  double hp = 100;
  double maxHp = 100;
  String anim = 'Idle';
  double _t = 0;
  double _heading = 0, _yaw = 0;
  bool _nQueued = false;
  int _n = 0;
  int _tcount = 0;
  int _bc = 12;
  int _stride = 144; // bc*12
  Map<String, List<dynamic>> _clipRanges = {};
  Map<String, MonsterClip> _clips = {};
  late Float32List _pos, _mats, _xy, _depth;
  late Int32List _col;
  late Uint8List _skin;
  late Uint16List _tri;
  Float32List _bones = Float32List(144);

  // behavior flags
  bool isStealth = false; // blind-stalker
  double stealthAlpha = 1.0; // 0..1
  bool isHeavyAoe = false; // stone-golem
  double _aoeWaveAge = 999;
  double _aoeWaveR = 0;
  ui.Offset _aoeWaveCenter = ui.Offset.zero;

  // callbacks
  void Function(ui.Offset center, double radius, double damage)? onHit;
  void Function(String sound)? onSound;

  bool get isDead => anim == 'Die';
  bool get isReady => _n > 0;
  bool get isFree => anim == 'Idle' || anim == 'Walk' || anim == 'Run';
  ui.Offset get aim => ui.Offset(sin(_heading), cos(_heading));

  static const _defaultClips = {
    'Idle': MonsterClip(6, 3.0, true),
    'Walk': MonsterClip(8, 1.6, true),
    'Run': MonsterClip(6, 0.9, true),
    'Attack': MonsterClip(8, 1.2, false),
    'Roar': MonsterClip(8, 2.6, false),
    'Hit': MonsterClip(4, 0.45, false),
    'Die': MonsterClip(8, 2.2, false),
  };

  Future<void> load([String folder = 'assets/monsters']) async {
    final data = await rootBundle.load('$folder/$id/$id.bin');
    final raw = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final bytes = raw.offsetInBytes % 4 == 0 ? raw : Uint8List.fromList(raw);
    final buf = bytes.buffer;
    final base = bytes.offsetInBytes;
    final headLength = ByteData.view(buf, base, bytes.lengthInBytes).getUint32(0, Endian.little);
    final head = jsonDecode(utf8.decode(bytes.sublist(4, 4 + headLength))) as Map<String, dynamic>;
    final n = head['n'] as int;
    final t = head['t'] as int;
    _bc = (head['bc'] as int?) ?? 12;
    _stride = _bc * 12;
    _clipRanges = (head['clips'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).cast<dynamic>()));
    final clipMeta = (head['clipMeta'] as Map<String, dynamic>?) ?? {};
    _clips = {};
    for (final e in _clipRanges.entries) {
      final meta = (clipMeta[e.key] as Map<String, dynamic>?) ?? {};
      final dur = (meta['dur'] as num?)?.toDouble() ?? _defaultClips[e.key]?.secs ?? 1.0;
      final loop = (meta['loop'] as bool?) ?? _defaultClips[e.key]?.loop ?? false;
      final fc = (e.value[1] as int);
      _clips[e.key] = MonsterClip(fc, dur, loop);
    }
    // ensure all 7 exist
    for (final k in _defaultClips.keys) {
      _clips.putIfAbsent(k, () => _defaultClips[k]!);
    }
    var at = (4 + headLength + 3) & ~3;
    int take(int size) { final start = at; at += (size + 3) & ~3; return base + start; }
    _pos = buf.asFloat32List(take(n * 12), n * 3);
    _col = buf.asInt32List(take(n * 4), n);
    _skin = buf.asUint8List(take(n * 3), n * 3);
    _tri = buf.asUint16List(take(t * 6), t * 3);
    _mats = buf.asFloat32List(base + at);
    _xy = Float32List(n * 2);
    _depth = Float32List(n);
    _bones = Float32List(_stride);
    _tcount = t; // triangle count
    _n = n;
  }

  void dispose() { _n = 0; }

  void face(ui.Offset v) { if (v.distance > .1) _heading = atan2(v.dx, v.dy); }

  void _set(String name) {
    if (!_clipRanges.containsKey(name)) return;
    anim = name;
    _t = 0;
  }

  void play(String name) {
    if (isDead && name != 'Die') return;
    _set(name);
  }

  void triggerAttack() {
    if (isDead) return;
    if (anim == 'Attack') { _nQueued = true; return; }
    if (isFree) _set('Attack');
  }

  void triggerRoar() { if (isFree) _set('Roar'); }

  void takeHit(double damage) {
    if (isDead) return;
    hp = max(0.0, hp - damage);
    onSound?.call(hp > 0 ? 'hit' : 'death');
    if (hp <= 0) {
      _set('Die');
    } else {
      _set('Hit');
    }
  }

  void revive([double health = 100]) {
    hp = health;
    maxHp = max(maxHp, health);
    _set('Idle');
    _aoeWaveAge = 999;
  }

  void update(double dt, {ui.Offset? moveDir, double moveSpeed = 0, bool attacking = false, bool roaring = false}) {
    if (!isReady) return;
    _t += dt;
    _yaw += atan2(sin(_heading - _yaw), cos(_heading - _yaw)) * (1 - exp(-dt * 14));

    // stealth pulse for blind-stalker
    if (isStealth && !isDead) {
      // vanish when moving/idle, appear briefly on attack/roar/hit
      final visible = anim == 'Attack' || anim == 'Roar' || anim == 'Hit';
      final target = visible ? 1.0 : 0.18;
      stealthAlpha += (target - stealthAlpha) * (1 - exp(-dt * 6));
    } else {
      stealthAlpha += (1.0 - stealthAlpha) * (1 - exp(-dt * 8));
    }

    // AOE wave aging
    _aoeWaveAge += dt;

    final moving = moveDir != null && moveDir.distance > .05;
    final m = (moveDir != null && moveDir.distance > 1) ? moveDir / moveDir.distance : (moveDir ?? ui.Offset.zero);
    if (isFree) {
      if (roaring) {
        _set('Roar');
      } else if (attacking) {
        triggerAttack();
      } else if (moving) {
        face(m);
        final speed = moveSpeed > 0 ? moveSpeed : height * 0.8;
        position += m * speed * dt;
        final want = speed > height * 1.1 ? 'Run' : 'Walk';
        if (anim != want) _set(want);
      } else {
        if (anim != 'Idle') _set('Idle');
      }
    } else if (anim == 'Attack' && moving) {
      // small forward lunge
      position += aim * (height * 0.3 * dt);
    }

    // AOE trigger for heavy golem on attack impact
    if (isHeavyAoe && anim == 'Attack') {
      final impact = 0.78; // from monster.json estimate
      if (_t >= impact && _t - dt < impact) {
        _aoeWaveAge = 0;
        _aoeWaveR = height * 0.9;
        _aoeWaveCenter = position + aim * (height * 0.25);
        onHit?.call(_aoeWaveCenter, _aoeWaveR, 18);
        onSound?.call('boom');
      }
    } else if (anim == 'Attack') {
      // normal/fast/stealth single target hit at impact
      final impact = id == 'werewolf' ? 0.62 : (id == 'blind-stalker' ? 0.64 : 0.62);
      if (_t >= impact && _t - dt < impact) {
        final c = position + aim * (height * 0.35);
        final r = id == 'stone-golem' ? height * 0.7 : height * 0.35;
        final dmg = id == 'werewolf' ? 14.0 : (id == 'blind-stalker' ? 16.0 : 12.0);
        onHit?.call(c, r, dmg);
        onSound?.call('hit');
      }
    }

    // clip end
    final clip = _clips[anim] ?? _defaultClips['Idle']!;
    final end = clip.loop || isDead ? double.infinity : clip.secs;
    if (_t >= end) {
      if (anim == 'Attack' && _nQueued) {
        _nQueued = false;
        _set('Attack');
      } else if (!isDead) {
        _nQueued = false;
        _set('Idle');
      }
    }
  }

  void paint(ui.Canvas canvas) {
    if (!isReady) return;
    final clip = _clips[anim] ?? _defaultClips['Idle']!;
    final range = _clipRanges[anim];
    if (range == null) return;
    final start = range[0] as int;
    final count = range[1] as int;
    var u = _t / clip.secs;
    u = clip.loop ? (u % 1.0) : u.clamp(0.0, 1.0).toDouble();
    final f = u * (clip.loop ? count : (count - 1));
    final i0 = min(f.floor(), count - 1);
    final i1 = clip.loop ? (i0 + 1) % count : min(i0 + 1, count - 1);
    final w = f - i0;
    final stride = _stride;
    for (var k = 0; k < stride; k++) {
      final a = _mats[(start + i0) * stride + k];
      _bones[k] = a + (_mats[(start + i1) * stride + k] - a) * w;
    }
    final cy = cos(_yaw), sy = sin(_yaw), cp = cos(.3), sp = sin(.3);
    for (var v = 0; v < _n; v++) {
      final px = _pos[v * 3], py = _pos[v * 3 + 1], pz = _pos[v * 3 + 2];
      final a = _skin[v * 3] * 12;
      final b = _skin[v * 3 + 1] * 12;
      final q = _skin[v * 3 + 2] / 255.0;
      double row(int r) {
        final m = _bones[a + r] * px + _bones[a + 3 + r] * py + _bones[a + 6 + r] * pz + _bones[a + 9 + r];
        final o = _bones[b + r] * px + _bones[b + 3 + r] * py + _bones[b + 6 + r] * pz + _bones[b + 9 + r];
        return m + (o - m) * q;
      }
      final x = row(0), y = row(1), z = row(2);
      final wx = x * cy - z * sy;
      final wz = x * sy + z * cy;
      final vy = y * cp - wz * sp;
      final vz = y * sp + wz * cp;
      final sc = height / 1.9;
      _xy[v * 2] = position.dx + wx * sc;
      _xy[v * 2 + 1] = position.dy - vy * sc;
      _depth[v] = vz;
    }

    // draw AOE wave
    if (isHeavyAoe && _aoeWaveAge < 0.6) {
      final p = (_aoeWaveAge / 0.6).clamp(0.0, 1.0);
      final r = _aoeWaveR * (0.4 + 0.8 * p);
      final paint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - p) + 1
        ..color = const ui.Color(0xFFFFD180).withValues(alpha: 0.7 * (1 - p));
      canvas.drawCircle(_aoeWaveCenter, r, paint);
      final fill = ui.Paint()..color = const ui.Color(0xFFFF8A65).withValues(alpha: 0.12 * (1 - p));
      canvas.drawCircle(_aoeWaveCenter, r, fill);
    }

    // simple painter's algorithm by triangle depth sort (bucket-ish small)
    // For mobile performance, draw unsorted if large; here use per-triangle average depth sort light.
    final triCount = _tcount;
    final depths = Float32List(triCount);
    for (var i = 0; i < triCount; i++) {
      final i3 = i * 3;
      final a = _tri[i3]; final b = _tri[i3 + 1]; final c = _tri[i3 + 2];
      depths[i] = (_depth[a] + _depth[b] + _depth[c]) / 3.0;
    }
    // simple insertion sort for small arrays is bad; use indexed sort via List<int>
    final idx = List<int>.generate(triCount, (i) => i);
    idx.sort((a, b) => depths[a].compareTo(depths[b]));

    // build drawVertices batches by color is expensive; draw per triangle via drawVertices in chunks.
    // For simplicity/perf balance, draw in chunks of 256 triangles.
    const chunk = 256;
    final alphaMul = stealthAlpha.clamp(0.0, 1.0);
    for (var startI = 0; startI < idx.length; startI += chunk) {
      final endI = min(idx.length, startI + chunk);
      final countTri = endI - startI;
      final verts = ui.Vertices(ui.VertexMode.triangles,
        List<ui.Offset>.generate(countTri * 3, (k) {
          final ti = idx[startI + (k ~/ 3)];
          final vi = _tri[ti * 3 + (k % 3)];
          return ui.Offset(_xy[vi * 2], _xy[vi * 2 + 1]);
        }),
        colors: List<ui.Color>.generate(countTri * 3, (k) {
          final ti = idx[startI + (k ~/ 3)];
          final vi = _tri[ti * 3 + (k % 3)];
          final c = _col[vi];
          final a = ((c >> 24) & 0xFF);
          final r = ((c >> 16) & 0xFF);
          final g = ((c >> 8) & 0xFF);
          final bl = (c & 0xFF);
          final aa = (a * alphaMul).round().clamp(0, 255);
          return ui.Color((aa << 24) | (r << 16) | (g << 8) | bl);
        }),
      );
      canvas.drawVertices(verts, ui.BlendMode.modulate, ui.Paint());
      verts.dispose();
    }
  }
}
