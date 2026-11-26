// أبطال 3D مباشر (CPU skinning + Canvas.drawVertices) بدون مكتبات للرسم.
// pubspec assets:  - assets/heroes3d/   و  - assets/audio/flame/
// final hero = Hero3D('ranger', height: 90); await hero.load();   // flame ranger shadow storm
// بكل إطار: hero.update(dt, joystick); hero.paint(canvas);
// attack() dash() ultimate(1..4) hurt(n) revive()  +  onHit, targets, onSound
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;

class _Clip {
  final int frames;
  final double secs;
  final bool loop;
  const _Clip(this.frames, this.secs, [this.loop = false]);
}

const Map<String, _Clip> _clips = {
  'idle': _Clip(6, 2.513, true), 'run': _Clip(8, .5712, true),
  'attack1': _Clip(6, .3), 'attack2': _Clip(6, .3), 'attack3': _Clip(6, .34),
  'attack4': _Clip(6, .4), 'attack5': _Clip(6, .65),
  'dash': _Clip(3, .25), 'hurt': _Clip(4, .4), 'death': _Clip(8, 1.2),
  'ult1': _Clip(8, .31416, true), 'ult2': _Clip(10, 2.2),
  'ult3': _Clip(8, 1.1), 'ult4': _Clip(14, 1.8),
};

class _Fx {
  _Fx(this.type, this.at, this.r, this.life, this.angle, this.vel);
  final String type;
  final ui.Offset at, vel;
  final double r, life, angle;
  double age = 0;
}

class _Timed {
  _Timed(this.wait, this.run);
  double wait;
  final void Function() run;
}

class Hero3D {
  Hero3D(this.id, {this.height = 90});
  final String id;
  bool get _ranged => id == 'ranger' || id == 'storm';
  ui.Color _tint(double a, [bool light = false]) {
    final c = const {'flame': [0xff7814, 0xffeb82], 'ranger': [0x4be132, 0xebffb0], 'shadow': [0x9b3cff, 0xf0c8ff], 'storm': [0x2896ff, 0xdff6ff]}[id]![light ? 1 : 0];
    return ui.Color(0xff000000 | c).withValues(alpha: a.clamp(0.0, 1.0).toDouble());
  }
  double height;
  ui.Offset position = ui.Offset.zero; // موضع القدمين
  int hp = 100;
  String anim = 'idle';
  double _t = 0, _step = 0;
  double _heading = 0, _yaw = 0;
  int _combo = 0;
  bool _queued = false;
  int _n = 0;
  Map<String, dynamic> _anims = {};
  late Float32List _pos, _mats, _xy, _depth;
  late Int32List _col;
  late Uint8List _skin;
  late Uint16List _tri, _out, _order;
  final Float32List _bones = Float32List(144);
  final Int32List _bucket = Int32List(256);
  final List<_Fx> _fx = [];
  List<_Timed> _timers = [];
  final Random _rng = Random();

  void Function(ui.Offset center, double radius, int damage)? onHit;
  void Function(String sound)? onSound;
  List<ui.Offset> Function()? targets;

  bool get isDead => anim == 'death';
  bool get isReady => _n > 0;
  bool get _free => anim == 'idle' || anim == 'run';
  ui.Offset get aim => ui.Offset(sin(_heading), cos(_heading));

  Future<void> load([String folder = 'assets/heroes3d']) async {
    final data = await rootBundle.load('$folder/$id.bin');
    final raw = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final bytes = raw.offsetInBytes % 4 == 0 ? raw : Uint8List.fromList(raw);
    final buf = bytes.buffer;
    final base = bytes.offsetInBytes;
    final headLength = ByteData.view(buf, base, bytes.lengthInBytes).getUint32(0, Endian.little);
    final head = jsonDecode(utf8.decode(bytes.sublist(4, 4 + headLength))) as Map<String, dynamic>;
    final n = head['n'] as int, t = head['t'] as int;
    _anims = head['clips'] as Map<String, dynamic>;
    var at = (4 + headLength + 3) & ~3;
    int take(int size) {
      final start = at;
      at += (size + 3) & ~3;
      return base + start;
    }
    _pos = buf.asFloat32List(take(n * 12), n * 3);
    _col = buf.asInt32List(take(n * 4), n);
    _skin = buf.asUint8List(take(n * 3), n * 3);
    _tri = buf.asUint16List(take(t * 6), t * 3);
    _mats = buf.asFloat32List(at);
    _xy = Float32List(n * 2);
    _depth = Float32List(n);
    _out = Uint16List(t * 3);
    _order = Uint16List(t);
    _n = n;
  }

  void dispose() {
    _n = 0;
  }

  void face(ui.Offset v) {
    if (v.distance > .1) _heading = atan2(v.dx, v.dy);
  }

  void _set(String name) {
    anim = name;
    _t = 0;
  }

  void _after(double s, void Function() f) => _timers.add(_Timed(s, f));

  void _add(String type, ui.Offset at, double r, double life,
          [double angle = 0, ui.Offset vel = ui.Offset.zero]) =>
      _fx.add(_Fx(type, at, r, life, angle, vel));

  void _hit(ui.Offset c, double r, int damage) => onHit?.call(c, r * height, damage);

  void _blast(ui.Offset at, double r) {
    onSound?.call('boom');
    _add('ring', at, r, .45);
    for (var i = 0; i < 16; i++) {
      final a = _rng.nextDouble() * pi * 2;
      _add('spark', at, .06, .5, 0, ui.Offset(cos(a), sin(a) * .6 - .5) * (height * 1.3));
    }
  }

  void attack() {
    if (anim.startsWith('attack')) {
      _queued = true;
    } else if (_free) {
      _combo = 0;
      _strike();
    }
  }

  void _strike() {
    final i = _combo;
    _queued = false;
    _set('attack${i + 1}');
    _after(const [.1, .1, .12, .15, .3][i], () {
      onSound?.call('swish');
      final c = position + aim * (height * .33);
      if (_ranged) {
        final dir = aim, start = position;
        _add('shot', start + dir * (height * .35), i == 4 ? .16 : .09, .4, 0, dir * (height * 6));
        for (var k = 0; k < 4; k++) {
          _after(k * .09, () => _hit(start + dir * (height * (.6 + k * .65)), .32, const [10, 12, 15, 20, 40][i]));
        }
        return;
      }
      _add('arc', c, .45 + i * .08, .28, atan2(aim.dy, aim.dx));
      if (i == 4) _blast(c, .81);
      _hit(c, i == 4 ? .81 : .52, const [10, 12, 15, 20, 40][i]);
    });
  }

  bool dash() {
    if (!_free) return false;
    onSound?.call('swish');
    _set('dash');
    return true;
  }

  bool ultimate(int n) {
    if (!_free || n < 1 || n > 4) return false;
    _set('ult$n');
    onSound?.call('charge');
    _add('ring', position, .5, .5);
    final origin = position;
    final dir = aim;
    if (n == 1) {
      for (var i = 0; i < 9; i++) {
        _after(.2 + i * .19, () {
          onSound?.call('swish');
          _add('ring', position, .75, .3);
          _hit(position, .81, 14);
        });
      }
    } else if (n == 2) {
      for (var i = 0; i < 12; i++) {
        _after(.3 + i * .13, () {
          final foes = targets?.call() ?? const <ui.Offset>[];
          final base = foes.isEmpty ? origin + dir * height : foes[i % foes.length];
          final spot = base +
              ui.Offset((_rng.nextDouble() - .5) * height * .4,
                  (_rng.nextDouble() - .5) * height * .25);
          _add('meteor', spot, .12, .4);
          _after(.4, () {
            _blast(spot, .43);
            _hit(spot, .43, 25);
          });
        });
      }
    } else if (n == 3) {
      for (var i = 0; i < 10; i++) {
        _after(.45 + i * .06, () {
          final p = origin + dir * (height * (.29 + i * .26));
          if (i == 0) _blast(p, .5);
          _add('pillar', p, .2 + i * .015, .35);
          _hit(p, .57, 18);
        });
      }
    } else {
      for (var k = 0; k < 3; k++) {
        _after(.4 + k * .38, () {
          _blast(position, .52 + k * .4);
          final count = 6 + k * 3;
          for (var i = 0; i < count; i++) {
            final a = i / count * pi * 2;
            final off = ui.Offset(cos(a) * (.38 + k * .36), sin(a) * (.21 + k * .19));
            _add('pillar', position + off * height, .12, .55);
          }
          _hit(position, .52 + k * .4, 30);
        });
      }
    }
    return true;
  }

  void hurt(int damage) {
    if (isDead) return;
    hp = max(0, hp - damage);
    _timers.clear();
    _queued = false;
    onSound?.call(hp > 0 ? 'hurt' : 'death');
    if (hp > 0) {
      onSound?.call('hit');
    }
    _set(hp > 0 ? 'hurt' : 'death');
  }

  void revive([int health = 100]) {
    hp = health;
    _timers.clear();
    _set('idle');
  }

  void update(double dt, [ui.Offset move = ui.Offset.zero]) {
    _t += dt;
    _yaw += atan2(sin(_heading - _yaw), cos(_heading - _yaw)) * (1 - exp(-dt * 14));
    final moving = move.distance > .15;
    final m = move.distance > 1 ? move / move.distance : move;
    if (_free || anim == 'ult1') {
      if (moving) position += m * (height * 1.05 * dt);
      if (_free) {
        if (moving) face(move);
        final next = moving ? 'run' : 'idle';
        if (next != anim) _set(next);
        if (moving) {
          _step += dt;
          if (_step > .285) {
            _step = 0;
            onSound?.call('step');
          }
        }
      }
    }
    if (anim == 'dash') position += aim * (height * 3.6 * dt);
    if (anim.startsWith('attack') && _t < .12) position += aim * (height * .85 * dt);
    final pending = _timers;
    _timers = [];
    for (final timer in pending) {
      timer.wait -= dt;
      if (timer.wait <= 0) {
        timer.run();
      } else {
        _timers.add(timer);
      }
    }
    for (final f in _fx) {
      f.age += dt;
    }
    _fx.removeWhere((f) => f.age >= f.life);
    final clip = _clips[anim]!;
    final end = anim == 'ult1' ? 2.0 : (clip.loop || isDead ? double.infinity : clip.secs);
    if (_t >= end) {
      if (anim.startsWith('attack') && _queued && _combo < 4) {
        _combo++;
        _strike();
      } else {
        _queued = false;
        _set('idle');
      }
    }
  }

  void paint(ui.Canvas canvas) {
    if (!isReady) return;
    final clip = _clips[anim]!;
    final range = _anims[anim] as List<dynamic>;
    final start = range[0] as int, count = range[1] as int;
    var u = _t / clip.secs;
    u = clip.loop ? u % 1 : u.clamp(0.0, 1.0).toDouble();
    final f = u * (clip.loop ? count : count - 1);
    final i0 = min(f.floor(), count - 1);
    final i1 = clip.loop ? (i0 + 1) % count : min(i0 + 1, count - 1);
    final w = f - i0;
    for (var k = 0; k < 144; k++) {
      final x = _mats[(start + i0) * 144 + k];
      _bones[k] = x + (_mats[(start + i1) * 144 + k] - x) * w;
    }
    final cy = cos(_yaw), sy = sin(_yaw), cp = cos(.3), sp = sin(.3);
    for (var v = 0; v < _n; v++) {
      final px = _pos[v * 3], py = _pos[v * 3 + 1], pz = _pos[v * 3 + 2];
      final a = _skin[v * 3] * 12, b = _skin[v * 3 + 1] * 12;
      final q = _skin[v * 3 + 2] / 255;
      double row(int r) {
        final m = _bones[a + r] * px + _bones[a + 3 + r] * py + _bones[a + 6 + r] * pz + _bones[a + 9 + r];
        final o = _bones[b + r] * px + _bones[b + 3 + r] * py + _bones[b + 6 + r] * pz + _bones[b + 9 + r];
        return m + (o - m) * q;
      }
      final x = row(0), y = row(1), z = row(2);
      final rx = cy * x + sy * z, rz = cy * z - sy * x;
      _xy[v * 2] = position.dx + rx * height;
      _xy[v * 2 + 1] = position.dy - (cp * y - sp * rz) * height;
      _depth[v] = sp * y + cp * rz;
    }
    // back-face culling + bucket depth sort (far to near)
    _bucket.fillRange(0, 256, 0);
    final keys = _order;
    final total = _tri.length ~/ 3;
    for (var t = 0; t < total; t++) {
      final a = _tri[t * 3], b = _tri[t * 3 + 1], c = _tri[t * 3 + 2];
      final area = (_xy[b * 2] - _xy[a * 2]) * (_xy[c * 2 + 1] - _xy[a * 2 + 1]) -
          (_xy[b * 2 + 1] - _xy[a * 2 + 1]) * (_xy[c * 2] - _xy[a * 2]);
      if (area >= 0) {
        keys[t] = 65535;
        continue;
      }
      final d = (((_depth[a] + _depth[b] + _depth[c]) / 3 + 1.6) * 80).toInt().clamp(0, 255).toInt();
      keys[t] = d;
      _bucket[d]++;
    }
    var sum = 0;
    for (var k = 0; k < 256; k++) {
      final c = _bucket[k];
      _bucket[k] = sum;
      sum += c;
    }
    for (var t = 0; t < total; t++) {
      final d = keys[t];
      if (d == 65535) continue;
      final o = _bucket[d]++ * 3;
      _out[o] = _tri[t * 3];
      _out[o + 1] = _tri[t * 3 + 1];
      _out[o + 2] = _tri[t * 3 + 2];
    }
    canvas.drawOval(
        ui.Rect.fromCenter(center: position, width: height * .6, height: height * .16),
        ui.Paint()..color = const ui.Color(0x66000000));
    final mesh = ui.Vertices.raw(ui.VertexMode.triangles, _xy,
        colors: _col, indices: Uint16List.sublistView(_out, 0, sum * 3));
    canvas.drawVertices(mesh, ui.BlendMode.modulate, ui.Paint()..color = const ui.Color(0xffffffff));
    mesh.dispose();
    for (final fx in _fx) {
      _paintFx(canvas, fx);
    }
  }

  void _paintFx(ui.Canvas canvas, _Fx f) {
    final u = (f.age / f.life).clamp(0.0, 1.0).toDouble();
    final r = f.r * height;
    final p = ui.Paint()
      ..blendMode = ui.BlendMode.plus
      ..color = _tint(1 - u * u);
    if (f.type == 'ring') {
      p
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = height * .07 * (1 - u) + 1;
      canvas.drawOval(
          ui.Rect.fromCenter(center: f.at, width: r * 2 * (.2 + u), height: r * .8 * (.2 + u)), p);
    } else if (f.type == 'arc') {
      final box = ui.Rect.fromCircle(center: f.at.translate(0, -height * .38), radius: r);
      p
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = height * .12 * (1 - u * .6);
      canvas.drawArc(box, f.angle - 1.5 + u, 2 + u * .6, false, p);
      p
        ..color = _tint(1 - u, true)
        ..strokeWidth = height * .03;
      canvas.drawArc(box, f.angle - 1.5 + u, 2 + u * .6, false, p);
    } else if (f.type == 'spark') {
      canvas.drawCircle(f.at + f.vel * f.age, r * (1 - u), p);
    } else if (f.type == 'shot') {
      final head = f.at + f.vel * f.age;
      if (id == 'ranger') {
        p..strokeWidth = r * .4..strokeCap = ui.StrokeCap.round;
        canvas.drawLine((head - f.vel * .07).translate(0, -height * .45), head.translate(0, -height * .45), p);
      }
      canvas.drawCircle(head.translate(0, -height * .45), r * (id == 'storm' ? 1 : .35), p);
    } else if (f.type == 'meteor' && id != 'flame') {
      final at = f.at.translate(0, -height * 2 * (1 - u));
      final path = ui.Path()..moveTo(at.dx, at.dy);
      for (var k = 1; k <= 5; k++) {
        path.lineTo(at.dx + (id == 'storm' ? (k.isOdd ? 1 : -1) * height * .09 : 0), at.dy - height * .18 * k);
      }
      p..style = ui.PaintingStyle.stroke..strokeWidth = height * (id == 'shadow' ? .07 : .035);
      canvas.drawPath(path, p);
    } else {
      final meteor = f.type == 'meteor';
      final at = f.at.translate(0, meteor ? -height * 2 * (1 - u) : 0);
      final tall = meteor ? height * .6 : height * 1.05 * sin(u * pi);
      final path = ui.Path()
        ..moveTo(at.dx - r, at.dy)
        ..lineTo(at.dx + (meteor ? height * .3 : 0), at.dy - tall)
        ..lineTo(at.dx + r, at.dy)
        ..close();
      canvas.drawPath(path, p);
      canvas.drawCircle(at, r, p);
    }
  }
}
