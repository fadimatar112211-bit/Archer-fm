import 'package:flutter/material.dart';

import 'settings.dart';

/// Arabic settings screen: control button size, joystick size, control side
/// and vertical position. Changes save immediately through [store] and can be
/// reset to the confirmed default layout (movement left, attacks right).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.store});

  final SettingsStore? store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsStore store;
  GameSettings _settings = const GameSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    store = widget.store ?? SharedPreferencesSettingsStore();
    _load();
  }

  Future<void> _load() async {
    final loaded = await store.load();
    if (!mounted) return;
    setState(() {
      _settings = loaded;
      _loading = false;
    });
  }

  Future<void> _update(GameSettings next) async {
    setState(() => _settings = next);
    await store.save(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات التحكم'),
        backgroundColor: const Color(0x33000000),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _card(
                    title: 'حجم أزرار الهجوم والقدرات',
                    child: _scaleSlider(
                      key: const ValueKey('control_scale'),
                      value: _settings.controlScale,
                      onChanged: (v) => _update(
                          _settings.copyWith(controlScale: v)),
                    ),
                  ),
                  _card(
                    title: 'حجم عصا الحركة',
                    child: _scaleSlider(
                      key: const ValueKey('joystick_scale'),
                      value: _settings.joystickScale,
                      onChanged: (v) => _update(
                          _settings.copyWith(joystickScale: v)),
                    ),
                  ),
                  _card(
                    title: 'موضع أزرار الهجوم',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<ControlSide>(
                          key: const ValueKey('control_side'),
                          segments: const [
                            ButtonSegment(
                                value: ControlSide.right,
                                label: Text('يمين')),
                            ButtonSegment(
                                value: ControlSide.left,
                                label: Text('يسار')),
                          ],
                          selected: {_settings.controlSide},
                          onSelectionChanged: (values) {
                            _update(_settings.copyWith(
                                controlSide: values.first));
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'العصا دايماً في الجهة المعاكسة للهجوم',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  _card(
                    title: 'ارتفاع أزرار الهجوم',
                    child: Slider(
                      key: const ValueKey('vertical_offset'),
                      value: _settings.verticalOffset,
                      min: -GameSettings.maxVerticalOffset,
                      max: GameSettings.maxVerticalOffset,
                      divisions: 8,
                      label: _settings.verticalOffset.round().toString(),
                      onChanged: (v) =>
                          _update(_settings.copyWith(verticalOffset: v)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _preview(_settings),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('reset_controls'),
                    onPressed: () =>
                        _update(const GameSettings()),
                    icon: const Icon(Icons.restore),
                    label: const Text('استعادة الوضع الافتراضي'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _scaleSlider({
    required Key key,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Slider(
      key: key,
      value: value,
      min: GameSettings.minScale,
      max: GameSettings.maxScale,
      divisions: 9,
      label: '${(value * 100).round()}%',
      onChanged: onChanged,
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      color: const Color(0x22FFFFFF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  /// A small diagram proving the chosen side/size is applied, not just saved.
  Widget _preview(GameSettings s) {
    final attack = Container(
      key: const ValueKey('preview_attack'),
      width: 40 * s.controlScale,
      height: 40 * s.controlScale,
      decoration: const BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
    );
    final stick = Container(
      key: const ValueKey('preview_stick'),
      width: 40 * s.joystickScale,
      height: 40 * s.joystickScale,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
    );
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: s.controlSide == ControlSide.right
            ? [stick, attack]
            : [attack, stick],
      ),
    );
  }
}
