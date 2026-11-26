import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'monster_models.dart';
import 'monster_progression.dart';

/// Single-node persistence adapter for permanent monster levels.
///
/// The account ID must come from a trusted authenticated session. This file
/// store is suitable for development/single-node hosting, not as a replacement
/// for a production cloud database or distributed account store.
class FileMonsterProgressStore {
  FileMonsterProgressStore(this.directory);

  final Directory directory;
  final Map<String, Future<void>> _writeQueue = {};

  String _keyFor(String accountId) {
    if (accountId.trim().isEmpty || accountId.length > 180) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'Account ID must be 1 to 180 characters.',
      );
    }
    return base64Url.encode(utf8.encode(accountId)).replaceAll('=', '');
  }

  File _fileFor(String key) => File(
        '${directory.path}${Platform.pathSeparator}$key.monsters.json',
      );

  Future<Map<String, Object?>> loadData(String trustedAccountId) async {
    final key = _keyFor(trustedAccountId);
    await (_writeQueue[key] ?? Future<void>.value());
    final file = _fileFor(key);
    if (!await file.exists()) {
      return {
        'version': MonsterProgression.saveSchemaVersion,
        'levels': {for (final type in MonsterType.values) type.name: 1},
      };
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Invalid monster progression file.');
    }
    final data = <String, Object?>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw const FormatException('Monster progression keys must be strings.');
      }
      data[entry.key as String] = entry.value;
    }
    _validateSaveData(data);
    return data;
  }

  Future<void> save(
    String trustedAccountId,
    MonsterProgression progression,
  ) async {
    final key = _keyFor(trustedAccountId);
    final data = progression.toSaveData();
    _validateSaveData(data);
    final previous = _writeQueue[key] ?? Future<void>.value();
    final next = previous.then<void>(
      (_) => _writeAtomically(key, data),
      onError: (_) => _writeAtomically(key, data),
    );
    _writeQueue[key] = next;
    try {
      await next;
    } finally {
      if (identical(_writeQueue[key], next)) _writeQueue.remove(key);
    }
  }

  void _validateSaveData(Map<String, Object?> data) {
    if (data['version'] != MonsterProgression.saveSchemaVersion) {
      throw const FormatException('Unsupported monster progression save version.');
    }
    final rawLevels = data['levels'];
    if (rawLevels is! Map ||
        rawLevels.length != MonsterType.values.length) {
      throw const FormatException('Monster progression must save all four types.');
    }
    for (final type in MonsterType.values) {
      final level = rawLevels[type.name];
      if (level is! int || level < 1 || level > MonsterProgression.maxLevel) {
        throw FormatException('Invalid saved level for ${type.name}.');
      }
    }
    if (rawLevels.keys.any(
      (key) => key is! String ||
          !MonsterType.values.any((type) => type.name == key),
    )) {
      throw const FormatException('Monster progression contains an unknown type.');
    }
    if (data.keys.any((key) => key != 'version' && key != 'levels')) {
      throw const FormatException('Monster progression contains unknown fields.');
    }
  }

  Future<void> _writeAtomically(
    String key,
    Map<String, Object?> data,
  ) async {
    await directory.create(recursive: true);
    final destination = _fileFor(key);
    final temporary = File(
      '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(jsonEncode(data), flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
