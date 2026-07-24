import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/settings_manager.dart';
import 'core/bookmarks_manager.dart';
import 'core/widgets/home_widget_service.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgeygoclduqotqveperx.supabase.co',
    publishableKey: 'sb_publishable_kyxOvxsj6WxjTCadR_tpoA_Xb7sQ6Ik',
  );

  // Initialize home_widget with correct app group ID (iOS AppGroup / Android SharedPrefs)
  if (!kIsWeb) {
    await HomeWidget.setAppGroupId(HomeWidgetService.appGroupId);
  }

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
    // Sync last read to home widget on app startup
    _syncLastReadOnStartup();

    // If a session is already active on startup, pull cloud preferences
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Future.microtask(() => ref.read(settingsProvider.notifier).loadFromCloud());
    }
  }

  Future<void> _syncLastReadOnStartup() async {
    try {
      final lr = await BookmarksManager.getLastRead();
      if (lr != null) {
        final surahId = lr['surahId'] as int? ?? 1;
        final ayahNumber = lr['ayahNumber'] as int? ?? 1;
        final surahName = lr['surahName'] as String? ?? 'Al-Fatihah';
        await HomeWidgetService.instance.updateLastReadWidget(
          surahName: surahName,
          surahNo: surahId,
          ayahNo: ayahNumber,
          progress: (ayahNumber / 50.0).clamp(0.0, 1.0) * 100.0,
        );
      }
    } catch (_) {}
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
