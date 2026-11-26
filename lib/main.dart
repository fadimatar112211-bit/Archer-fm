import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/auth/account_gate.dart';
import 'game/auth/supabase_account_service.dart';
import 'hero/hero_assets.dart';
import 'hero/hero_catalog.dart';
import 'home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final accountService = await SupabaseAccountService.initializeFromEnvironment();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(ArcherFmApp(accountService: accountService));
}

class ArcherFmApp extends StatelessWidget {
  const ArcherFmApp({super.key, this.loaderFactory, this.accountService});

  /// Tests inject fake loaders; the running game decodes the bundled atlases.
  final HeroLoaderFactory? loaderFactory;
  final SupabaseAccountService? accountService;

  @override
  Widget build(BuildContext context) {
    final hero = heroCatalog.first;
    return MaterialApp(
      title: 'Archer FM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: hero.theme.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: hero.theme.stageBottom,
        useMaterial3: true,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: accountService == null
            ? ArcherFmHomeScreen(
                loaderFactory: loaderFactory ?? defaultHeroLoaderFactory,
                accountService: accountService,
              )
            : AccountGate(
                accountService: accountService!,
                child: ArcherFmHomeScreen(
                  loaderFactory: loaderFactory ?? defaultHeroLoaderFactory,
                  accountService: accountService,
                ),
              ),
      ),
    );
  }
}
