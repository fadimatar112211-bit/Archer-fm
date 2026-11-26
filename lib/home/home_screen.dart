import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/match/match_loadout_screen.dart';
import '../hero/hero_assets.dart';
import '../hero/hero_viewer_screen.dart';

class ArcherFmHomeScreen extends StatelessWidget {
  const ArcherFmHomeScreen({
    super.key,
    required this.loaderFactory,
  });

  final HeroLoaderFactory loaderFactory;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 430;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 28,
                vertical: compact ? 12 : 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      (compact ? 24 : 48),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.bolt,
                      size: 42,
                      color: Color(0xFFFFC857),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'آرتشر إف إم',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ساحة المعركة بانتظارك',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: compact ? 16 : 28),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _HomeAction(
                          icon: Icons.sports_esports,
                          title: 'المباراة',
                          subtitle: 'إنشاء غرفة أو الانضمام إلى مباراة',
                          onTap: () => _open(
                            context,
                            const MatchLoadoutScreen(),
                          ),
                        ),
                        _HomeAction(
                          icon: Icons.groups,
                          title: 'الأبطال',
                          subtitle: 'استعراض الأبطال وحركاتهم',
                          onTap: () => _open(
                            context,
                            HeroViewerScreen(loaderFactory: loaderFactory),
                          ),
                        ),
                        _HomeAction(
                          icon: Icons.settings,
                          title: 'الإعدادات',
                          subtitle: 'التحكم والاهتزاز',
                          onTap: () => _open(
                            context,
                            const GameSettingsScreen(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'اللعب بلا إعلانات',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9CCFB0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 34, color: const Color(0xFFFFC857)),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameSettingsScreen extends StatefulWidget {
  const GameSettingsScreen({super.key});

  @override
  State<GameSettingsScreen> createState() => _GameSettingsScreenState();
}

class _GameSettingsScreenState extends State<GameSettingsScreen> {
  bool _hapticsEnabled = true;

  Future<void> _toggleHaptics(bool enabled) async {
    setState(() => _hapticsEnabled = enabled);
    if (enabled) await HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            value: _hapticsEnabled,
            onChanged: _toggleHaptics,
            secondary: const Icon(Icons.vibration),
            title: const Text('الاهتزاز'),
            subtitle: const Text('استجابة لمسية عند تغيير الإعداد'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.volume_up_outlined),
            title: Text('الصوت'),
            subtitle: Text('لم يتم ربط ملفات الموسيقى والمؤثرات الصوتية بعد'),
          ),
          const ListTile(
            leading: Icon(Icons.screen_rotation),
            title: Text('اتجاه الشاشة'),
            subtitle: Text('اللعب بالوضع الأفقي'),
          ),
          const ListTile(
            leading: Icon(Icons.block),
            title: Text('الإعلانات'),
            subtitle: Text('لا توجد إعلانات داخل اللعبة'),
          ),
        ],
      ),
    );
  }
}
