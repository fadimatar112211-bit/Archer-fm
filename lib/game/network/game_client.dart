import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../match/match_rules.dart';

/// Mobile WebSocket transport for Archer FM.
///
/// The server remains authoritative. This class only transports commands and
/// snapshots; it does not calculate movement, damage, rewards, or match rules.
/// Supported targets are Android and iOS (dart:io WebSocket).
enum GameConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  sessionExpired,
  closed,
}

class GameClient {
  GameClient(
    this.url, {
    this.onSession,
    this.profileKey,
    this.onProfile,
    this.accessTokenProvider,
    this.connectTimeout = const Duration(seconds: 8),
    this.maxReconnectDelay = const Duration(seconds: 30),
  });

  final String url;
  final Duration connectTimeout;
  final Duration maxReconnectDelay;

  /// Persist this opaque profile key only as a temporary development identity.
  /// Production identity must come from the account/authentication service.
  String? profileKey;
  final void Function(String key)? onProfile;
  /// Supplies a fresh Supabase access token for each socket handshake,
  /// including reconnects. Omit only for local development hosts.
  final Future<String?> Function()? accessTokenProvider;

  /// Persist the room code and resume token to support reconnect after app pause.
  final void Function(String code, String token)? onSession;

  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<GameConnectionState> _states =
      StreamController<GameConnectionState>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<GameConnectionState> get states => _states.stream;
  GameConnectionState _state = GameConnectionState.disconnected;
  GameConnectionState get state => _state;
  bool get isConnected => _state == GameConnectionState.connected;

  WebSocket? _socket;
  String? _roomCode;
  String? _resumeToken;
  int _sequence = 0;
  int _retryAttempt = 0;
  bool _disposed = false;
  bool _connecting = false;
  Timer? _reconnectTimer;

  /// Only durable, sequence-deduplicated commands are replayed after reconnect.
  /// Movement and combat inputs are intentionally dropped while disconnected.
  static const Set<String> _replayableTypes = {
    'select',
    'army_select',
    'unlock',
    'upgrade',
    'buy',
    'start',
  };
  final Map<int, Map<String, Object?>> _pendingReliable = {};

  void _setState(GameConnectionState value) {
    if (_state == value || _disposed) return;
    _state = value;
    _states.add(value);
    _messages.add({
      'type': 'connection',
      'state': value.name,
    });
  }

  Future<void> create({int durationMinutes = 30}) {
    MatchDuration.fromMinutes(durationMinutes);
    return _open({
      'type': 'create',
      'durationMinutes': durationMinutes,
      if (profileKey != null) 'profile': profileKey,
    });
  }

  Future<void> join(String code) => _open({
        'type': 'join',
        'code': code,
        if (profileKey != null) 'profile': profileKey,
      });

  Future<void> resume(String code, String token) {
    _roomCode = code;
    _resumeToken = token;
    return _open({
      'type': 'resume',
      'code': code,
      'token': token,
    });
  }

  Future<void> _open(Map<String, Object?> hello) async {
    if (_disposed || _connecting) return;
    _reconnectTimer?.cancel();
    _connecting = true;
    _setState(_retryAttempt == 0
        ? GameConnectionState.connecting
        : GameConnectionState.reconnecting);

    WebSocket? socket;
    try {
      final helloMessage = Map<String, Object?>.from(hello);
      final tokenProvider = accessTokenProvider;
      if (tokenProvider != null) {
        final accessToken = await tokenProvider().timeout(connectTimeout);
        if (accessToken == null || accessToken.isEmpty) {
          throw StateError('A valid signed-in session is required.');
        }
        helloMessage['accessToken'] = accessToken;
      }
      socket = await WebSocket.connect(url).timeout(connectTimeout);
      if (_disposed) {
        await socket.close();
        return;
      }
      final current = socket;
      _socket = current;
      current.pingInterval = const Duration(seconds: 5);
      current.listen(
        (raw) => _receive(current, raw),
        onDone: () => _lost(current),
        onError: (_) => _lost(current),
        cancelOnError: true,
      );
      current.add(jsonEncode(helloMessage));
    } catch (_) {
      if (socket != null) {
        try {
          await socket.close();
        } catch (_) {}
      }
      _connectionFailed();
    } finally {
      _connecting = false;
    }
  }

  void _receive(WebSocket source, dynamic raw) {
    if (_disposed || !identical(source, _socket) || raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _messages.add({'type': 'error', 'reason': 'invalid_server_message'});
        return;
      }
      final message = decoded;

      if (message['type'] == 'welcome') {
        _roomCode = message['code'] as String?;
        _resumeToken = message['token'] as String?;
        final receivedProfile = message['profile'];
        if (receivedProfile is String) {
          profileKey = receivedProfile;
          onProfile?.call(receivedProfile);
        }
        final lastSequence = message['lastSeq'];
        if (lastSequence is int) {
          if (lastSequence > _sequence) _sequence = lastSequence;
          _pendingReliable.removeWhere(
            (sequence, _) => sequence <= lastSequence,
          );
        }
        _retryAttempt = 0;
        _setState(GameConnectionState.connected);
        final code = _roomCode;
        final token = _resumeToken;
        if (code != null && token != null) onSession?.call(code, token);
        for (final pending in _pendingReliable.values.toList()) {
          if (identical(source, _socket) && source.readyState == WebSocket.open) {
            source.add(jsonEncode(pending));
          }
        }
      } else if (message['type'] == 'ack') {
        final sequence = message['seq'];
        if (sequence is int) _pendingReliable.remove(sequence);
      } else if (message['type'] == 'error' &&
          message['reason'] == 'no_session') {
        _resumeToken = null;
        _reconnectTimer?.cancel();
        _setState(GameConnectionState.sessionExpired);
      }

      _messages.add(message);
    } on FormatException {
      _messages.add({'type': 'error', 'reason': 'invalid_server_message'});
    } catch (_) {
      _messages.add({'type': 'error', 'reason': 'message_processing_failed'});
    }
  }

  void _lost(WebSocket source) {
    if (_disposed || !identical(source, _socket)) return;
    _socket = null;
    _connectionFailed();
  }

  void _connectionFailed() {
    if (_disposed || _state == GameConnectionState.sessionExpired) return;
    _setState(GameConnectionState.disconnected);
    final code = _roomCode;
    final token = _resumeToken;
    if (code == null || token == null) {
      _messages.add({'type': 'error', 'reason': 'connect_failed'});
      return;
    }
    _setState(GameConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    final exponent = _retryAttempt.clamp(0, 10).toInt();
    final seconds = 1 << exponent;
    final delay = Duration(seconds: seconds).compareTo(maxReconnectDelay) > 0
        ? maxReconnectDelay
        : Duration(seconds: seconds);
    if (_retryAttempt < 10) _retryAttempt++;
    _reconnectTimer = Timer(delay, () {
      if (!_disposed && !_connecting && _roomCode != null && _resumeToken != null) {
        resume(_roomCode!, _resumeToken!);
      }
    });
  }

  /// Returns false when disconnected. Movement and combat are never queued.
  bool send(String type, [Map<String, Object?> data = const {}]) {
    final socket = _socket;
    if (!isConnected || socket == null || socket.readyState != WebSocket.open) {
      return false;
    }
    final message = <String, Object?>{
      ...data,
      'type': type,
      'seq': ++_sequence,
    };
    if (_replayableTypes.contains(type)) {
      _pendingReliable[_sequence] = message;
    }
    try {
      socket.add(jsonEncode(message));
      return true;
    } catch (_) {
      if (_replayableTypes.contains(type)) {
        _pendingReliable.remove(_sequence);
      }
      _lost(socket);
      return false;
    }
  }

  Future<void> dispose({bool leave = false}) async {
    if (_disposed) return;
    if (leave) send('leave');
    _setState(GameConnectionState.closed);
    _disposed = true;
    _reconnectTimer?.cancel();
    final socket = _socket;
    _socket = null;
    try {
      await socket?.close();
    } catch (_) {}
    await _messages.close();
    await _states.close();
  }
}
