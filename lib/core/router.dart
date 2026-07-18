import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/surah_list/surah_list_screen.dart';
import '../features/surah_detail/surah_detail_screen.dart';
import '../features/ayah_detail/ayah_detail_screen.dart';
import '../features/mushaf/mushaf_screen.dart';
import '../features/topic/topic_screen.dart';
import '../features/topic/topic_detail_screen.dart';
import '../features/bookmarks/bookmarks_screen.dart';
import '../features/more/more_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/library/library_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_screens.dart';
import '../features/admin/admin_cms_screen.dart';
import '../features/qibla/qibla_screen.dart';
import '../features/qibla/qibla_ar_screen.dart';
import '../features/qibla/prayer_settings_screen.dart';
import '../features/murajaah/murajaah_screen.dart';
import 'auth_provider.dart';
import 'shell_scaffold.dart';

// Re-build the router whenever auth state changes
final _routerRefreshStream = StreamProvider<void>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((_) {});
});

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuild router on auth state changes
  final refreshListenable = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final path = state.uri.path;

      // Admin guard — must be signed in AND have admin role
      if (path.startsWith('/admin')) {
        if (user == null) return '/login';
        // Role check — isAdminProvider reads from profile cache
        final isAdmin = ref.read(isAdminProvider);
        if (!isAdmin) return '/';
      }

      // If already logged in and visiting /login, go to profile
      if (path == '/login' && user != null) return '/profile';

      return null;
    },
    routes: [
      // ── Main app shell (with bottom nav) ──────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) {
              final query = state.uri.queryParameters['q'] ?? '';
              return NoTransitionPage(child: SearchScreen(initialQuery: query));
            },
          ),
          GoRoute(
            path: '/surahs',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SurahListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  final autoplay = state.uri.queryParameters['autoplay'] == '1';
                  return SurahDetailScreen(surahId: id, autoplay: autoplay);
                },
                routes: [
                  GoRoute(
                    path: 'ayahs/:ayahNum',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      final ayahNum = int.parse(state.pathParameters['ayahNum']!);
                      final tafsir = state.uri.queryParameters['tafsir'];
                      final tabStr = state.uri.queryParameters['tab'];
                      final tab = tabStr != null ? int.tryParse(tabStr) : null;
                      return AyahDetailScreen(
                        surahId: id,
                        ayahNumber: ayahNum,
                        initialTafsir: tafsir,
                        initialTab: tab,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/mushaf',
            pageBuilder: (context, state) {
              final pageStr = state.uri.queryParameters['page'];
              final verseKey = state.uri.queryParameters['verse_key'];
              final page = pageStr != null ? int.tryParse(pageStr) : null;
              return NoTransitionPage(
                child: MushafScreen(
                  initialPage: page,
                  initialVerseKey: verseKey,
                ),
              );
            },
          ),
          GoRoute(
            path: '/topics',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TopicScreen()),
            routes: [
              GoRoute(
                path: ':tagId',
                builder: (context, state) {
                  final tagId = state.pathParameters['tagId']!;
                  return TopicDetailScreen(tagId: tagId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/bookmarks',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BookmarksScreen()),
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LibraryScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MoreScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
          GoRoute(
            path: '/murajaah',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MurajaahScreen()),
          ),
          GoRoute(
            path: '/qibla',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: QiblaScreen()),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => const PrayerSettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── AR Ka'bah Qibla View (full screen) ─────────────────────────────────
      GoRoute(
        path: '/qibla/ar',
        builder: (context, state) => const QiblaArScreen(),
      ),
 
      // ── Auth (no bottom nav) ───────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(),
      ),

      // ── Admin section (no bottom nav shell) ───────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'tags',
            builder: (context, state) => const AdminTagsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const AdminTagsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'translations',
            builder: (context, state) => const AdminTranslationsScreen(),
          ),
          GoRoute(
            path: 'tafsirs',
            builder: (context, state) => const AdminTafsirsScreen(),
          ),
          GoRoute(
            path: 'nuzul',
            builder: (context, state) => const AdminNuzulScreen(),
          ),
          GoRoute(
            path: 'cms',
            builder: (context, state) => const AdminCmsScreen(),
          ),
        ],
      ),
    ],
  );
});

// Listens to auth state stream and notifies the router to re-evaluate redirects
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<void>>(
      _routerRefreshStream,
      (_, _) => notifyListeners(),
    );
  }
}
