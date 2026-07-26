import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/settings_manager.dart';
import '../../core/theme.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideNavBar = ref.watch(hideNavBarProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Scaffold(
            body: Row(
              children: [
                if (!hideNavBar)
                  NavigationRail(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) => _onTap(context, index),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: AppTheme.getMushafIcon(),
                        selectedIcon: AppTheme.getMushafIcon(),
                        label: Text('Surah'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search_outlined),
                        selectedIcon: Icon(Icons.search),
                        label: Text('Search'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.bookmark_outline),
                        selectedIcon: Icon(Icons.bookmark),
                        label: Text('Bookmarks'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.more_horiz_outlined),
                        selectedIcon: Icon(Icons.more_horiz),
                        label: Text('More'),
                      ),
                    ],
                  ),
                if (!hideNavBar) const VerticalDivider(thickness: 1, width: 1),

                Expanded(
                  child: navigationShell,
                ),
              ],
            ),
          );
        } else {
          return Scaffold(
            extendBody: true,
            body: navigationShell,
            bottomNavigationBar: hideNavBar ? null : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => _onTap(context, index),
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: AppTheme.getMushafIcon(),
                  activeIcon: AppTheme.getMushafIcon(),
                  label: 'Surah',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_outlined),
                  activeIcon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark_outline),
                  activeIcon: Icon(Icons.bookmark),
                  label: 'Bookmarks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.more_horiz_outlined),
                  activeIcon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
