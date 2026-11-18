import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local player identity used by rooms, invites and the pre-match screen.
class PlayerProfile {
  const PlayerProfile({
    required this.username,
    required this.displayName,
    this.profilePicture = 'default',
    this.colorValue = 0xFF9BE845,
    this.wins = 0,
    this.losses = 0,
    this.kills = 0,
    this.matches = 0,
  });

  final String username;
  final String displayName;

  /// Asset id/color key chosen by the player. No external images are bundled.
  final String profilePicture;
  final int colorValue;
  final int wins;
  final int losses;
  final int kills;
  final int matches;

  PlayerProfile copyWith({
    String? username,
    String? displayName,
    String? profilePicture,
    int? colorValue,
    int? wins,
    int? losses,
    int? kills,
    int? matches,
  }) => PlayerProfile(
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        profilePicture: profilePicture ?? this.profilePicture,
        colorValue: colorValue ?? this.colorValue,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        kills: kills ?? this.kills,
        matches: matches ?? this.matches,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'profilePicture': profilePicture,
        'colorValue': colorValue,
        'wins': wins,
        'losses': losses,
        'kills': kills,
        'matches': matches,
      };

  static PlayerProfile? fromJson(Map<String, dynamic> json) {
    final username = json['username'];
    final displayName = json['displayName'];
    final picture = json['profilePicture'];
    final color = json['colorValue'];
    if (username is! String ||
        displayName is! String ||
        picture is! String ||
        color is! int) {
      return null;
    }
    return PlayerProfile(
      username: username,
      displayName: displayName,
      profilePicture: picture,
      colorValue: color,
      wins: json['wins'] is int ? json['wins'] as int : 0,
      losses: json['losses'] is int ? json['losses'] as int : 0,
      kills: json['kills'] is int ? json['kills'] as int : 0,
      matches: json['matches'] is int ? json['matches'] as int : 0,
    );
  }
}

/// Storage contract so social flows are testable without platform channels.
abstract class SocialStore {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
}

class MemorySocialStore implements SocialStore {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      Map<String, dynamic>.from(_data[key] ?? const {});

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _data[key] = Map<String, dynamic>.from(value);
  }
}

class SharedPreferencesSocialStore implements SocialStore {
  static const prefix = 'archer_fm.social.';

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$prefix$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$prefix$key', jsonEncode(value));
  }
}

enum FriendRequestState { pending, accepted, declined }

class FriendRequest {
  const FriendRequest({
    required this.from,
    required this.to,
    required this.state,
  });

  final String from;
  final String to;
  final FriendRequestState state;

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'state': state.name,
      };

  static FriendRequest? fromJson(Map<String, dynamic> json) {
    final from = json['from'];
    final to = json['to'];
    if (from is! String || to is! String) return null;
    return FriendRequest(
      from: from,
      to: to,
      state: FriendRequestState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => FriendRequestState.pending,
      ),
    );
  }
}

/// Username/password accounts, profiles and the confirmed social features:
/// friends, requests with accept/decline, username search, and opponent stats.
///
/// Google/Apple sign-in needs external credentials and is intentionally not
/// faked here; see PROJECT_STATUS.md for the remaining work.
class SocialService {
  SocialService({SocialStore? store, this.currentUsername = ''})
      : _store = store ?? SharedPreferencesSocialStore();

  final SocialStore _store;
  String currentUsername;
  final Map<String, String> _passwords = {};
  final Map<String, PlayerProfile> _profiles = {};
  final List<FriendRequest> _requests = [];

  static const _usersKey = 'users';
  static const _requestsKey = 'requests';
  static const _currentKey = 'current';

  Future<void> load() async {
    final users = await _store.read(_usersKey);
    if (users != null) {
      for (final entry in users.entries) {
        if (entry.value is! Map<String, dynamic>) continue;
        final raw = entry.value as Map<String, dynamic>;
        final profile = PlayerProfile.fromJson(raw);
        final password = raw['password'];
        if (profile != null && password is String) {
          _profiles[entry.key] = profile;
          _passwords[entry.key] = password;
        }
      }
    }
    final requests = await _store.read(_requestsKey);
    final rawRequests = requests?['items'];
    if (rawRequests is List) {
      _requests.clear();
      for (final raw in rawRequests) {
        if (raw is! Map<String, dynamic>) continue;
        final request = FriendRequest.fromJson(raw);
        if (request != null) _requests.add(request);
      }
    }
    final current = await _store.read(_currentKey);
    if (current?['username'] is String) {
      currentUsername = current!['username'] as String;
    }
  }

  Future<void> _saveUsers() async {
    await _store.write(_usersKey, {
      for (final entry in _profiles.entries)
        entry.key: {
          ...entry.value.toJson(),
          'password': _passwords[entry.key],
        },
    });
  }

  Future<void> _saveRequests() async {
    await _store.write(_requestsKey, {
      'items': [for (final request in _requests) request.toJson()],
    });
  }

  /// Creates a local account or signs in an existing one.
  /// Passwords are stored locally for this offline prototype only; a real
  /// deployment needs the backend that PROJECT_STATUS.md still leaves open.
  Future<bool> signIn(String username, String password) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) return false;
    final existing = _profiles[normalized];
    if (existing != null) {
      if (_passwords[normalized] != password) return false;
    } else {
      _profiles[normalized] = PlayerProfile(
        username: normalized,
        displayName: username.trim(),
      );
      _passwords[normalized] = password;
      await _saveUsers();
    }
    currentUsername = normalized;
    await _store.write(_currentKey, {'username': normalized});
    return true;
  }

  Future<void> signOut() async {
    currentUsername = '';
    await _store.write(_currentKey, {'username': ''});
  }

  PlayerProfile? get current => _profiles[currentUsername];

  Iterable<PlayerProfile> get profiles => _profiles.values;

  List<PlayerProfile> searchByUsername(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return _profiles.values
        .where((profile) => profile.username.contains(needle))
        .toList();
  }

  PlayerProfile? profileOf(String username) => _profiles[username.toLowerCase()];

  List<PlayerProfile> get friends {
    final me = currentUsername;
    final names = <String>{};
    for (final request in _requests) {
      if (request.state != FriendRequestState.accepted) continue;
      if (request.from == me) names.add(request.to);
      if (request.to == me) names.add(request.from);
    }
    return [for (final name in names) if (_profiles[name] != null) _profiles[name]!];
  }

  List<FriendRequest> get incomingRequests => _requests
      .where((request) =>
          request.to == currentUsername &&
          request.state == FriendRequestState.pending)
      .toList();

  Future<bool> sendFriendRequest(String username) async {
    final target = username.trim().toLowerCase();
    if (target.isEmpty || target == currentUsername) return false;
    if (_profiles[target] == null) return false;
    final already = _requests.any((request) =>
        (request.from == currentUsername && request.to == target) ||
        (request.from == target && request.to == currentUsername));
    if (already) return false;
    _requests.add(
      FriendRequest(
        from: currentUsername,
        to: target,
        state: FriendRequestState.pending,
      ),
    );
    await _saveRequests();
    return true;
  }

  Future<bool> acceptFriendRequest(String from) async {
    final index = _requests.indexWhere((request) =>
        request.from == from &&
        request.to == currentUsername &&
        request.state == FriendRequestState.pending);
    if (index < 0) return false;
    final request = _requests[index];
    _requests[index] = FriendRequest(
      from: request.from,
      to: request.to,
      state: FriendRequestState.accepted,
    );
    await _saveRequests();
    return true;
  }

  Future<bool> declineFriendRequest(String from) async {
    final index = _requests.indexWhere((request) =>
        request.from == from &&
        request.to == currentUsername &&
        request.state == FriendRequestState.pending);
    if (index < 0) return false;
    final request = _requests[index];
    _requests[index] = FriendRequest(
      from: request.from,
      to: request.to,
      state: FriendRequestState.declined,
    );
    await _saveRequests();
    return true;
  }

  Future<void> updateProfilePicture(String picture) async {
    final profile = current;
    if (profile == null) return;
    _profiles[currentUsername] = profile.copyWith(profilePicture: picture);
    await _saveUsers();
  }

  /// Records a finished match for the signed-in player. A leave during an
  /// active match is a loss, while leaving an open room has no effect.
  Future<void> recordMatch({required bool won, required int kills}) async {
    final profile = current;
    if (profile == null) return;
    _profiles[currentUsername] = profile.copyWith(
      wins: profile.wins + (won ? 1 : 0),
      losses: profile.losses + (won ? 0 : 1),
      kills: profile.kills + kills,
      matches: profile.matches + 1,
    );
    await _saveUsers();
  }
}
