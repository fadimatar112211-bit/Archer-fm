import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import 'hero_catalog.dart';
import 'hero_manifest.dart';

/// A decoded atlas image plus the source rectangle of every frame in it.
class AtlasSheet {
  AtlasSheet({
    required this.image,
    required this.frames,
    required this.width,
    required this.height,
    this.ownsImage = true,
  });

  final ui.Image image;
  final bool ownsImage;
  final Map<String, ui.Rect> frames;
  final int width;
  final int height;

  ui.Rect? rectFor(String frameId) => frames[frameId];

  void dispose() {
    if (ownsImage) image.dispose();
  }
}

/// Indirection so widget tests can supply a manifest without touching assets.
abstract class HeroAssetLoader {
  /// Hero this loader serves, so the UI can label failures correctly.
  String get heroId;

  Future<HeroManifest> loadManifest();

  Future<AtlasSheet> loadSheet(HeroManifest manifest, String animation);

  void dispose() {}
}

/// Builds one loader per hero. The app swaps loaders when the player changes
/// hero so decoded atlases from the previous hero can be released immediately.
typedef HeroLoaderFactory = HeroAssetLoader Function(HeroDefinition hero);

HeroAssetLoader defaultHeroLoaderFactory(HeroDefinition hero) =>
    BundleHeroAssetLoader(hero);

/// Loads the manifest, atlas metadata and atlas bitmaps bundled under
/// `assets/heroes/<hero>/renders` by the Blender pipeline.
///
/// Every hero uses the same folder contract and the same frame geometry, so
/// only the root path differs between them.
class BundleHeroAssetLoader implements HeroAssetLoader {
  BundleHeroAssetLoader(this.hero);

  final HeroDefinition hero;

  final Map<String, AtlasSheet> _cache = {};

  // Multiple directional clips may reference one shared sprite sheet. Keep
  // one decoded ui.Image per asset path instead of decoding the same 4x8
  // Shadow atlas eight times (which would multiply GPU/CPU image memory).
  final Map<String, Future<ui.Image>> _imageCache = {};

  HeroManifest? _manifestCache;

  @override
  String get heroId => hero.id;

  String get assetRoot => hero.assetRoot;

  String get manifestPath => hero.manifestPath;

  @override
  Future<HeroManifest> loadManifest() async {
    final cached = _manifestCache;
    if (cached != null) return cached;
    final text = await rootBundle.loadString(manifestPath);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('${hero.id} manifest root must be an object');
    }
    return _manifestCache = HeroManifest.fromJson(decoded);
  }

  @override
  Future<AtlasSheet> loadSheet(HeroManifest manifest, String animation) async {
    final cached = _cache[animation];
    if (cached != null) return cached;
    final entry = manifest.atlasFor(animation);
    if (entry == null) {
      throw StateError('Manifest has no atlas for $animation');
    }
    final metaText = await rootBundle.loadString('$assetRoot/${entry.meta}');
    final encodedMeta = jsonDecode(metaText);
    if (encodedMeta is! Map<String, dynamic>) {
      throw FormatException('Atlas metadata for $animation must be an object');
    }
    final imagePath = '$assetRoot/${entry.image}';
    final image = await _loadSharedImage(imagePath);

    final framesJson = encodedMeta['frames'];
    if (framesJson is! Map) {
      throw FormatException('Atlas metadata for $animation has no frames');
    }
    final frames = <String, ui.Rect>{};
    for (final entry in framesJson.entries) {
      final frameId = entry.key;
      final value = entry.value;
      if (frameId is! String || value is! Map) continue;
      final rect = value['frame'];
      if (rect is! Map) continue;
      final x = rect['x'];
      final y = rect['y'];
      final w = rect['w'];
      final h = rect['h'];
      if (x is! int || y is! int || w is! int || h is! int) continue;
      frames[frameId] = ui.Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        w.toDouble(),
        h.toDouble(),
      );
    }
    final sheet = AtlasSheet(
      image: image,
      frames: frames,
      width: image.width,
      height: image.height,
      ownsImage: false,
    );
    _cache[animation] = sheet;
    return sheet;
  }

  Future<ui.Image> _loadSharedImage(String path) async {
    final future = _imageCache.putIfAbsent(path, () async {
      final imageData = await rootBundle.load(path);
      final bytes = imageData.buffer.asUint8List(
        imageData.offsetInBytes,
        imageData.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    });
    try {
      return await future;
    } catch (_) {
      if (identical(_imageCache[path], future)) _imageCache.remove(path);
      rethrow;
    }
  }

  @override
  void dispose() {
    for (final sheet in _cache.values) {
      sheet.dispose();
    }
    _cache.clear();
    // Dispose each shared image exactly once, including loads still in flight.
    for (final future in _imageCache.values) {
      future.then((image) => image.dispose(), onError: (_) {});
    }
    _imageCache.clear();
  }
}
