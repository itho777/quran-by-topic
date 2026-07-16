import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/settings_manager.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgeygoclduqotqveperx.supabase.co',
    publishableKey: 'sb_publishable_kyxOvxsj6WxjTCadR_tpoA_Xb7sQ6Ik',
  );

  // Use path-based URLs on web (no #) so Supabase OAuth token fragment
  // doesn't collide with go_router's hash routing.
  if (kIsWeb) usePathUrlStrategy();

  runApp(const ProviderScope(child: TafseerApp()));
}

class TafseerApp extends ConsumerStatefulWidget {
  const TafseerApp({super.key});
  @override
  ConsumerState<TafseerApp> createState() => _TafseerAppState();
}

class _TafseerAppState extends ConsumerState<TafseerApp> {
  @override
  void initState() {
    super.initState();
    // If a session is already active on startup, pull cloud preferences
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Future.microtask(() => ref.read(settingsProvider.notifier).loadFromCloud());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    AppTheme.themeMode = themeMode;
    return MaterialApp.router(
      title: 'Tafseer.id',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
