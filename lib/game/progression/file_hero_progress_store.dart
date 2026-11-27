import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hero_progress.dart';
import 'hero_progress_store.dart';

/// Single-node development persistence adapter.
/// 
/// The account ID must come from a trusted authenticated session. This class
/// is not an authentication system and is not a substitute for cloud/database
/// persistence in production. It adapts atomic JSON-file storage to the
/// canonical Archer FM progression model.
class FileHeroProgressStore implements HeroProgressStore {
  FileHeroProgressStore(this.directory);

  final Directory directory;
  final Map<String, Future<void>> _writeQueue = {};

  String _keyFor(String accountId) {
    if (accountId.trim().isEmpty || accountId.length > 180) {
      throw ArgumentError.value(accountId, 'accountId', 'Account ID must be 1 to 180 characters.');
    }
    return base64Url.encode(utf8.encode(accountId)).replaceAll('=', '');
  }

  File _fileFor(String key) => File(
        '${directory.path}${Platform.pathSeparator}$key.progress.json',
      );

  @override
  Future<HeroProgress> load(String accountId) async {
    final key = _keyFor(accountId);
    await (_writeQueue[key] ?? Future<void>.value());
    final file = _fileFor(key);
    if (!await file.exists()) return HeroProgress.fresh();

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid progression file.');
    }
    return HeroProgress.fromJson(decoded);
  }

  @override
  Future<void> save(String accountId, HeroProgress progress) async {
    final key = _keyFor(accountId);
    final previous = _writeQueue[key] ?? Future<void>.value();
    final next = previous.then<void>(
      (_) => _writeAtomically(key, progress),
      onError: (_) => _writeAtomically(key, progress),
    );
    _writeQueue[key] = next;
    try {
      await next;
    } finally {
      if (identical(_writeQueue[key], next)) _writeQueue.remove(key);
    }
  }

  Future<void> _writeAtomically(String key, HeroProgress progress) async {
    await directory.create(recursive: true);
    final destination = _fileFor(key);
    final temporary = File(
      '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(
        jsonEncode(progress.toJson()),
        flush: true,
      );
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
