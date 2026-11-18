import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'match_models.dart';
import 'protocol.dart';

/// Client-side view of the room/match. Network events are surfaced to the UI
/// through [onEvent] while the authoritative state is kept on the host.
class OnlineMatchClient {
  OnlineMatchClient({
    required NetTransport transport,
    required this.username,
    required this.heroId,
    this.onEvent,
  }) : _transport = transport {
    _subscription = _transport.messages.listen(_handle);
  }

  final NetTransport _transport;
  final String username;
  final String heroId;
  final void Function(String type, Map<String, dynamic> data)? onEvent;
  late final StreamSubscription<Map<String, dynamic>> _subscription;

  String? playerId;
  MatchRoom? room;
  int? seed;
  int elapsedMs = 0;
  List<MatchPlayer> players = const [];
  MatchResult? result;
  MatchDuration selectedDuration = MatchDuration.m10;
  MatchEndReason? pendingEnd;

  bool get connected => _transport.connected;
  bool get isHost => room?.ownerId == playerId;

  /// Raw network messages, used by the in-match overlay for HUD updates and
  /// disconnection handling.
  Stream<Map<String, dynamic>> get messages => _transport.messages;

  static Future<OnlineMatchClient> connect({
    required String host,
    required int port,
    required String username,
    required String heroId,
    void Function(String type, Map<String, dynamic> data)? onEvent,
  }) async {
    final socket = await Socket.connect(host, port);
    return OnlineMatchClient(
      transport: SocketTransport(socket),
      username: username,
      heroId: heroId,
      onEvent: onEvent,
    );
  }

  void _send(String type, [Map<String, dynamic>? data]) {
    _transport.send(envelope(type, payload: data));
  }

  void hello({String roomCode = ''}) => _send(NetMessage.hello, {
        'username': username,
        'heroId': heroId,
        'roomCode': roomCode,
      });

  void createRoom(MatchDuration duration) {
    selectedDuration = duration;
    _send(NetMessage.createRoom, {
      'username': username,
      'heroId': heroId,
      'duration': duration.minutes,
    });
  }

  void joinRoom(String code) => _send(NetMessage.joinRoom, {
        'code': code.toUpperCase(),
        'username': username,
        'heroId': heroId,
      });

  void queue(MatchDuration duration) {
    selectedDuration = duration;
    _send(NetMessage.queue, {
      'username': username,
      'heroId': heroId,
      'duration': duration.minutes,
    });
  }

  void setHero(String heroId) {
    _send(NetMessage.setHero, {'heroId': heroId});
  }

  void ready(bool value) => _send(NetMessage.ready, {'ready': value});

  void invite(String username) => _send(NetMessage.invite, {'username': username});

  void removePlayer(String id) =>
      _send(NetMessage.removePlayer, {'playerId': id});

  void leave() => _send(NetMessage.leaveRoom);

  /// Leaving an active match counts as a loss; the host broadcasts the result.
  void leaveMatch() => _send(NetMessage.leaveMatch);

  void startMatch() => _send(NetMessage.matchStart);

  void sendInput(Offset position, int atMs) => _send(NetMessage.input, {
        'x': position.dx,
        'y': position.dy,
        'atMs': atMs,
      });

  void sendAttack({
    required String targetId,
    required double amount,
    required double maxDamage,
    double? distance,
  }) =>
      _send(NetMessage.attack, {
        'targetId': targetId,
        'amount': amount,
        'maxDamage': maxDamage,
        'distance': distance,
      });

  void sendCrystal(String ownerId) =>
      _send(NetMessage.crystal, {'ownerId': ownerId});

  void sendPickup(Offset position, int amount) => _send(NetMessage.pickup, {
        'x': position.dx,
        'y': position.dy,
        'amount': amount,
      });

  void _handle(Map<String, dynamic> message) {
    if (!validEnvelope(message)) return;
    final type = message['type'] as String;
    switch (type) {
      case NetMessage.welcome:
        final id = message['playerId'];
        if (id is String) playerId = id;
        final incomingSeed = message['seed'];
        if (incomingSeed is int) seed = incomingSeed;
        _setRoom(message['room']);
      case NetMessage.roomState:
        _setRoom(message['room']);
      case NetMessage.matchStart:
        final incomingSeed = message['seed'];
        if (incomingSeed is int) seed = incomingSeed;
        final minutes = message['duration'];
        if (minutes is int) {
          selectedDuration = MatchDuration.fromMinutes(minutes) ?? selectedDuration;
        }
        players = playersFromMessage(message);
      case NetMessage.snapshot:
        players = playersFromMessage(message);
        final elapsed = message['elapsedMs'];
        if (elapsed is int) elapsedMs = elapsed;
      case NetMessage.matchEnd:
        final raw = message['result'];
        if (raw is Map<String, dynamic>) result = MatchResult.fromJson(raw);
      case NetMessage.playerLeft:
        // A leave during an active match is a loss; the host publishes the
        // final result immediately afterwards.
        pendingEnd = MatchEndReason.timeUp;
      default:
        break;
    }
    onEvent?.call(type, message);
  }

  void _setRoom(Object? raw) {
    if (raw is! Map<String, dynamic>) return;
    room = MatchRoom.fromJson(raw);
    if (room != null) {
      players = List<MatchPlayer>.of(room!.players);
      selectedDuration = room!.duration;
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _transport.close();
  }
}
