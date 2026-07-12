import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'settings_manager.dart';
import 'auth_provider.dart';
import 'bookmarks_manager.dart';

final navigationHistoryProvider = StateNotifierProvider<NavigationHistoryNotifier, List<String>>((ref) {
  return NavigationHistoryNotifier();
});

class NavigationHistoryNotifier extends StateNotifier<List<String>> {
  NavigationHistoryNotifier() : super(['/']);

  void push(String path) {
    if (state.isNotEmpty && state.last == path) return;
    if (path.startsWith('/login') || path.startsWith('/admin')) return;
    
    final list = List<String>.from(state)..remove(path)..add(path);
    if (list.length > 20) {
      list.removeAt(0);
    }
    state = list;
  }

  String? pop() {
    if (state.length <= 1) return null;
    final list = List<String>.from(state);
    list.removeLast(); // Remove current location
    state = list;
    return list.last; // Return previous location
  }
}

class ShellScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  DateTime? _lastPressed;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/surahs')) return 1;
    if (location.startsWith('/mushaf')) return 2;
    if (location.startsWith('/topics')) return 3;
    if (location.startsWith('/bookmarks')) return 4;
    if (location.startsWith('/library')) return 5;
    if (location.startsWith('/profile')) return 6;
    return 0;
  }

  void _onTap(int index) {
    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/surahs'); break;
      case 2:
        BookmarksManager.getLastRead().then((lr) {
          if (!mounted) return;
          if (lr != null) {
            context.go('/mushaf?verse_key=${lr['surahId']}:${lr['ayahNumber']}');
          } else {
            context.go('/mushaf');
          }
        });
        break;
      case 3: context.go('/topics'); break;
      case 4: context.go('/bookmarks'); break;
      case 5: context.go('/library'); break;
      case 6: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final hideNavBar = ref.watch(hideNavBarProvider);
    final user = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).uri.toString();

    // Track navigation history safely outside the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(navigationHistoryProvider.notifier).push(location);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If standard sub-pages are pushed on top, pop them first
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // 2. If at Home page (/), ask to exit or exit on second tap
        if (location == '/') {
          final now = DateTime.now();
          if (_lastPressed == null || now.difference(_lastPressed!) > const Duration(seconds: 2)) {
            _lastPressed = now;
            final isEn = ref.read(settingsProvider).appLanguage == 'en';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEn ? 'Press back again to exit' : 'Tekan back sekali lagi untuk keluar'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            SystemNavigator.pop();
          }
        } else {
          // 3. Otherwise, go back through custom navigation history
          final prev = ref.read(navigationHistoryProvider.notifier).pop();
          if (prev != null) {
            context.go(prev);
          } else {
            context.go('/');
          }
        }
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: hideNavBar
            ? null
            : Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.outlineVariant, width: 0.5)),
                ),
                child: BottomNavigationBar(
                  currentIndex: index,
                  onTap: _onTap,
                  type: BottomNavigationBarType.fixed,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.list_alt),
                      activeIcon: Icon(Icons.list_alt_sharp),
                      label: 'Surahs',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.menu_book_outlined),
                      activeIcon: Icon(Icons.menu_book),
                      label: 'Mushaf',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.category_outlined),
                      activeIcon: Icon(Icons.category),
                      label: 'Topics',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.bookmark_border_outlined),
                      activeIcon: Icon(Icons.bookmark),
                      label: 'Saved',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.download_for_offline_outlined),
                      activeIcon: Icon(Icons.download_for_offline_rounded),
                      label: 'Library',
                    ),
                    BottomNavigationBarItem(
                      icon: user != null
                          ? Icon(Icons.account_circle)
                          : Icon(Icons.account_circle_outlined),
                      activeIcon: Icon(Icons.account_circle),
                      label: user != null ? 'Profile' : 'Sign In',
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
