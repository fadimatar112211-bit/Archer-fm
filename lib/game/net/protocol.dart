import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'match_models.dart';

/// Message names exchanged between the authoritative host and clients.
abstract final class NetMessage {
  static const hello = 'hello';
  static const welcome = 'welcome';
  static const roomState = 'roomState';
  static const createRoom = 'createRoom';
  static const joinRoom = 'joinRoom';
  static const queue = 'queue';
  static const setHero = 'setHero';
  static const ready = 'ready';
  static const invite = 'invite';
  static const removePlayer = 'removePlayer';
  static const leaveRoom = 'leaveRoom';
  static const leaveMatch = 'leaveMatch';
  static const matchStart = 'matchStart';
  static const input = 'input';
  static const attack = 'attack';
  static const crystal = 'crystal';
  static const pickup = 'pickup';
  static const snapshot = 'snapshot';
  static const matchEnd = 'matchEnd';
  static const playerLeft = 'playerLeft';
  static const error = 'error';

  /// Protocol version. Mismatched clients are rejected instead of silently
  /// interpreting unknown payloads.
  static const version = 1;
}

/// Minimal framed transport: one JSON object per line. This works over plain
/// TCP on LAN/hotspot and over any stream that provides the same framing.
abstract class NetTransport {
  Stream<Map<String, dynamic>> get messages;
  bool get connected;
  void send(Map<String, dynamic> message);
  Future<void> close();
}

class SocketTransport implements NetTransport {
  SocketTransport(this._socket) {
    _subscription = _socket.listen(
      (bytes) {
        _buffer += utf8.decode(bytes, allowMalformed: true);
        while (true) {
          final newline = _buffer.indexOf('\n');
          if (newline < 0) break;
          final line = _buffer.substring(0, newline);
          _buffer = _buffer.substring(newline + 1);
          final decoded = decodeLine(line.trimRight());
          if (decoded != null) _messages.add(decoded);
        }
      },
      onError: (Object error) => _messages.addError(error),
      onDone: () {
        _connected = false;
        _messages.close();
      },
    );
  }

  final Socket _socket;
  String _buffer = '';
  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();
  late final StreamSubscription<Uint8List> _subscription;
  bool _connected = true;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  bool get connected => _connected;

  @override
  void send(Map<String, dynamic> message) {
    if (!_connected) return;
    _socket.writeln(encodeLine(message));
  }

  @override
  Future<void> close() async {
    _connected = false;
    await _subscription.cancel();
    await _messages.close();
    _socket.destroy();
  }
}

/// In-memory client/server pair used by deterministic network tests. Each
/// client has its own server-side socket so the host knows which player sent
/// a message, exactly like a real TCP connection.
class LoopbackTransportPair {
  LoopbackTransportPair() {
    serverA = _LoopbackServerSide(this, isA: true);
    serverB = _LoopbackServerSide(this, isA: false);
    a = _LoopbackClientSide(this, isA: true);
    b = _LoopbackClientSide(this, isA: false);
  }

  late final NetTransport a;
  late final NetTransport b;
  late final NetTransport serverA;
  late final NetTransport serverB;

  final StreamController<Map<String, dynamic>> _fromA =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _fromB =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _toA =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _toB =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _closed = false;

  void sendFromClient({required bool isA, required Map<String, dynamic> message}) {
    if (_closed) return;
    (isA ? _fromA : _fromB).add(message);
  }

  void sendToClient({required bool isA, required Map<String, dynamic> message}) {
    if (_closed) return;
    (isA ? _toA : _toB).add(message);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait([
      _fromA.close(),
      _fromB.close(),
      _toA.close(),
      _toB.close(),
    ]);
  }
}

class _LoopbackClientSide implements NetTransport {
  _LoopbackClientSide(this._pair, {required this.isA});

  final LoopbackTransportPair _pair;
  final bool isA;

  @override
  Stream<Map<String, dynamic>> get messages => isA ? _pair._toA.stream : _pair._toB.stream;

  @override
  bool get connected => true;

  @override
  void send(Map<String, dynamic> message) {
    _pair.sendFromClient(isA: isA, message: message);
  }

  @override
  Future<void> close() async {}
}

class _LoopbackServerSide implements NetTransport {
  _LoopbackServerSide(this._pair, {required this.isA});

  final LoopbackTransportPair _pair;
  final bool isA;

  @override
  Stream<Map<String, dynamic>> get messages => isA ? _pair._fromA.stream : _pair._fromB.stream;

  @override
  bool get connected => true;

  @override
  void send(Map<String, dynamic> message) {
    _pair.sendToClient(isA: isA, message: message);
  }

  @override
  Future<void> close() async {}
}

/// Checks the envelope shared by every message.
bool validEnvelope(Map<String, dynamic> message) =>
    message['v'] == NetMessage.version && message['type'] is String;

Map<String, dynamic> envelope(String type, {Map<String, dynamic>? payload}) => {
      'v': NetMessage.version,
      'type': type,
      ...?payload,
    };

/// Small helper used by the UI to keep snapshots immutable.
List<MatchPlayer> playersFromMessage(Map<String, dynamic> message) {
  final raw = message['players'];
  if (raw is! List) return const [];
  final players = <MatchPlayer>[];
  for (final value in raw) {
    if (value is! Map<String, dynamic>) continue;
    final player = MatchPlayer.fromJson(value);
    if (player != null) players.add(player);
  }
  return players;
}

/// Exposed for socket tests that need a bound localhost port without leaving
/// a server running.
Future<ServerSocket> bindForTest({InternetAddress? address, int port = 0}) =>
    ServerSocket.bind(address ?? InternetAddress.loopbackIPv4, port);

@visibleForTesting
String describeTransport(NetTransport transport) => transport.runtimeType.toString();
