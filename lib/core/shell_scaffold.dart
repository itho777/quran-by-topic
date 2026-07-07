import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'settings_manager.dart';
import 'auth_provider.dart';

import 'bookmarks_manager.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/surahs')) return 1;
    if (location.startsWith('/mushaf')) return 2;
    if (location.startsWith('/topics')) return 3;
    if (location.startsWith('/bookmarks')) return 4;
    if (location.startsWith('/profile')) return 5;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/surahs'); break;
      case 2:
        BookmarksManager.getLastRead().then((lr) {
          if (lr != null) {
            context.go('/mushaf?verse_key=${lr['surahId']}:${lr['ayahNumber']}');
          } else {
            context.go('/mushaf');
          }
        });
        break;
      case 3: context.go('/topics'); break;
      case 4: context.go('/bookmarks'); break;
      case 5: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final hideNavBar = ref.watch(hideNavBarProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: hideNavBar
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.outlineVariant, width: 0.5)),
              ),
              child: BottomNavigationBar(
                currentIndex: index,
                onTap: (i) => _onTap(context, i),
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
                  // Profile — shows a dot badge when signed in
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
    );
  }
}
