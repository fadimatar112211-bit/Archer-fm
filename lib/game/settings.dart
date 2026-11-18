import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Which side of the screen the attack/ability cluster sits on.
///
/// The requirement puts movement on the left and attacks on the right by
/// default; a left-handed player can swap them from the settings screen.
enum ControlSide { right, left }

extension ControlSideAr on ControlSide {
  String get labelAr => this == ControlSide.right ? 'يمين' : 'يسار';
}

/// Player-adjustable interface settings: control button size and position.
///
/// Defaults match the confirmed layout (movement left, attacks right,
/// medium button size). Values are clamped so a stray saved value can never
/// push the buttons off screen.
class GameSettings {
  const GameSettings({
    this.controlScale = 1.0,
    this.joystickScale = 1.0,
    this.controlSide = ControlSide.right,
    this.verticalOffset = 0.0,
  });

  /// Multiplier for the attack/dodge/ability button diameters (0.7–1.6).
  final double controlScale;

  /// Multiplier for the joystick base diameter (0.7–1.6).
  final double joystickScale;

  /// Side of the screen holding the attack cluster; the joystick takes the
  /// other side so movement and attacks never overlap.
  final ControlSide controlSide;

  /// Vertical nudge of the attack cluster in logical pixels (−80…80).
  final double verticalOffset;

  static const double minScale = 0.7;
  static const double maxScale = 1.6;
  static const double maxVerticalOffset = 80;

  GameSettings copyWith({
    double? controlScale,
    double? joystickScale,
    ControlSide? controlSide,
    double? verticalOffset,
  }) {
    return GameSettings(
      controlScale: controlScale ?? this.controlScale,
      joystickScale: joystickScale ?? this.joystickScale,
      controlSide: controlSide ?? this.controlSide,
      verticalOffset: verticalOffset ?? this.verticalOffset,
    );
  }

  Map<String, dynamic> toJson() => {
        'controlScale': controlScale,
        'joystickScale': joystickScale,
        'controlSide': controlSide.name,
        'verticalOffset': verticalOffset,
      };

  static GameSettings fromJson(Map<String, dynamic> data) {
    final rawScale = data['controlScale'];
    final rawJoy = data['joystickScale'];
    final rawSide = data['controlSide'];
    final rawOffset = data['verticalOffset'];
    return GameSettings(
      controlScale: _clamped(rawScale is num ? rawScale.toDouble() : 1.0,
          minScale, maxScale),
      joystickScale: _clamped(rawJoy is num ? rawJoy.toDouble() : 1.0,
          minScale, maxScale),
      controlSide: rawSide == 'left' ? ControlSide.left : ControlSide.right,
      verticalOffset: _clamped(
          rawOffset is num ? rawOffset.toDouble() : 0.0,
          -maxVerticalOffset,
          maxVerticalOffset),
    );
  }

  static double _clamped(double value, double lo, double hi) =>
      value < lo ? lo : (value > hi ? hi : value);
}

/// Storage abstraction so tests can inject an in-memory store.
abstract class SettingsStore {
  Future<GameSettings> load();
  Future<void> save(GameSettings settings);
}

/// Shared-preferences backed store used by the running app.
class SharedPreferencesSettingsStore implements SettingsStore {
  static const key = 'archer_fm.settings.controls';

  @override
  Future<GameSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const GameSettings();
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return const GameSettings();
      return GameSettings.fromJson(data);
    } on FormatException {
      return const GameSettings();
    }
  }

  @override
  Future<void> save(GameSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(settings.toJson()));
  }
}

/// In-memory store for widget tests.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._settings = const GameSettings()]);

  GameSettings _settings;

  @override
  Future<GameSettings> load() async => _settings;

  @override
  Future<void> save(GameSettings settings) async {
    _settings = settings;
  }
}
