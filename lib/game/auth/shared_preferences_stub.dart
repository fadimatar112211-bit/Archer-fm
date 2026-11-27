/// Stub for shared_preferences when package resolution is unavailable offline.
import 'dart:async';
class SharedPreferencesAsync {
  final Map<String, Object?> _store = {};
  Future<void> setString(String key, String value) async { _store[key] = value; }
  Future<String?> getString(String key) async => _store[key] as String?;
  Future<void> remove(String key) async { _store.remove(key); }
  Future<void> clear() async { _store.clear(); }
  Future<bool> containsKey(String key) async => _store.containsKey(key);
}
