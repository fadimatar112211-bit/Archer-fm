/// Parsed sprite-sheet manifest produced by `tools/blender/render_hero.py`.
///
/// The manifest is the contract between the Blender pipeline and the game: it
/// names every animation (`<state>_<direction>`), the ordered frame ids, the
/// frame duration, gameplay events, and the atlas files that hold the pixels.
class HeroManifest {
  HeroManifest({
    required this.heroId,
    required this.frameWidth,
    required this.frameHeight,
    required this.pivotX,
    required this.pivotY,
    required this.clips,
    required this.atlases,
    required this.fps,
  });

  final String heroId;
  final int frameWidth;
  final int frameHeight;
  final double pivotX;
  final double pivotY;
  final int fps;
  final Map<String, AnimationClip> clips;
  final List<AtlasEntry> atlases;

  AnimationClip? clipFor(String state, String direction) =>
      clips['${state}_$direction'];

  AtlasEntry? atlasFor(String animation) {
    for (final atlas in atlases) {
      if (atlas.animation == animation) return atlas;
    }
    return null;
  }

  factory HeroManifest.fromJson(Map<String, dynamic> json) {
    final heroId = json['hero_id'];
    if (heroId is! String || heroId.isEmpty) {
      throw const FormatException('hero_id must be a non-empty string');
    }
    final frameSize = json['frame_size'];
    if (frameSize is! Map) {
      throw const FormatException('frame_size must be an object');
    }
    final frameWidth = _requireInt(frameSize['width'], 'frame_size.width');
    final frameHeight = _requireInt(frameSize['height'], 'frame_size.height');
    if (frameWidth < 1 || frameHeight < 1) {
      throw const FormatException('frame_size must be positive');
    }
    final pivot = json['pivot'];
    if (pivot is! Map) {
      throw const FormatException('pivot must be an object');
    }
    final pivotX = _requireNumber(pivot['x'], 'pivot.x');
    final pivotY = _requireNumber(pivot['y'], 'pivot.y');
    if (pivotX < 0 || pivotX > 1 || pivotY < 0 || pivotY > 1) {
      throw const FormatException('pivot must be normalized between 0 and 1');
    }
    final source = json['source'];
    final fps = source is Map ? _optionalInt(source['fps'], 12) : 12;

    final animationsJson = json['animations'];
    if (animationsJson is! Map || animationsJson.isEmpty) {
      throw const FormatException('animations must be a non-empty object');
    }
    final clips = <String, AnimationClip>{};
    for (final entry in animationsJson.entries) {
      final name = entry.key;
      final value = entry.value;
      if (name is! String || value is! Map) {
        throw const FormatException('animations entries must be named objects');
      }
      clips[name] = AnimationClip.fromJson(name, value.cast<String, dynamic>());
    }

    final atlasesJson = json['atlases'];
    if (atlasesJson is! List || atlasesJson.isEmpty) {
      throw const FormatException('atlases must be a non-empty array');
    }
    final atlases = <AtlasEntry>[];
    for (final entry in atlasesJson) {
      if (entry is! Map) {
        throw const FormatException('atlas entries must be objects');
      }
      final animation = entry['animation'];
      final image = entry['image'];
      final meta = entry['meta'];
      if (animation is! String || image is! String || meta is! String) {
        throw const FormatException('atlas entries need animation, image and meta');
      }
      atlases.add(AtlasEntry(animation: animation, image: image, meta: meta));
    }

    return HeroManifest(
      heroId: heroId,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      pivotX: pivotX,
      pivotY: pivotY,
      clips: clips,
      atlases: atlases,
      fps: fps,
    );
  }
}

class AnimationClip {
  AnimationClip({
    required this.name,
    required this.loop,
    required this.frameDurationMs,
    required this.frames,
    required this.events,
  });

  final String name;
  final bool loop;
  final int frameDurationMs;
  final List<String> frames;
  final List<AnimationEvent> events;

  factory AnimationClip.fromJson(String name, Map<String, dynamic> json) {
    final loop = json['loop'];
    if (loop is! bool) {
      throw FormatException('$name.loop must be a boolean');
    }
    final duration = json['frame_duration_ms'];
    if (duration is! int || duration < 1) {
      throw FormatException('$name.frame_duration_ms must be a positive integer');
    }
    final framesJson = json['frames'];
    // A looping one-frame clip is a valid static pose (for example, Shadow's
    // current user-approved directional idle frame). Non-looping actions need
    // at least two frames so their timing/events can advance meaningfully.
    if (framesJson is! List ||
        framesJson.isEmpty ||
        (!loop && framesJson.length < 2)) {
      throw FormatException(
        '$name.frames must contain at least one frame; non-looping clips '
        'must contain at least two',
      );
    }
    final frames = <String>[];
    for (final frame in framesJson) {
      if (frame is! String || frame.isEmpty) {
        throw FormatException('$name.frames must contain non-empty ids');
      }
      frames.add(frame);
    }
    final events = <AnimationEvent>[];
    final eventsJson = json['events'];
    if (eventsJson != null) {
      if (eventsJson is! List) {
        throw FormatException('$name.events must be an array');
      }
      for (final event in eventsJson) {
        if (event is! Map) {
          throw FormatException('$name.events entries must be objects');
        }
        final frame = event['frame'];
        final eventName = event['name'];
        if (frame is! int || frame < 0 || frame >= frames.length) {
          throw FormatException('$name event frame is out of range');
        }
        if (eventName is! String || eventName.isEmpty) {
          throw FormatException('$name event name must be non-empty');
        }
        events.add(AnimationEvent(frame: frame, name: eventName));
      }
    }
    return AnimationClip(
      name: name,
      loop: loop,
      frameDurationMs: duration,
      frames: frames,
      events: events,
    );
  }
}

class AnimationEvent {
  const AnimationEvent({required this.frame, required this.name});

  final int frame;
  final String name;
}

class AtlasEntry {
  const AtlasEntry({
    required this.animation,
    required this.image,
    required this.meta,
  });

  final String animation;
  final String image;
  final String meta;
}

int _requireInt(Object? value, String path) {
  if (value is int) return value;
  throw FormatException('$path must be an integer');
}

int _optionalInt(Object? value, int fallback) => value is int ? value : fallback;

double _requireNumber(Object? value, String path) {
  if (value is num) return value.toDouble();
  throw FormatException('$path must be a number');
}
