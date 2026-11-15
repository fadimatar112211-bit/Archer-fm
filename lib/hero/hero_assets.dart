import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import 'hero_manifest.dart';

/// A decoded atlas image plus the source rectangle of every frame in it.
class AtlasSheet {
  AtlasSheet({
    required this.image,
    required this.frames,
    required this.width,
    required this.height,
  });

  final ui.Image image;
  final Map<String, ui.Rect> frames;
  final int width;
  final int height;

  ui.Rect? rectFor(String frameId) => frames[frameId];

  void dispose() {
    image.dispose();
  }
}

/// Indirection so widget tests can supply a manifest without touching assets.
abstract class HeroAssetLoader {
  Future<HeroManifest> loadManifest();

  Future<AtlasSheet> loadSheet(HeroManifest manifest, String animation);

  void dispose() {}
}

class BundleHeroAssetLoader implements HeroAssetLoader {
  static const String assetRoot = 'assets/heroes/ranger/renders';
  static const String manifestPath = '$assetRoot/ranger_manifest.json';

  final Map<String, AtlasSheet> _cache = {};

  @override
  Future<HeroManifest> loadManifest() async {
    final text = await rootBundle.loadString(manifestPath);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Ranger manifest root must be an object');
    }
    return HeroManifest.fromJson(decoded);
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
    final imageData = await rootBundle.load('$assetRoot/${entry.image}');
    final bytes = imageData.buffer.asUint8List(
      imageData.offsetInBytes,
      imageData.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;

    final framesJson = encodedMeta['frames'];
    if (framesJson is! Map) {
      image.dispose();
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
    );
    _cache[animation] = sheet;
    return sheet;
  }

  @override
  void dispose() {
    for (final sheet in _cache.values) {
      sheet.dispose();
    }
    _cache.clear();
  }
}
